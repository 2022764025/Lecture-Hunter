import asyncio
import ollama
from core.config import settings
from supabase import create_async_client

# Ollama 비동기 클라이언트 (싱글톤)
ollama_client = ollama.AsyncClient()

# Supabase 클라이언트 캐싱
_supabase_client = None
async def get_supabase():
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = await create_async_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_ANON_KEY
        )
    return _supabase_client

# 학생/강의별 히스토리 분리 (lecture_id 기준)
chat_histories: dict = {}

async def index_lecture_content(lecture_id: str, original: str, translated: str):
    """
    STT로 생성된 자막을 벡터화하여 DB에 저장
    나중에 get_answer_with_memory에서 RAG 검색에 사용됨
    """
    if not original:
        return

    try:
        supabase = await get_supabase()

        # 텍스트를 벡터(768차원)로 변환 (비동기)
        q_emb_resp = await ollama_client.embeddings(
            model='nomic-embed-text',
            prompt=original
        )

        # DB에 Insert
        await supabase.table("lecture_contents").insert({
            "lecture_id":        lecture_id,
            "original_text":     original,
            "translated_text":   translated,
            "content_embedding": q_emb_resp['embedding']
        }).execute()

        print(f"✅ 자막 저장 완료: {original[:30]}...")

    except Exception as e:
        print(f"❌ index_lecture_content 오류: {e}")
        raise

async def get_answer_with_memory(question: str, lecture_id: str) -> str:
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

        # 질문을 벡터로 변환 (비동기)
        q_emb_resp = await ollama_client.embeddings(
            model='nomic-embed-text',
            prompt=question
        )

        # 벡터 유사도 검색으로 관련 강의 내용 가져오기
        rpc_resp = await supabase.rpc('match_lecture_contents', {
            'query_embedding': q_emb_resp['embedding'],
            'match_threshold': 0.4,
            'match_count':     3,
            'p_lecture_id':    lecture_id
        }).execute()

        # 검색된 강의 내용 컨텍스트 구성
        context = "\n".join([
            item['original_text'] for item in rpc_resp.data
        ]) if rpc_resp.data else "관련 강의 내용 없음"

        # 최근 3개 대화 히스토리
        history_context = "\n".join([
            f"Q: {h['q']}\nA: {h['a']}" for h in history[-3:]
        ]) if history else "없음"

        prompt = f"""
        당신은 강의 보조 AI입니다. 아래 [강의 내용]과 [이전 대화]를 참고하여 [학생의 질문]에 답하세요.
        한국어로 답변하세요. 모르면 모른다고 하세요.

        [강의 내용]: {context}
        [이전 대화]: {history_context}
        [학생의 질문]: {question}
        """

        # LLM 답변 생성 (비동기)
        response = await ollama_client.generate(
            model='gemma2:2b',
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