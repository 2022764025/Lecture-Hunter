### 학생이 "방금 뭐라고 했어 ?"라고 물었을 때 작동할 로직이다 ###

import ollama
from services.stt_service import get_supabase

async def answer_student_question(lecture_id: str, question: str):
    client = await get_supabase()
    
    # 1. 질문을 벡터로 변환
    q_embed = ollama.embeddings(model='nomic-embed-text', prompt=question)['embedding']
    
    # 2. 벡터 유사도 검색 (가장 관련 있는 자막 3개 추출)
    # Supabase의 rpc 기능을 사용하거나 유사도 쿼리를 작성한다.
    rpc_response = await client.rpc('match_lecture_contents', {
        'query_embedding': q_embed,
        'match_threshold': 0.5,
        'match_count': 3,
        'p_lecture_id': lecture_id
    }).execute()
    
    context = " ".join([item['original_text'] for item in rpc_response.data])
    
    # 3. 답변 생성 (Gemma-2)
    prompt = f"Based on the following lecture context, answer the student's question concisely.\nContext: {context}\nQuestion: {question}"
    
    response = ollama.chat(model='gemma2:2b', messages=[
        {'role': 'system', 'content': 'You are a helpful teaching assistant.'},
        {'role': 'user', 'content': prompt}
    ])
    
    return response['message']['content']