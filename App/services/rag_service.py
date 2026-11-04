"""
<설명>
본 모듈은 "학생 질문 -> 벡터 검색(Retrieval) -> 컨텍스트 강화 -> LLM 답변 생성(Generation)"으로 이어지는
핵심 RAG 파이프라인 및 대화 컨텍스트 관리 엔진입니다.

(1) 컨텍스트 강화 유사도 검색 (Retrieval)
    - 질문을 nomic-embed-text로 벡터화한 뒤 Supabase RPC(match_lecture_contents)로 관련 자막을 찾습니다.
    - "방금 뭐라고 했어?" 같은 질문은 벡터 검색으로 찾기 어려워서, 가장 최근 자막도 함께 넣습니다.
(2) 환각 방지 규칙
    - 강의 자막을 근거로 답하고, 강의에서 다루지 않은 내용이면 그렇다고 먼저 밝히게 합니다.
    - 날씨·주식처럼 강의와 무관한 질문은 정중히 거절합니다.
    - 답변과 함께 근거 자막(sources)을 돌려줘 화면에서 확인할 수 있게 합니다.
(3) 대화 메모리 및 슬라이딩 윈도우 (Memory)
    - (강의, 학생) 단위로 대화를 따로 저장합니다. 예전에는 강의 단위라 같은 강의의 학생 전원이
      대화 기록을 공유했고, 한 명이 초기화하면 모두 초기화됐습니다.
    - 최근 3개 대화를 프롬프트에 넣고, 최대 10개까지만 보관합니다.
(4) 자동 자원 회수 (Memory Optimization)
    - 1시간(TTL) 동안 접근이 없는 대화는 main.py의 주기 작업이 지웁니다.
"""

import time
from typing import Optional

from core import llm
from core.database import get_supabase
from core.lang import prompt_lang_name

ANONYMOUS = "anonymous"
HISTORY_TTL_SEC = 3600
MAX_HISTORY = 10

# (lecture_id, client_id) -> [{"q": ..., "a": ...}]
chat_histories: dict[tuple[str, str], list[dict]] = {}
history_last_access: dict[tuple[str, str], float] = {}


def _key(lecture_id: str, client_id: Optional[str]) -> tuple[str, str]:
    return lecture_id, (client_id or ANONYMOUS)


async def cleanup_old_histories() -> int:
    now = time.time()
    expired = [k for k, t in history_last_access.items() if now - t > HISTORY_TTL_SEC]
    for k in expired:
        chat_histories.pop(k, None)
        history_last_access.pop(k, None)
    if expired:
        print(f"[History] 만료된 대화 {len(expired)}개 삭제")
    return len(expired)


async def get_answer_with_memory(
    question: str,
    lecture_id: str,
    target_lang: str = "Korean",
    client_id: Optional[str] = None,
) -> dict:
    """
    RAG 기반 질문 답변 (강의 자막 + 대화 기록 참고)
    반환: {"answer": str, "sources": [{"id", "text", "similarity"}]}
    """
    question = (question or "").strip()
    if not question:
        return {"answer": "", "sources": []}

    key = _key(lecture_id, client_id)
    history = chat_histories.setdefault(key, [])
    history_last_access[key] = time.time()

    supabase = await get_supabase()

    q_embedding = await llm.embed(question)
    rpc = await supabase.rpc("match_lecture_contents", {
        "query_embedding": q_embedding,
        "match_threshold": 0.4,
        "match_count": 4,
        "p_lecture_id": lecture_id,
    }).execute()
    related = rpc.data or []

    recent_res = await supabase.table("lecture_contents").select("id, original_text") \
        .eq("lecture_id", lecture_id).order("id", desc=True).limit(4).execute()
    recent = list(reversed(recent_res.data or []))

    related_ids = {r["id"] for r in related}
    related_text = "\n".join(f"- {r['original_text']}" for r in related) or "(관련 자막 없음)"
    recent_text = "\n".join(
        f"- {r['original_text']}" for r in recent if r["id"] not in related_ids and r.get("original_text")
    ) or "(없음)"
    history_text = "\n".join(f"Q: {h['q']}\nA: {h['a']}" for h in history[-3:]) or "(없음)"
    language = prompt_lang_name(target_lang)

    prompt = f"""You are a teaching assistant for a university lecture. Answer the student's question.

Rules:
1. Base your answer on the lecture transcript below. The transcript comes from speech recognition and may contain typos.
2. If the transcript does not cover the question but it is an academic question related to the lecture, first say in one sentence that it was not covered in the lecture, then give a short general explanation.
3. If the question is unrelated to the lecture (e.g., weather, stocks, personal matters), politely decline in one sentence.
4. Never invent what the professor said. If you are not sure, say so instead of guessing.
5. Write the entire answer in {language} only, in at most 5 sentences.

[Lecture transcript related to the question]
{related_text}

[Most recent lecture transcript]
{recent_text}

[Previous conversation]
{history_text}

[Student question]
{question}

Answer in {language}:"""

    answer = await llm.generate(prompt, options={"temperature": 0.3})

    history.append({"q": question, "a": answer})
    if len(history) > MAX_HISTORY:
        history.pop(0)

    sources = [
        {"id": r["id"], "text": r["original_text"], "similarity": round(float(r.get("similarity", 0)), 3)}
        for r in related
    ]
    return {"answer": answer, "sources": sources}


def reset_lecture_history(lecture_id: str, client_id: Optional[str] = None) -> int:
    """
    질문 히스토리 초기화 (Flutter "새 질문 시작" 버튼).
    client_id를 주면 그 학생 기록만, 없으면 이 강의의 익명 기록만 지운다.
    """
    key = _key(lecture_id, client_id)
    removed = 1 if chat_histories.pop(key, None) is not None else 0
    history_last_access.pop(key, None)
    if removed:
        print(f"[History] {lecture_id}/{key[1]} 히스토리 초기화")
    return removed
