import cv2
import time
import requests
import numpy as np
from vision_service import EngagementDetector  # 기존 코드 주석 처리
# from App.services.vision_service import EngagementDetector # 새로운 HSE 엔진 임포트

def main():
    detector = EngagementDetector()
    cap = cv2.VideoCapture(0) # 맥북 내장 카메라
    
    last_send_time = time.time()
    send_interval = 1.0 
    
    # [최적화 변수]
    frame_count = 0
    last_result = None # 분석이 없는 프레임에서도 UI를 유지하기 위함
    
    print("최적화 모드로 비전 엔진을 시작합니다. 'q'를 누르세요.")
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break

        frame = cv2.flip(frame, 1) # 거울 모드
        h, w, _ = frame.shape
        frame_count += 1
        
        # --- [최적화 핵심 1: 프레임 스킵 & 리사이징] ---
        # 5프레임마다 한 번만 분석을 수행합니다. (초당 약 6번 분석)
        if frame_count % 5 == 0:
            # 분석용으로만 화면 크기를 절반(0.5)으로 줄여 연산량을 1/4로 감소시킵니다.
            small_frame = cv2.resize(frame, (0, 0), fx=0.5, fy=0.5)
            last_result = detector.analyze_frame(small_frame)
        
        # 분석 결과가 있을 때만 화면에 그립니다.
        if last_result:
            current_time = time.time()

            # 1초마다 서버 전송 (last_result가 존재할 때만)
            if current_time - last_send_time > send_interval:
                payload = {
                    "session_id": "AI_CLASS_01",
                    "ear": last_result['ear'],
                    "gaze_x": last_result['gaze_x'],
                    "gaze_y": last_result['gaze_y'],
                    "emotion": last_result['emotion'],
                    "engagement_score": last_result['engagement_score']
                }
                try:
                    requests.post("http://localhost:8000/submit_data", json=payload, timeout=0.05)
                except:
                    pass # 서버 연결 오류 무시
                last_send_time = current_time

            # 시선 매핑 계산 (last_result 기준)
            sensitivity_x, sensitivity_y = 10000, 13000
            offset_x, offset_y = 0.02, -0.05
            
            target_x = int(w/2 + (last_result['gaze_x'] + offset_x) * sensitivity_x)
            target_y = int(h/2 + (last_result['gaze_y'] + offset_y) * sensitivity_y)
            target_x, target_y = max(0, min(w, target_x)), max(0, min(h, target_y))

            # --- [화면 UI 렌더링] ---
            # 텍스트 출력
            # EAR 뒤에 상태(Awake/Drowsy) 다시 추가
            cv2.putText(frame, f"EAR: {last_result['ear']:.2f} ({last_result['status']})", (30, 50), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            cv2.putText(frame, f"Emotion: {last_result['emotion']}", (30, 80), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 100, 0), 2)
            
            cv2.putText(frame, f"Score: {last_result['engagement_score']:.2f}", (30, 110), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
            
            # 시선 커서
            cv2.circle(frame, (target_x, target_y), 20, (0, 255, 255), -1)

        cv2.imshow('AI Vision Private Sync Test', frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()