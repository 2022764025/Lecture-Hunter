import cv2
import numpy as np
import mediapipe as mp
import time
from hsemotion_onnx.facial_emotions import HSEmotionRecognizer

class EngagementDetector:
    def __init__(self):
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(refine_landmarks=True)
        self.fer = HSEmotionRecognizer(model_name='enet_b0_8_best_vgaf')
        
        self.LEFT_EYE  = [33, 160, 158, 133, 153, 144]
        self.RIGHT_EYE = [362, 385, 387, 263, 373, 380]
        
        self.closed_start_time = None

        # Gaze 스무딩 버퍼 (최근 5프레임 평균)
        self.gaze_buffer_x = []
        self.gaze_buffer_y = []
        self.GAZE_SMOOTH   = 5

        # 캘리브레이션
        self.calibration_frames = []
        self.calibration_done   = False
        self.baseline = {
            "lip_drop":         0.01,
            "mouth_open":       0.015,
            "eye_squint":       0.03,
            "eye_aspect_ratio": 0.35,
            "inner_eye_dist":   0.15,
            "gaze_y_offset":    0.5
        }
        print("System: Professional Vision Engine Loaded")
        print("캘리브레이션 중... 무표정으로 정면을 바라봐 주세요 (30프레임)")

    def _calibrate(self, lip_drop, mouth_open, eye_squint, eye_aspect_ratio, inner_eye_dist, raw_gaze_y):
        """처음 30프레임 무표정 기준값 자동 수집"""
        self.calibration_frames.append({
            "lip_drop":         lip_drop,
            "mouth_open":       mouth_open,
            "eye_squint":       eye_squint,
            "eye_aspect_ratio": eye_aspect_ratio,
            "inner_eye_dist":   inner_eye_dist,
            "raw_gaze_y":       raw_gaze_y
        })
        if len(self.calibration_frames) >= 30:
            self.baseline["lip_drop"]         = np.mean([f["lip_drop"]         for f in self.calibration_frames]) + 0.008
            self.baseline["mouth_open"]       = np.mean([f["mouth_open"]       for f in self.calibration_frames]) - 0.003
            self.baseline["eye_squint"]       = np.mean([f["eye_squint"]       for f in self.calibration_frames]) - 0.008
            self.baseline["eye_aspect_ratio"] = np.mean([f["eye_aspect_ratio"] for f in self.calibration_frames]) * 0.88
            self.baseline["inner_eye_dist"]   = np.mean([f["inner_eye_dist"]   for f in self.calibration_frames]) - 0.01
            # 중앙값(median)으로 이상치 제거 후 정면 기준 오프셋 저장
            self.baseline["gaze_y_offset"]    = np.median([f["raw_gaze_y"] for f in self.calibration_frames])
            self.calibration_done = True
            print(f"캘리브레이션 완료: {self.baseline}")

    def _extract_dip_features(self, gray_face):
        """[DIP] DoG 텍스처 + Sobel 그래디언트"""
        g1 = cv2.GaussianBlur(gray_face, (3, 3), 0)
        g2 = cv2.GaussianBlur(gray_face, (9, 9), 0)
        texture_energy = np.mean(cv2.absdiff(g1, g2))
        sobelx = cv2.Sobel(gray_face, cv2.CV_64F, 1, 0, ksize=3)
        sobely = cv2.Sobel(gray_face, cv2.CV_64F, 0, 1, ksize=3)
        gradient_intensity = np.mean(cv2.magnitude(sobelx, sobely))
        return float(texture_energy), float(gradient_intensity)

    def _analyze_eye_morphology(self, gray, lms, h, w):
        """[DIP Morphology] 동공 영역으로 눈 개폐 확인"""
        try:
            points = (lms[self.LEFT_EYE] * [w, h]).astype(np.int32)
            rect = cv2.boundingRect(points)
            eye_roi = gray[rect[1]:rect[1]+rect[3], rect[0]:rect[0]+rect[2]]
            _, thresh = cv2.threshold(eye_roi, 45, 255, cv2.THRESH_BINARY_INV)
            opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
            return "Closed" if np.sum(opening == 255) < 5 else "Open"
        except:
            return "Unknown"

    def enhance_image(self, frame):
        """CLAHE 조명 보정"""
        lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
        return cv2.cvtColor(cv2.merge((clahe.apply(l), a, b)), cv2.COLOR_LAB2BGR)

    def _smooth_gaze(self, gx, gy):
        """최근 N프레임 평균으로 Gaze 스무딩"""
        self.gaze_buffer_x.append(gx)
        self.gaze_buffer_y.append(gy)
        if len(self.gaze_buffer_x) > self.GAZE_SMOOTH:
            self.gaze_buffer_x.pop(0)
            self.gaze_buffer_y.pop(0)
        return float(np.mean(self.gaze_buffer_x)), float(np.mean(self.gaze_buffer_y))

    def analyze_frame(self, frame):
        if frame is None: return None

        enhanced = self.enhance_image(frame)
        h, w = enhanced.shape[:2]
        gray = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY)
        results = self.face_mesh.process(cv2.cvtColor(enhanced, cv2.COLOR_BGR2RGB))

        if not results.multi_face_landmarks: return None
        lms = np.array([[lm.x, lm.y] for lm in results.multi_face_landmarks[0].landmark])

        # --- [1. DIP Features] ---
        texture_val, grad_val = self._extract_dip_features(gray)
        eye_morph = self._analyze_eye_morphology(gray, lms, h, w)

        # --- [2. EAR] ---
        ear = (self._calc_ear(lms, self.LEFT_EYE) + self._calc_ear(lms, self.RIGHT_EYE)) / 2.0

        # --- [3. 눈 찡그림 & 미간] ---
        inner_eye_dist   = np.linalg.norm(lms[133] - lms[362])
        left_eye_height  = abs(lms[159][1] - lms[145][1])
        right_eye_height = abs(lms[386][1] - lms[374][1])
        eye_squint       = (left_eye_height + right_eye_height) / 2.0

        # 눈 세로/가로 비율: 화난 표정은 눈을 가늘게 뜨므로 비율 감소
        left_eye_width   = abs(lms[33][0]  - lms[133][0])
        right_eye_width  = abs(lms[263][0] - lms[362][0])
        eye_aspect_ratio = eye_squint / ((left_eye_width + right_eye_width) / 2.0 + 1e-6)

        # --- [4. Gaze: 양쪽 홍채(468, 473) 평균] ---
        # X축: 홍채가 눈 안에서 얼마나 좌우에 있는지
        left_gaze_x  = (lms[468][0] - lms[33][0])  / (lms[133][0] - lms[33][0]  + 1e-6)
        right_gaze_x = (lms[473][0] - lms[362][0]) / (lms[263][0] - lms[362][0] + 1e-6)
        raw_x = (left_gaze_x + right_gaze_x) / 2.0

        # Y축: 홍채가 눈 안에서 얼마나 위아래에 있는지
        left_gaze_y  = (lms[468][1] - lms[159][1]) / (lms[145][1] - lms[159][1] + 1e-6)
        right_gaze_y = (lms[473][1] - lms[386][1]) / (lms[374][1] - lms[386][1] + 1e-6)
        raw_y = (left_gaze_y + right_gaze_y) / 2.0

        gaze_y_offset = self.baseline["gaze_y_offset"] if self.calibration_done else 0.5

        # X 반전 수정: 오른쪽 볼수록 양수
        raw_gx = np.clip((raw_x - 0.5) * -2.5, -1.0, 1.0)
        # Y 반전 수정: 위를 볼수록 양수
        raw_gy = np.clip((raw_y - gaze_y_offset) * -3.5, -1.0, 1.0)

        # 스무딩 적용 (휙휙 이동 방지)
        g_x, g_y = self._smooth_gaze(float(raw_gx), float(raw_gy))

        # --- [5. 눈꼬리] ---
        eye_smile = ((lms[33][1] - lms[133][1]) + (lms[263][1] - lms[362][1])) / 2.0

        # --- [6. 입술] ---
        lip_corners_y = (lms[61][1] + lms[291][1]) / 2.0
        lip_center_y  = lms[13][1]
        lip_up        = lip_center_y - lip_corners_y   # 양수 = 입꼬리 올라감
        lip_drop      = lip_corners_y - lip_center_y   # 양수 = 입꼬리 처짐
        lip_width     = np.linalg.norm(lms[61] - lms[291])
        mouth_open    = np.linalg.norm(lms[13] - lms[14])

        # --- [7. 볼 근육] ---
        cheek_raise = (
            (lms[133][1] - lms[116][1]) +
            (lms[362][1] - lms[345][1])
        ) / 2.0

        # --- [8. 턱 위치 (고개 숙임)] ---
        chin_drop = lms[152][1] - lms[1][1]

        # --- [9. 눈썹 (앞머리 없을 때만 유효)] ---
        brow_dist_v = np.linalg.norm(lms[52] - lms[159])

        # --- [10. 캘리브레이션 수집 (처음 30프레임)] ---
        if not self.calibration_done:
            self._calibrate(lip_drop, mouth_open, eye_squint, eye_aspect_ratio, inner_eye_dist, raw_y)
            return {
                "ear": float(ear), "status": "Calibrating...",
                "gaze_x": 0.0, "gaze_y": 0.0,
                "emotion": "Calibrating...", "engagement_score": 0.0,
                "happy_score": 0, "angry_score": 0,
                "muscle_tension": grad_val, "texture_energy": texture_val,
                "chin_drop": float(chin_drop)
            }

        # --- [11. HSEmotion AI (얼굴 크롭)] ---
        try:
            x_min = max(int(np.min(lms[:, 0]) * w) - 10, 0)
            x_max = min(int(np.max(lms[:, 0]) * w) + 10, w)
            y_min = max(int(np.min(lms[:, 1]) * h) - 10, 0)
            y_max = min(int(np.max(lms[:, 1]) * h) + 10, h)
            face_crop = enhanced[y_min:y_max, x_min:x_max]
            _, scores = self.fer.predict_emotions(face_crop, logits=False)
            happy_prob, angry_prob = scores[4], scores[0]
        except:
            happy_prob, angry_prob = 0.0, 0.0

        # --- [12. 졸음 / 깜빡임 판단] ---
        current_time = time.time()
        if ear < 0.28 or eye_morph == "Closed":
            if self.closed_start_time is None: self.closed_start_time = current_time
            status = "Sleeping!!!" if (current_time - self.closed_start_time) >= 3.0 else "Blinking"
        else:
            self.closed_start_time = None
            status = "Awake"

        # --- [13. 가중치 점수제 감정 판정] ---
        h_score, a_score = 0, 0

        # Happy 점수
        if eye_smile > 0.02:    h_score += 1   # 눈꼬리 내려감
        if lip_up > 0.015:      h_score += 1   # 입꼬리 올라감
        if cheek_raise > 0.01:  h_score += 1   # 볼 올라감
        if lip_width > 0.13:    h_score += 1   # 입 넓게 벌어짐
        if brow_dist_v > 0.035: h_score += 1   # 눈썹 올라감 (앞머리 없을 때)
        if happy_prob > 0.45:   h_score += 2   # AI 가중치 2배

        # Angry 점수 (전부 캘리브레이션 기준값 대비로 판단)
        if eye_aspect_ratio < self.baseline["eye_aspect_ratio"]: a_score += 2  # 핵심: 눈 가늘어짐 2배
        if eye_squint       < self.baseline["eye_squint"]:       a_score += 1  # 눈 세로 높이 감소
        if inner_eye_dist   < self.baseline["inner_eye_dist"]:   a_score += 1  # 미간 좁아짐
        if lip_drop         > self.baseline["lip_drop"]:         a_score += 1  # 입꼬리 처짐
        if mouth_open       < self.baseline["mouth_open"]:       a_score += 1  # 입 꽉 다문 상태
        if chin_drop < 0.15:                                     a_score += 1  # 고개 숙임
        if brow_dist_v < 0.025:                                  a_score += 1  # 눈썹 찡그림
        if grad_val > 55.0:                                      a_score += 1  # 얼굴 근육 긴장
        if angry_prob > 0.45:                                    a_score += 2  # AI 가중치 2배

        # 2점 이상 확정 → Neutral 보호
        if h_score >= 2:
            emotion = "Happy"
        elif a_score >= 2:
            emotion = "Angry"
        else:
            emotion = "Neutral"

        # --- [14. Engagement Score] ---
        base_score = ear * 0.4
        if emotion == "Happy":     base_score += 0.4
        elif emotion == "Neutral": base_score += 0.2
        engagement_score = float(np.clip(base_score + 0.2, 0, 1))

        return {
            "ear":              float(ear),
            "status":           status,
            "gaze_x":           float(g_x),
            "gaze_y":           float(g_y),
            "emotion":          emotion,
            "happy_score":      h_score,
            "angry_score":      a_score,
            "eye_squint":       float(eye_squint),
            "eye_aspect_ratio": float(eye_aspect_ratio),
            "inner_eye_dist":   float(inner_eye_dist),
            "muscle_tension":   grad_val,
            "texture_energy":   texture_val,
            "chin_drop":        float(chin_drop),
            "engagement_score": engagement_score
        }

    def _calc_ear(self, lms, idx):
        # Eye Aspect Ratio: 눈 세로/가로 비율로 눈 개방도 계산
        p1, p2, p3, p4, p5, p6 = lms[idx]
        return (np.linalg.norm(p2-p6) + np.linalg.norm(p3-p5)) / (2.0 * np.linalg.norm(p1-p4) + 1e-6)


