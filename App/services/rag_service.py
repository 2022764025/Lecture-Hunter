"""
<설명>
이 코드는 "질문 -> 검색 -> [이전 대화 기억] -> [언어 정보 참고] -> 답변"에 더해 "자막 저장(Indexing)" 기능이다.

(1) 벡터 데이터 파이프라인
    - index_lecture_content 함수가 STT 자막을 실시간으로 받아 벡터 좌표로 변환한 뒤 Supabase DB에 저장 (768차원 의미 공간에 배치)
(2) 컨텍스트 강화 검색
    - 학생이 질문하면, DB에서 가장 관련 있는 자막 3개를 찾아온다. 자막 앞에 [ko], [zh] 같은 꼬리표를 붙여서 AI가 "이건 중국어 설명이었구나"라고 인지
(3) 슬라이딩 윈도우 메모리
    - chat_histories를 통해 최근 10개의 대화를 기억한다. history.pop(0) 로직을 통해 고정된 메모리 크기(Sliding Window)를 유지
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
        answer = response['response']

        # 히스토리 저장 (최대 10개 유지)
        history.append({"q": question, "a": answer})
        if len(history) > 10:
            history.pop(0)

        return answer

    except Exception as e:
        print(f"get_answer_with_memory 오류: {e}")
        raise