import cv2
from vision_service import EngagementDetector

def main():
    # 1. 감지기 초기화
    detector = EngagementDetector()
    
    # 2. 웹캠 연결 (맥북의 경우 보통 0번)
    cap = cv2.VideoCapture(0)
    
    print("비전 테스트를 시작합니다. 'q'를 누르면 종료합니다.")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        # 3. 프레임 분석
        result = detector.analyze_frame(frame)

        if result:
            ear = result['ear']
            status = result['status']
            
            # 화면에 수치 및 상태 표시
            color = (0, 255, 0) if status == "Awake" else (0, 0, 255)
            cv2.putText(frame, f"EAR: {ear:.2f}", (30, 50), 
                        cv2.FONT_HERSHEY_SIMPLEX, 1, color, 2)
            cv2.putText(frame, f"Status: {status}", (30, 100), 
                        cv2.FONT_HERSHEY_SIMPLEX, 1, color, 2)

        # 4. 결과 화면 출력
        cv2.imshow('Vision AI Test', frame)

        # 'q' 누르면 종료
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()