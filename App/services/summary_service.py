import ollama
from core.config import settings
from supabase import create_async_client

async def generate_lecture_summary(lecture_id: str):
    supabase = await create_async_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)

    # 1. 해당 강의의 전체 텍스트 가져오기
    resp = await supabase.table("lecture_contents").select("original_text").eq("lecture_id", lecture_id).execute()
    full_text = " ".join([item['original_text'] for item in resp.data])

    if not full_text: return "요약할 내용이 없습니다."

    # 2. Gemma-2를 이용한 요약 및 키워드 추출
    prompt = f"""
    아래 강의 내용을 바탕으로 3줄 요약과 핵심 키워드 5개를 뽑아주세요.
    형식: [요약] 내용... [키워드] k1, k2, k3...
    
    [강의 내용]:
    {full_text}
    """

    response = ollama.generate(model='gemma2:2b', prompt=prompt)
    summary_result = response['response']

    # 3. 결과 저장 (lecture_summaries 테이블)
    await supabase.table("lecture_summaries").insert({
        "lecture_id": lecture_id,
        "summary_text": summary_result
    }).execute()

    return summary_result