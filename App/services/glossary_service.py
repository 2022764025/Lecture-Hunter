"""
<설명>
실시간 전공 용어 추출 및 조회 (Zero-shot & Contextual AI)

(1) 1분마다 최근 2분 맥락으로 추출
    - 예전에는 자막(약 5초 분량)이 나올 때마다 LLM을 불러 문장 조각 하나에서 용어를 뽑았다.
      맥락이 짧아 정의가 틀리고(예: "드롭아웃: 자막을 숨기는 기법"), 번역과 같은 LLM 큐를 두고 경쟁했다.
    - 이제 강의별로 최근 GLOSSARY_CONTEXT_SEC(기본 2분) 자막을 모아 GLOSSARY_INTERVAL_SEC(기본 1분)마다 한 번 추출한다.
(2) 품질 필터
    - 자막에 실제로 나온 표현만 저장해 LLM이 지어낸 용어를 막고, '수업', '오늘' 같은 일반 단어는 거른다.
    - 같은 용어는 처음 저장된 정의를 유지한다 (unique_lecture_term 제약 + ignore_duplicates).
(3) 번역용 용어 목록 캐시 (Glossary Prompting)
    - 번역 프롬프트에 넣을 용어 목록을 강의별로 1분간 캐시한다.
(4) 용어 검색
    - DB에 없는 용어는 LLM이 즉석 설명을 만들고 source='ai'로 표시한다.
    - 작은 모델(gemma2:2b)이 한국어로 바로 정의하면 틀리는 일이 잦아, 영어로 정의한 뒤 한국어로 번역한다.
      영어 원문도 definition_en으로 함께 돌려준다.
"""

import asyncio
import json
import re
import time
from collections import deque
from datetime import datetime, timezone
from typing import Optional

from core import llm
from core.config import settings
from core.database import get_supabase
from services.translation_service import translation_engine

# 강의별 최근 자막 (수신 시각, 텍스트)
_recent: dict[str, deque] = {}
_last_run: dict[str, float] = {}
_chars_since_run: dict[str, int] = {}
_running: set[str] = set()
_terms_cache: dict[str, tuple[float, list[str]]] = {}
_tasks: set[asyncio.Task] = set()

TERMS_CACHE_SEC = 60.0
MIN_CONTEXT_CHARS = 40
MAX_CONTEXT_CHARS = 800
MAX_TERMS_PER_RUN = 3
MAX_OUTPUT_TOKENS = 250     # 용어 3개 + 짧은 정의. 출력이 길수록 M1에서 수십 초씩 걸린다

# 용어로 저장하지 않을 일반 단어
_STOPWORDS = {
    "수업", "강의", "오늘", "내용", "시간", "다음", "이번", "부분", "설명", "질문", "예시", "예제", "문제",
    "복습", "실습", "과제", "시험", "학생", "교수", "여러분", "자막", "서비스", "영상", "화면", "슬라이드",
    "방법", "과정", "경우", "사용", "이해", "정리", "공부", "학습", "개념", "정의", "중요", "기본",
}
_SENTENCE_END_RE = re.compile(r"(니다|어요|아요|해요|세요|죠|다)\.?$")


def _spawn(coro) -> None:
    task = asyncio.create_task(coro)
    _tasks.add(task)
    task.add_done_callback(_tasks.discard)


def _norm(text: str) -> str:
    return re.sub(r"\s+", "", text or "").lower()


def add_caption(lecture_id: str, text: str) -> None:
    """새 자막을 맥락 버퍼에 넣고, 주기가 되면 백그라운드에서 용어를 추출한다."""
    now = time.time()
    dq = _recent.setdefault(lecture_id, deque())
    dq.append((now, text))
    while dq and now - dq[0][0] > settings.GLOSSARY_CONTEXT_SEC:
        dq.popleft()
    _chars_since_run[lecture_id] = _chars_since_run.get(lecture_id, 0) + len(text)

    last = _last_run.setdefault(lecture_id, now)
    if now - last >= settings.GLOSSARY_INTERVAL_SEC:
        _start_extraction(lecture_id)