def main():
    detector = EngagementDetector()
    cap = cv2.VideoCapture(0)

    # 시선 표시용 캔버스 크기
    GAZE_W, GAZE_H = 300, 200

    print("실행 중... 'q' 키를 누르면 종료됩니다.")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        result = detector.analyze_frame(frame)

        if result:
            # EAR / Status
            ear_color = (0, 255, 0) if result["status"] == "Awake" else (0, 0, 255)
            cv2.putText(frame, f"EAR: {result['ear']:.2f} ({result['status']})",
                        (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, ear_color, 2)

            # Emotion
            emo_color = {
                "Happy":        (0, 255, 255),
                "Angry":        (0, 0, 255),
                "Neutral":      (255, 255, 0),
                "Calibrating...": (128, 128, 128)
            }.get(result["emotion"], (255, 255, 255))
            cv2.putText(frame, f"Emotion: {result['emotion']}",
                        (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, emo_color, 2)

            # Score
            cv2.putText(frame, f"Score: {result['engagement_score']:.2f}",
                        (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

            # --- 시선 추적 미니 캔버스 ---
            gaze_canvas = np.zeros((GAZE_H, GAZE_W, 3), dtype=np.uint8)

            # 3x3 격자
            for i in range(1, 3):
                cv2.line(gaze_canvas, (GAZE_W * i // 3, 0), (GAZE_W * i // 3, GAZE_H), (50, 50, 50), 1)
                cv2.line(gaze_canvas, (0, GAZE_H * i // 3), (GAZE_W, GAZE_H * i // 3), (50, 50, 50), 1)

            # 중앙 십자선
            cv2.line(gaze_canvas, (GAZE_W // 2, 0), (GAZE_W // 2, GAZE_H), (80, 80, 80), 1)
            cv2.line(gaze_canvas, (0, GAZE_H // 2), (GAZE_W, GAZE_H // 2), (80, 80, 80), 1)

            if result["emotion"] != "Calibrating...":
                # gaze_x, gaze_y: -1.0 ~ 1.0 → 캔버스 좌표 변환
                gx = int((result["gaze_x"] + 1.0) / 2.0 * GAZE_W)
                # Y축: 양수(위)면 캔버스 위쪽 → 반전 적용
                gy = int((-result["gaze_y"] + 1.0) / 2.0 * GAZE_H)
                gx = np.clip(gx, 5, GAZE_W - 5)
                gy = np.clip(gy, 5, GAZE_H - 5)
                cv2.circle(gaze_canvas, (gx, gy), 10, (0, 255, 255), -1)
            else:
                cv2.putText(gaze_canvas, "Calibrating...", (30, GAZE_H // 2),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (128, 128, 128), 1)

            # 미니 캔버스를 메인 프레임 우측 하단에 합성
            fh, fw = frame.shape[:2]
            frame[fh - GAZE_H - 10: fh - 10, fw - GAZE_W - 10: fw - 10] = gaze_canvas

        cv2.imshow("AI Vision Private Sync Test", frame)

        # q 누르면 종료
        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("종료합니다.")
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()