from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import asyncio
from services.audio_service import process_lecture_audio
from services.stt_service import lecture_buffers, last_received_times
from core.database import get_supabase

router = APIRouter()

# 강의(lecture_id)별 패킷 처리 순서를 물리적으로 보장하기 위한 비동기 락 저장소
lecture_locks = {}

@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(websocket: WebSocket, lecture_id: str):
    await websocket.accept()
    
    # [보완] 익스텐션 주소창 쿼리 파라미터에서 target_lang을 명시적으로 안전하게 추출
    target_lang = websocket.query_params.get("target_lang", "Korean")
    
    print(f"[WebSocket] {lecture_id} 강의 실시간 오디오 스트림 연결 성공 (목표 언어: {target_lang})")

    # 해당 강의 전용 비동기 Lock 초기화
    if lecture_id not in lecture_locks:
        lecture_locks[lecture_id] = asyncio.Lock()

    try:
        db = await get_supabase()
        
        # 플러터가 자막 테이블을 안전하게 쿼리할 수 있도록 부모 레코드 생성
        await db.table("lectures").upsert({
            "id": lecture_id,
            "title": f"크롬 익스텐션 실시간 강의 ({lecture_id[:8]})",
        }).execute()
        print(f"[DB] {lecture_id} 부모 강의 레코드 선제 생성 완료 (외래키 제약조건 해결)")
    except Exception as db_err:
        print(f"[DB 에러 방어] 부모 강의 방 생성 중 오류 발생: {db_err}")

    # 태스크 내부에서 순차 처리를 보장하기 위한 헬퍼 함수 선언
    async def safe_process(audio_data: bytes, room_id: str, lang: str):
        # 락을 획득하여 앞선 패킷의 처리가 완벽히 끝날 때까지 대기 (순서 뒤바뀜 원천 차단)
        async with lecture_locks[room_id]:
            try:
                await process_lecture_audio(audio_data, room_id, lang)
            except Exception as proc_err:
                print(f"[Process 에러] 오디오 패킷 처리 중 예외 발생: {proc_err}")

    try:
        while True:
            data = await websocket.receive_bytes()

            # [최적화] 네트워크 수신루프 자체는 비차단(Non-blocking)으로 유지하되,
            # safe_process 내부의 Lock 덕분에 데이터가 순서대로 버퍼에 누적
            asyncio.create_task(safe_process(data, lecture_id, target_lang))

    except WebSocketDisconnect:
        print(f"[WebSocket] {lecture_id} 클라이언트 정상 연결 종료")
    except Exception as e:
        print(f"[WebSocket] {lecture_id} 에러 발생: {e}")
    finally:
        # [메모리 최적화] 연결 종료 시 해당 강의의 찌꺼기 버퍼 및 락 자원 완전히 소거
        if lecture_id in lecture_buffers:
            del lecture_buffers[lecture_id]
        if lecture_id in last_received_times:
            del last_received_times[lecture_id]
        if lecture_id in lecture_locks:
            del lecture_locks[lecture_id]
        print(f"[WebSocket] {lecture_id} 메모리 버퍼 및 동기화 자원 정리 완료")