def _start_extraction(lecture_id: str) -> None:
    if lecture_id in _running:
        return
    context = " ".join(t for _, t in _recent.get(lecture_id, ()))[-MAX_CONTEXT_CHARS:]
    if len(context) < MIN_CONTEXT_CHARS:
        return
    _running.add(lecture_id)
    _last_run[lecture_id] = time.time()
    _chars_since_run[lecture_id] = 0
    _spawn(_extract_and_save(lecture_id, context))


def flush(lecture_id: str) -> None:
    """오디오 연결이 끝날 때 호출. 마지막 추출 이후 쌓인 자막이 있으면 한 번 더 추출하고 상태를 비운다."""
    if _chars_since_run.get(lecture_id, 0) >= MIN_CONTEXT_CHARS:
        _start_extraction(lecture_id)
    _recent.pop(lecture_id, None)
    _last_run.pop(lecture_id, None)
    _chars_since_run.pop(lecture_id, None)


def _parse_terms(raw: str) -> list[dict]:
    raw = (raw or "").strip()
    data = None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        for open_ch, close_ch in (("{", "}"), ("[", "]")):
            start, end = raw.find(open_ch), raw.rfind(close_ch)
            if start != -1 and end > start:
                try:
                    data = json.loads(raw[start:end + 1])
                    break
                except json.JSONDecodeError:
                    continue
    if isinstance(data, dict):
        items = data.get("terms")
        if items is None and "term" in data:
            items = [data]
        data = items
    return [x for x in data if isinstance(x, dict)] if isinstance(data, list) else []


def _valid_terms(items: list[dict], context: str) -> list[dict]:
    ctx = _norm(context)
    seen, valid = set(), []
    for item in items:
        term = item.get("term")
        definition = item.get("definition")
        if isinstance(term, list):
            term = term[0] if term else ""
        if isinstance(definition, list):
            definition = " ".join(map(str, definition))
        term = str(term or "").strip().strip("\"'`·•-–:").strip()
        definition = str(definition or "").strip()

        key = _norm(term)
        if not (2 <= len(term) <= 40) or key in seen:
            continue
        if key not in ctx:                       # 자막에 없는 용어는 LLM이 지어낸 것
            continue
        if term in _STOPWORDS or _SENTENCE_END_RE.search(term):
            continue
        if not (5 <= len(definition) <= 300) or _norm(definition) == key:
            continue
        seen.add(key)
        valid.append({"term": term, "definition": definition})
    return valid[:MAX_TERMS_PER_RUN]


async def _extract_and_save(lecture_id: str, context: str) -> None:
    prompt = f"""당신은 대학 전공 강의의 용어 사전 편집자입니다.
아래 강의 자막에서 학생이 어려워할 만한 전공 용어를 최대 {MAX_TERMS_PER_RUN}개 고르고, 각 용어를 강의 맥락에 맞게 짧은 한 문장(40자 안팎)으로 설명하세요.

규칙:
- 자막에 실제로 나온 표현만 용어로 고르세요. 자막에 없는 용어를 만들지 마세요.
- '수업', '오늘', '내용' 같은 일반 단어와 음성 인식 오류로 보이는 어색한 단어는 고르지 마세요.
- 전공 용어가 없으면 빈 목록을 돌려주세요.
- 다음 JSON 형식으로만 답하세요: {{"terms": [{{"term": "용어", "definition": "한 문장 설명"}}]}}

[강의 자막]
{context}
"""
    try:
        # 1분에 한 번이고 수 초가 걸리는 작업이라 pipeline_lock을 잡지 않는다.
        # 잡으면 그동안 Whisper가 멈춰 자막이 그만큼 밀린다 (실측 13~26초).
        t0 = time.perf_counter()
        raw = await llm.generate(
            prompt, json_mode=True, options={"temperature": 0.1, "num_predict": MAX_OUTPUT_TOKENS}
        )
        took = time.perf_counter() - t0
        terms = _valid_terms(_parse_terms(raw), context)
        if not terms:
            print(f"[Glossary] {lecture_id}: 새로 저장할 용어 없음 ({took:.1f}s)")
            return
        client = await get_supabase()
        await client.table("lecture_glossary").upsert(
            [{"lecture_id": lecture_id, **t} for t in terms],
            on_conflict="lecture_id,term",
            ignore_duplicates=True,
        ).execute()
        _terms_cache.pop(lecture_id, None)
        print(f"[Glossary] {lecture_id} ({took:.1f}s): {', '.join(t['term'] for t in terms)}")
    except Exception as e:
        print(f"[Glossary] {lecture_id} 용어 추출 실패 ({type(e).__name__}): {e}")
    finally:
        _running.discard(lecture_id)


