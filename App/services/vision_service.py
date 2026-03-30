import cv2
import numpy as np
import mediapipe as mp
from deepface import DeepFace

class EngagementDetector:
    def __init__(self):
        # 1. MediaPipe 초기화 (시선 및 졸음용)
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1, 
            refine_landmarks=True,
            min_detection_confidence=0.5, 
            min_tracking_confidence=0.5
        )
        
        # 랜드마크 인덱스 설정
        self.LEFT_EYE = [33, 160, 158, 133, 153, 144]
        self.RIGHT_EYE = [362, 385, 387, 263, 373, 380]
        
        print("시스템: DeepFace 엔진 장착 완료 (TF 2.16.1 호환 모드)")

    def get_emotion(self, frame):
        """DeepFace를 사용한 감정 분석 (MediaPipe 백엔드 활용)"""
        try:
            # detector_backend='mediapipe'를 써서 이미 로드된 mediapipe를 재활용한다.
            results = DeepFace.analyze(frame, actions=['emotion'], 
                                        enforce_detection=False, 
                                        detector_backend='mediapipe', 
                                        silent=True)
            return results[0]['dominant_emotion'].capitalize()
        except:
            return "Neutral"

    def analyze_frame(self, frame):
        if frame is None: return None
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.face_mesh.process(rgb_frame)
        
        if not results.multi_face_landmarks: return None

        # 랜드마크 추출
        lms = np.array([[lm.x, lm.y] for lm in results.multi_face_landmarks[0].landmark])
        
        # 1. EAR 계산 (졸음 수치)
        ear = (self._calc_ear(lms, self.LEFT_EYE) + self._calc_ear(lms, self.RIGHT_EYE)) / 2.0
        
        # 2. 시선 좌표 계산 (X: 좌우, Y: 상하)
        g_x = (lms[468][0] - lms[33][0]) / (lms[133][0] - lms[33][0]) - 0.5
        g_y = (lms[468][1] - lms[159][1]) / (lms[145][1] - lms[159][1]) - 0.45
        
        # 3. 감정 분석 수행
        emotion = self.get_emotion(frame)

        return {
            "ear": float(ear),
            "status": "Awake" if ear > 0.25 else "Drowsy",
            "gaze_x": float(g_x),
            "gaze_y": float(g_y),
            "emotion": emotion,
            "engagement_score": float((ear * 0.6) + (max(0, 1 - abs(g_x)*10) * 0.4))
        }

    def _calc_ear(self, lms, idx):
        """눈 개방도(EAR) 계산 헬퍼 함수"""
        return (np.linalg.norm(lms[idx[1]]-lms[idx[5]]) + 
                np.linalg.norm(lms[idx[2]]-lms[idx[4]])) / (2.0 * np.linalg.norm(lms[idx[0]]-lms[idx[3]]))