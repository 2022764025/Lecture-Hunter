import ollama
from core.config import settings
from supabase import create_async_client

# 대화 기록을 저장할 메모리 (실제 서비스에서는 Redis나 DB 추천)
chat_history = [] 

async def get_answer_with_memory(question: str, lecture_id: str):
    global chat_history
    supabase = await create_async_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)

    # 1. 질문 임베딩 및 DB 검색 (기존 로직 유지)
    q_emb_resp = ollama.embeddings(model='nomic-embed-text', prompt=question)
    rpc_resp = await supabase.rpc('match_lecture_contents', {
        'query_embedding': q_emb_resp['embedding'],
        'match_threshold': 0.4, # 검색 범위를 살짝 넓힘
        'match_count': 3,
        'p_lecture_id': lecture_id
    }).execute()

    context = "\n".join([item['original_text'] for item in rpc_resp.data])

    # 2. 대화 기록(History) 구성
    history_context = "\n".join([f"Q: {h['q']}\nA: {h['a']}" for h in chat_history[-3:]]) # 최근 3개 대화만 유지

    # 3. 프롬프트 구성 (문맥 + 대화 기록 추가)
    prompt = f"""
    당신은 강의 보조 AI입니다. 아래 [강의 내용]과 [이전 대화]를 참고하여 [학생의 질문]에 답하세요.
    
    [강의 내용]:
    {context}
    
    [이전 대화]:
    {history_context}
    
    [학생의 질문]:
    {question}
    """

    response = ollama.generate(model='gemma2:2b', prompt=prompt)
    answer = response['response']

    # 4. 메모리에 현재 대화 저장
    chat_history.append({"q": question, "a": answer})
    return answer