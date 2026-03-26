import cv2
import numpy as np
import mediapipe as mp
from hsemotion.face_api import HSEmotionRecognizer  # 최신 감정 분석 엔진

class EngagementDetector:
    def __init__(self):
        # 1. MediaPipe Face Mesh 초기화 (시선 및 졸음용)
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # 2. 최신 EfficientNet 기반 감정 인식기 로드
        # enet_b0_8_best_vgaf 모델은 속도와 정확도 밸런스가 가장 좋습니다.
        # 처음 실행 시 모델 가중치 파일(약 20MB)을 자동으로 다운로드합니다.
        self.fer = HSEmotionRecognizer(model_name='enet_b0_8_best_vgaf')

        # 감정 라벨 매핑 (민재님의 비즈니스 로직에 맞춰 최적화)
        # HSEmotion 기본 라벨: Anger, Contempt, Disgust, Fear, Happiness, Neutral, Sadness, Surprise
        self.emotion_map = {
            'Anger': 'Angry',
            'Happiness': 'Happy',
            'Sadness': 'Sad',
            'Surprise': 'Surprise',
            'Neutral': 'Neutral',
            'Fear': 'Fear',
            'Disgust': 'Disgust'
        }

        # 랜드마크 인덱스 설정
        self.LEFT_EYE = [33, 160, 158, 133, 153, 144]
        self.RIGHT_EYE = [362, 385, 387, 263, 373, 380]

    def calculate_ear(self, landmarks, eye_indices):
        """눈 개방도(EAR) 계산 알고리즘"""
        p2_p6 = np.linalg.norm(landmarks[eye_indices[1]] - landmarks[eye_indices[5]])
        p3_p5 = np.linalg.norm(landmarks[eye_indices[2]] - landmarks[eye_indices[4]])
        p1_p4 = np.linalg.norm(landmarks[eye_indices[0]] - landmarks[eye_indices[3]])
        return (p2_p6 + p3_p5) / (2.0 * p1_p4)

    def get_gaze_point(self, landmarks):
        """눈 구멍 내 눈동자 상대 위치 추적"""
        # X축 (좌우): 0을 중심으로 -0.5 ~ 0.5 범위
        left_bound = landmarks[33][0]
        right_bound = landmarks[133][0]
        iris_x = landmarks[468][0]
        gaze_x = (iris_x - left_bound) / (right_bound - left_bound) - 0.5
        
        # Y축 (상하): 가동 범위 보정 적용
        top_bound = landmarks[159][1]
        bottom_bound = landmarks[145][1]
        iris_y = landmarks[468][1]
        gaze_y_ratio = (iris_y - top_bound) / (bottom_bound - top_bound)
        gaze_y = gaze_y_ratio - 0.45 
        
        return float(gaze_x), float(gaze_y)

    def get_emotion(self, frame):
        """최신 HSEmotion 엔진을 사용한 감정 분석"""
        try:
            # 1. 프레임 전체를 모델에 전달 (내부적으로 얼굴 검출 및 전처리 수행)
            # logits=False로 설정하여 최종 라벨과 확률값을 직접 받습니다.
            emotion_label, scores = self.fer.predict_emotions(frame, logits=False)
            
            # 2. 매핑된 라벨 반환 (기본값 Neutral)
            return self.emotion_map.get(emotion_label, "Neutral")
        except Exception as e:
            return "Neutral"

    def analyze_frame(self, frame):
        if frame is None: return None
        
        # MediaPipe 처리를 위해 RGB 변환
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.face_mesh.process(rgb_frame)
        
        if not results.multi_face_landmarks:
            return None

        raw_landmarks = results.multi_face_landmarks[0].landmark
        landmarks_np = np.array([[lm.x, lm.y] for lm in raw_landmarks])
        
        # 1. EAR 계산 (졸음 여부)
        avg_ear = (self.calculate_ear(landmarks_np, self.LEFT_EYE) + 
                    self.calculate_ear(landmarks_np, self.RIGHT_EYE)) / 2.0
        
        # 2. 시선 좌표 추출
        gaze_x, gaze_y = self.get_gaze_point(landmarks_np)
        
        # 3. 최신 엔진 기반 감정 분석 (frame 전달)
        emotion = self.get_emotion(frame)

        # 4. 종합 집중도 점수 (졸음 60% + 시선 40%)
        engagement_score = (avg_ear * 0.6) + (max(0, 1 - abs(gaze_x)*10) * 0.4)

        return {
            "ear": float(avg_ear),
            "status": "Awake" if avg_ear > 0.25 else "Drowsy",
            "gaze_x": gaze_x,
            "gaze_y": gaze_y,
            "emotion": emotion,
            "engagement_score": float(engagement_score)
        }