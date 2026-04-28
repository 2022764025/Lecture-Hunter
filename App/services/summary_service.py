"""
<설명>
(1) 텍스트 코퍼스 어그리게이션 (Aggregation)
    - Supabase에서 해당 강의(lecture_id)의 모든 자막을 긁어모아 하나의 긴 텍스트(full_text)로 합침.
    강의 전체의 맥락을 LLM에게 한 번에 전달할 수 있다.
(2) LLM 요약 및 엔티티 추출 (Gemma-2:2b)
    - 가벼운 Gemma-2 모델을 사용하여 3줄 요약과 키워드 5개를 뽑음. (나중에 모델 교체)
    "개념 저장소(NoteLLM)"로 가는 기술, 학생들이 긴 강의를 다 볼 필요 없이 핵심만 파악하게 해준다.
(3) 데이터 영속화 (Persistence)
    - 결과를 단순히 보여주고 끝내는 게 아니라 lecture_summaries 테이블에 따로 저장.
    나중에 학생 대시보드나 모바일 앱에서 '복습 탭'을 누르면 즉시 요약을 보여줄 수 있는 근거 데이터가 된다.
"""

import ollama
from core.config import settings
from supabase import create_async_client
from services.rag_service import ollama_client

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

    response = await ollama_client.generate(model='gemma2:2b', prompt=prompt)
    summary_result = response['response']

    # 3. 결과 저장 (lecture_summaries 테이블)
    await supabase.table("lecture_summaries").insert({
        "lecture_id": lecture_id,
        "summary_text": summary_result
    }).execute()

    return summary_result