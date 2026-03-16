import cv2
import numpy as np
import mediapipe as mp

class EngagementDetector:
    def __init__(self):
        # 이제 mp.solutions가 아주 잘 작동합니다!
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        # 눈 랜드마크 인덱스 (MediaPipe Face Mesh 표준)
        self.LEFT_EYE = [33, 160, 158, 133, 153, 144]
        self.RIGHT_EYE = [362, 385, 387, 263, 373, 380]

    def calculate_ear(self, landmarks, eye_indices):
        """EAR(Eye Aspect Ratio) 계산 알고리즘"""
        # 수직 거리 계산
        p2_p6 = np.linalg.norm(landmarks[eye_indices[1]] - landmarks[eye_indices[5]])
        p3_p5 = np.linalg.norm(landmarks[eye_indices[2]] - landmarks[eye_indices[4]])
        # 수평 거리 계산
        p1_p4 = np.linalg.norm(landmarks[eye_indices[0]] - landmarks[eye_indices[3]])
        
        # EAR 공식: (수직1 + 수직2) / (2 * 수평)
        return (p2_p6 + p3_p5) / (2.0 * p1_p4)

    def analyze_frame(self, frame):
        if frame is None: return None
        
        # BGR -> RGB 변환
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.face_mesh.process(rgb_frame)
        
        if not results.multi_face_landmarks:
            return None

        # 랜드마크 추출 (0~1 사이의 상대 좌표)
        landmarks = np.array([[lm.x, lm.y] for lm in results.multi_face_landmarks[0].landmark])
        
        # 양안 EAR 계산 및 평균
        left_ear = self.calculate_ear(landmarks, self.LEFT_EYE)
        right_ear = self.calculate_ear(landmarks, self.RIGHT_EYE)
        avg_ear = (left_ear + right_ear) / 2.0
        
        # 임계값 0.22를 기준으로 졸음/깨어있음 판별
        status = "Awake" if avg_ear > 0.22 else "Drowsy"
        
        return {
            "ear": float(avg_ear),
            "status": status
        }