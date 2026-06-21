from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import asyncio
from typing import Optional
from services.audio_service import process_lecture_audio
from services.stt_service import lecture_buffers, last_received_times
from core.database import get_supabase

router = APIRouter()

# 강의(lecture_id)별 패킷 처리 순서를 보장하기 위한 비동기 락 저장소
lecture_locks = {}

@router.websocket("/ws/audio")
@router.websocket("/ws/audio/")
@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(websocket: WebSocket, lecture_id: Optional[str] = None):
    await websocket.accept()
    
    # 경로 파라미터가 비어있다면 쿼리 파라미터(?lecture_id=...)에서 안전하게 추출
    if not lecture_id or lecture_id.strip() == "":
        lecture_id = websocket.query_params.get("lecture_id")
        
    if not lecture_id:
        print("[WebSocket] 연결 거부: lecture_id 파라미터가 누락되었습니다.")
        await websocket.close(code=4000)
        return

    target_lang = websocket.query_params.get("target_lang", "Korean")
    print(f"[WebSocket] {lecture_id} 파이프라인 개통 성공 (목표 언어: {target_lang})")

    # [필터링 엔진 업그레이드] 
    # 전체 URL 주소뿐만 아니라, 프론트에서 정제해서 보낸 11자리의 유튜브 고유 비디오 ID 포맷까지 완벽 감별합니다!
    is_youtube = "youtube.com" in lecture_id or "youtu.be" in lecture_id or len(lecture_id) == 11

    if lecture_id not in lecture_locks:
        lecture_locks[lecture_id] = asyncio.Lock()

    try:
        db = await get_supabase()
        display_title = lecture_id if not is_youtube else f"유튜브 인강 ({lecture_id})"
        await db.table("lectures").upsert({
            "id": lecture_id,
            "title": f"실시간 강의 - {display_title}",
        }).execute()
        print(f"[DB] {lecture_id} 부모 강의 레코드 선제 생성 완료")
    except Exception as db_err:
        print(f"[DB 에러 방어] 부모 강의 방 생성 중 오류 발생: {db_err}")

    # 순차 처리를 보장하기 위한 헬퍼 함수
    async def safe_process(audio_data: bytes, room_id: str, lang: str):
        async with lecture_locks[room_id]:
            try:
                await process_lecture_audio(audio_data, room_id, lang)
            except Exception as proc_err:
                print(f"[Process 에러] 오디오 패킷 처리 중 예외 발생: {proc_err}")

    audio_proc = None

    try:
        if is_youtube:
            # [유튜브 주소 자동 복원 시트]
            # 인입된 ID가 11자리 고유 식별자라면, yt-dlp가 분석할 수 있도록 풀 주소로 안전하게 복원 포맷팅합니다.
            yt_url = lecture_id
            if "youtube.com" not in yt_url and "youtu.be" not in yt_url:
                yt_url = f"https://www.youtube.com/watch?v={lecture_id}"

            print(f"[유튜브 자막 엔진] 스트림 추출 시작 -> URL: {yt_url}")
            
            url_proc = await asyncio.create_subprocess_exec(
                'yt-dlp', '--no-playlist', '-g', '-f', 'bestaudio', yt_url,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await url_proc.communicate()
            stdout_str = stdout.decode().strip()

            if not stdout_str:
                raise Exception(f"유튜브 스트리밍 주소 획득 실패: {stderr.decode()}")

            stream_url = stdout_str.splitlines()[0]

            ffmpeg_cmd = [
                'ffmpeg', '-i', stream_url, '-f', 's16le', '-ac', '1', '-ar', '16000', 'pipe:1'
            ]
            audio_proc = await asyncio.create_subprocess_exec(
                *ffmpeg_cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL
            )
            print("[유튜브 자막 엔진] 오디오 실시간 동기화 빨대 꽂기 성공.")

            while True:
                # 100ms 분량의 PCM 오디오 청크 정속 수신 (3200 바이트)
                chunk = await audio_proc.stdout.read(3200)
                if not chunk:
                    print("[유튜브 자막 엔진] 스트리밍 오디오가 종료되었습니다.")
                    break

                asyncio.create_task(safe_process(chunk, lecture_id, target_lang))
                await asyncio.sleep(0.1) # 100ms 페이스메이커 작동

        else:
            while True:
                data = await websocket.receive_bytes()
                asyncio.create_task(safe_process(data, lecture_id, target_lang))

    except WebSocketDisconnect:
        print(f"[WebSocket] {lecture_id} 클라이언트 정상 연결 종료")
    except Exception as e:
        print(f"[WebSocket] {lecture_id} 에러 발생: {e}")
    finally:
        if audio_proc:
            try:
                audio_proc.terminate()
                await audio_proc.wait()
                print("[유튜브 자막 엔진] ffmpeg 프로세스 리소스 소거 완료")
            except:
                pass

        if lecture_id in lecture_buffers: del lecture_buffers[lecture_id]
        if lecture_id in last_received_times: del last_received_times[lecture_id]
        if lecture_id in lecture_locks: del lecture_locks[lecture_id]
        print(f"[WebSocket] {lecture_id} 자원 정리 마감 완료")