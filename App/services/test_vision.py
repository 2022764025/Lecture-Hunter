import cv2
import time
import requests
from vision_service import EngagementDetector

def main():
    # 1. 감지기 초기화
    # 모델 학습 전까지는 model_path=None으로 둡니다.
    detector = EngagementDetector()
    
    # 2. 카메라 연결 (맥북 M1 내장 카메라)
    cap = cv2.VideoCapture(0)
    
    # 서버 전송 주기 관리를 위한 변수
    last_send_time = time.time()
    send_interval = 1.0  # 1초에 한 번 전송
    
    print("비전 테스트 및 서버 동기화를 시작합니다. 'q'를 누르면 종료합니다.")
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        # 좌우 반전 (거울 모드)
        frame = cv2.flip(frame, 1)
        
        # 3. 프레임 분석
        result = detector.analyze_frame(frame)
        
        if result:
            h, w, _ = frame.shape
            current_time = time.time()

            # --- [아이디어 1: 서버 전송 로직] ---
            # 1초마다 익명화된 수치 데이터를 서버로 보고합니다.
            if current_time - last_send_time > send_interval:
                payload = {
                    "session_id": "AI_CLASS_01",  # 강의실 ID (익명성 유지)
                    "ear": result['ear'],
                    "gaze_x": result['gaze_x'],
                    "gaze_y": result['gaze_y'],
                    "emotion": result['emotion'],
                    "engagement_score": result['engagement_score']
                }
                try:
                    # 로컬 서버(server.py)로 데이터 전송
                    # timeout을 짧게 설정해야 네트워크 지연 시 UI가 끊기지 않습니다.
                    response = requests.post("http://localhost:8000/submit_data", json=payload, timeout=0.1)
                    print(f"서버 전송 성공: {response.json()}")
                except Exception as e:
                    print(f"서버 연결 대기 중... (server.py를 실행했는지 확인하세요)")
                
                last_send_time = current_time

            # --- [아이디어 2, 5: 시선 매핑 보정] ---
            sensitivity_x = 10000 
            sensitivity_y = 13000 
            
            offset_x = 0.02 
            offset_y = -0.05 
            
            target_x = int(w/2 + (result['gaze_x'] + offset_x) * sensitivity_x)
            target_y = int(h/2 + (result['gaze_y'] + offset_y) * sensitivity_y)

            target_x = max(0, min(w, target_x))
            target_y = max(0, min(h, target_y))

            # --- [화면 UI 렌더링] ---
            # 데이터 텍스트 출력
            cv2.putText(frame, f"EAR: {result['ear']:.2f} ({result['status']})", (30, 50), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(frame, f"Gaze: ({result['gaze_x']:.2f}, {result['gaze_y']:.2f})", (30, 80), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            cv2.putText(frame, f"Emotion: {result['emotion']}", (30, 110), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 100, 0), 2)
            cv2.putText(frame, f"Score: {result['engagement_score']:.2f}", (30, 140), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
            
            # 노란색 시선 커서 (2026 에듀테크 트렌드 반영!)
            cv2.circle(frame, (target_x, target_y), 20, (0, 255, 255), -1)

        # 4. 결과 윈도우 표시
        cv2.imshow('AI Vision Private Sync Test', frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()