async def get_terms(lecture_id: str, limit: int = 30) -> list[str]:
    """번역 프롬프트에 넣을 이 강의의 용어 목록 (1분 캐시)."""
    cached = _terms_cache.get(lecture_id)
    if cached and time.time() - cached[0] < TERMS_CACHE_SEC:
        return cached[1]
    try:
        client = await get_supabase()
        res = await client.table("lecture_glossary").select("term") \
            .eq("lecture_id", lecture_id).order("created_at", desc=True).limit(limit).execute()
        terms = [r["term"] for r in res.data if r.get("term")]
    except Exception as e:
        print(f"[Glossary] 용어 목록 조회 실패: {e}")
        terms = []
    _terms_cache[lecture_id] = (time.time(), terms)
    return terms


def _escape_like(keyword: str) -> str:
    """ILIKE 패턴 문자(%, _, PostgREST의 *)를 글자 그대로 검색되게 바꾼다."""
    return keyword.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_").replace("*", "")


async def search(lecture_id: str, keyword: Optional[str] = None) -> list[dict]:
    """
    강의 용어집 조회. keyword가 없으면 전체 목록.
    DB에 없는 용어를 검색하면 LLM이 즉석 설명을 만든다 (source='ai', DB에는 저장하지 않음).
    """
    client = await get_supabase()
    query = client.table("lecture_glossary").select("term, definition, created_at") \
        .eq("lecture_id", lecture_id).order("created_at", desc=True)
    keyword = (keyword or "").strip()
    if keyword:
        query = query.ilike("term", f"%{_escape_like(keyword)}%")
    res = await query.execute()
    rows = [{**r, "source": "lecture"} for r in res.data]
    # 글자 없이 기호만 있는 검색어(예: '%')는 AI 설명을 만들지 않는다
    if rows or not keyword or not re.search(r"\w", keyword):
        return rows

    # gemma2:2b는 한국어로 직접 정의를 쓰면 틀리는 경우가 많았다
    # (실측: "드롭아웃 = 훈련 데이터에만 맞춰진 상태"). 영어로 정의한 뒤 번역하면 뜻이 맞았다.
    field = await _lecture_field(lecture_id)
    prompt = (
        f"A university student in a {field} lecture asked what '{keyword}' means "
        "(the term may be written in Korean).\n"
        "Give the standard academic definition in 1-2 short sentences of plain English. "
        "If you are not sure what it means, say so. Output only the definition."
    )
    try:
        definition_en = await llm.generate(prompt, options={"temperature": 0.1, "num_predict": 150})
    except Exception as e:
        print(f"[Glossary] '{keyword}' 즉석 설명 실패: {e}")
        raise
    definition = await translation_engine.translate(
        definition_en, "Korean", source_lang="English", glossary_terms=[keyword], multiline=True
    )
    return [{
        "term": keyword,
        "definition": definition or definition_en,
        "definition_en": definition_en,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source": "ai",
    }]


async def _lecture_field(lecture_id: str) -> str:
    """lectures 테이블의 전공/과목 정보. 없으면 일반적인 분야 이름."""
    try:
        client = await get_supabase()
        res = await client.table("lectures").select("major, subject").eq("id", lecture_id).limit(1).execute()
        if res.data:
            parts = [res.data[0].get("major"), res.data[0].get("subject")]
            text = " / ".join(p for p in parts if p)
            if text:
                return text
    except Exception:
        pass
    return "university (computer science / AI)"
