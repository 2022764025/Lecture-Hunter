"""
<설명>
본 모듈은 "학생 질문 -> 벡터 검색(Retrieval) -> 컨텍스트 강화 -> LLM 답변 생성(Generation)"으로 이어지는 
핵심 RAG 파이프라인 및 대화 컨텍스트 관리 엔진입니다.

(1) 컨텍스트 강화 유사도 검색 (Retrieval)
    - 학생이 위젯을 통해 질문을 던지면, nomic-embed-text 모델로 질문을 벡터화한 후 
        Supabase RPC(match_lecture_contents)를 호출해 가장 연관성 높은 강의 자막 컨텍스트 3개를 추출합니다.
        이때 [ko], [en] 등 다국어 소스 태그를 꼬리표로 붙여 AI가 맥락을 정확히 인지하도록 유도합니다.
(2) 대화 메모리 및 슬라이딩 윈도우 (Memory)
    - 강의 세션별(`lecture_id`) 독립된 chat_histories를 관리하며, 최근 3개의 대화 요약을 Prompt에 주입합니다.
        메모리 과부하를 방지하기 위해 최대 10개까지만 대화를 유지하는 Sliding Window(pop(0)) 방식을 채택했습니다.
(3) 자동 자원 회수 인프라 (Memory Optimization)
    - 대화가 끝난 세션이 메모리를 점유하는 것을 막기 위해 1시간(TTL) 동안 접근이 없는 히스토리를 
        자동으로 감지하고 소거하는 백그라운드 클린업 로직이 반영되어 있습니다.

<추가>
(1) 중복 답변 방지
    - 모델과 방지 로직이 없어서 로직을 추가, 나중에 모델만 교체하면 됌.
"""

import asyncio
import ollama
import time
from core.config import settings
from core.database import get_supabase

# Ollama 비동기 클라이언트 (싱글톤)
ollama_client = ollama.AsyncClient()

# 학생/강의별 히스토리 분리 (lecture_id 기준)
chat_histories: dict = {}
history_last_access: dict = {} # TTL 추적용
HISTORY_TTL_SEC = 3600 # 1시간 미접근 시 삭제

async def cleanup_old_histories():
    """
    TTL 기반 메모리 정리
    미접근 강의 히스토리를 삭제하여 메모리 누수 방지
    main.py의 lifespan 또는 주기적 태스크에서 호출
    """
    now = time.time()
    expired = [
        lid for lid, t in history_last_access.items()
        if now - t > HISTORY_TTL_SEC
    ]
    for lid in expired:
        chat_histories.pop(lid, None)
        history_last_access.pop(lid, None)
        print(f"[History] {lid} 히스토리 만료 삭제")

async def get_answer_with_memory(question: str, lecture_id: str, target_lang: str = "Korean") -> str:
    """
    RAG 기반 질문 답변 (강의 내용 + 대화 히스토리 참고)
    """
    if not question:
        return ""

    try:
        supabase = await get_supabase()

        # lecture_id별 히스토리 분리
        if lecture_id not in chat_histories:
            chat_histories[lecture_id] = []
        history = chat_histories[lecture_id]
        history_last_access[lecture_id] = time.time()  # 접근 시간 갱신

        # 질문을 벡터로 변환 (비동기)
        q_emb_resp = await ollama_client.embeddings(
            model='nomic-embed-text',
            prompt=question
        )

        # 벡터 유사도 검색으로 관련 강의 내용 가져오기
        rpc_resp = await supabase.rpc('match_lecture_contents', {
            'query_embedding': q_emb_resp['embedding'],
            'match_threshold': 0.4,
            'match_count': 3,
            'p_lecture_id': lecture_id
        }).execute()

        # 검색된 강의 내용 컨텍스트 구성
        context = "\n".join([
            f"[{item.get('source_lang', 'unknown')}] {item['original_text']}" 
            for item in rpc_resp.data
        ]) if rpc_resp.data else "관련 강의 내용 없음"

        # 최근 3개 대화 히스토리
        history_context = "\n".join([
            f"Q: {h['q']}\nA: {h['a']}" for h in history[-3:]
        ]) if history else "없음"

        prompt = f"""
        당신은 강의 보조 AI입니다. 아래 [강의 내용]과 [이전 대화]를 참고하여 [학생의 질문]에 답하세요.
        [강의 내용]의 각 문장은 [ko], [en], [zh], [ja] 등 원문 언어가 표시되어 있습니다. 특정 언어로 설명된 부분을 묻는다면 해당 표시를 참고하여 답변하세요.

        한국어로 답변하세요. 모르면 모른다고 하세요.

        [강의 내용]: {context}
        [이전 대화]: {history_context}
        [학생의 질문]: {question}
        """

        # LLM 답변 생성 (비동기)
        response = await ollama_client.generate(
            model=settings.LLM_MODEL,
            prompt=prompt
        )
        answer = response['response'].strip()

        # 히스토리 저장 (최대 10개 유지)
        history.append({"q": question, "a": answer})
        if len(history) > 10:
            history.pop(0)

        return answer

    except Exception as e:
        print(f"get_answer_with_memory 오류: {e}")
        raise

def reset_lecture_history(lecture_id: str) -> bool:
    """
    특정 강의의 질문 히스토리 초기화
    Flutter "새 질문 시작" 버튼에서 호출
    """
    if lecture_id in chat_histories:
        chat_histories.pop(lecture_id, None)
        history_last_access.pop(lecture_id, None)
        print(f"[History] {lecture_id} 히스토리 초기화 완료")
        return True
    return False