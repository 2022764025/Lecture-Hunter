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
from core.database import get_supabase # 싱글턴 중앙화

# 순환 참조 방지: rag_service에서 가져오지 않고 독립 선언
ollama_client = ollama.AsyncClient()

CHUNK_SIZE = 100  # 청크당 문장 수


async def _summarize_chunk(chunk_text: str, chunk_index: int) -> str:
    """
    1차 요약: 청크 하나를 간단히 요약
    """
    prompt = f"""
    아래는 강의의 일부분입니다. 핵심 내용을 3문장 이내로 요약하세요.
    설명 없이 요약문만 출력하세요.

    [강의 내용]:
    {chunk_text}
    """
    try:
        response = await ollama_client.generate(model='gemma2:2b', prompt=prompt)
        result = response['response'].strip()
        print(f"[Summary] 청크 {chunk_index} 요약 완료")
        return result
    except Exception as e:
        print(f"[Summary] 청크 {chunk_index} 요약 에러: {e}")
        return ""


async def _final_summarize(chunk_summaries: list[str]) -> str:
    """
    2차 요약: 1차 요약들을 합쳐 최종 3줄 요약 + 키워드 5개 생성
    """
    combined = "\n".join(chunk_summaries)
    prompt = f"""
    아래는 강의 전체를 구간별로 요약한 내용입니다.
    이를 바탕으로 강의 전체의 3줄 요약과 핵심 키워드 5개를 뽑아주세요.
    형식: [요약] 내용... [키워드] k1, k2, k3, k4, k5

    [구간별 요약]:
    {combined}
    """
    try:
        response = await ollama_client.generate(model='gemma2:2b', prompt=prompt)
        return response['response'].strip()
    except Exception as e:
        print(f"[Summary] 최종 요약 에러: {e}")
        return "최종 요약 생성 중 오류가 발생했습니다."


async def generate_lecture_summary(lecture_id: str) -> str:
    supabase = await get_supabase()

    # 1. 전체 자막 가져오기 (시간순)
    resp = await supabase.table("lecture_contents") \
        .select("original_text") \
        .eq("lecture_id", lecture_id) \
        .order("created_at", desc=False) \
        .execute()

    if not resp.data:
        return "요약할 내용이 없습니다."

    sentences = [item['original_text'] for item in resp.data if item['original_text']]

    if not sentences:
        return "요약할 내용이 없습니다."

    # 2. Recursive Summarization
    # 2-1. 100문장씩 청크 분할 후 1차 요약
    chunks = [
        sentences[i:i + CHUNK_SIZE]
        for i in range(0, len(sentences), CHUNK_SIZE)
    ]

    print(f"[Summary] 전체 {len(sentences)}문장 → {len(chunks)}개 청크로 분할")

    # 청크가 1개면 바로 최종 요약으로
    if len(chunks) == 1:
        chunk_text = " ".join(chunks[0])
        summary_result = await _final_summarize([chunk_text])
    else:
        # 1차 요약 (청크별 순차 처리)
        chunk_summaries = []
        for i, chunk in enumerate(chunks):
            chunk_text = " ".join(chunk)
            summary = await _summarize_chunk(chunk_text, i + 1)
            if summary:
                chunk_summaries.append(summary)

        if not chunk_summaries:
            return "요약 생성 중 오류가 발생했습니다."

        # 2차 요약 (최종)
        summary_result = await _final_summarize(chunk_summaries)

    # 3. upsert로 중복 저장 방지
    try:
        await supabase.table("lecture_summaries").upsert({
            "lecture_id": lecture_id,
            "summary_text": summary_result
        }, on_conflict="lecture_id").execute()
        print(f"[Summary] DB 저장 완료: {lecture_id}")
    except Exception as e:
        print(f"[Summary] DB 저장 에러: {e}")

    return summary_result