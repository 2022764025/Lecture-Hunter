"""
<설명>
(1) 텍스트 코퍼스 어그리게이션 (Aggregation)
    - Supabase에서 강의(lecture_id) 자막을 시간순으로 모은다.
    - Supabase는 한 번에 최대 1,000행만 돌려주므로 페이지 단위로 끝까지 읽는다 (긴 강의 누락 방지).
(2) 요약 범위 3가지
    - 최근 N분 (Adaptive Briefing): 지각생이나 잠깐 딴생각한 학생용. 최대 180분.
    - 구간 요약: 강의 시작(첫 자막) 기준 start_min ~ end_min 분 구간.
    - 전체 요약: 강의 전체. 강의 종료(/lecture/end) 때 저장하고, 화면에서 다시 불러올 수 있다.
(3) Recursive Summarization + JSON 구조화 출력
    - 자막이 길면 구간별로 먼저 요약한 뒤 다시 합쳐 요약한다 (gemma2 문맥 길이 한계 대응).
    - 마지막 요약은 JSON(summary 3문장 + keywords)으로 받아 파싱 오류를 줄이고, 키워드는 key_points에 저장한다.
    - "자막에 없는 내용은 추측하지 말 것"을 프롬프트에 명시한다.
(4) 데이터 영속화 (Persistence)
    - 결과를 lecture_summaries에 저장한다. summary_type: 'adaptive'(최근 N분), 'range'(구간), 'full'(전체)
    - 'full'은 강의당 1개만 둔다. DB의 부분 유니크 인덱스(WHERE summary_type='full')는
      upsert(on_conflict)로 맞출 수 없어(42P10 에러) 조회 후 update/insert 한다.
"""

import json
from datetime import datetime, timedelta, timezone
from typing import Optional

from core import llm
from core.database import get_supabase
from core.lang import korean_lang_name

PAGE_SIZE = 1000
CHUNK_CHARS = 2500       # 한 번에 LLM에 넣는 자막 길이 (gemma2:2b 기본 문맥 4096 토큰 고려)
MAX_RECENT_MINUTES = 180


def _parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


async def fetch_captions(
    lecture_id: str,
    since: Optional[datetime] = None,
    until: Optional[datetime] = None,
) -> list[dict]:
    client = await get_supabase()
    rows: list[dict] = []
    start = 0
    while True:
        query = client.table("lecture_contents").select("id, original_text, created_at").eq("lecture_id", lecture_id)
        if since:
            query = query.gte("created_at", since.isoformat())
        if until:
            query = query.lte("created_at", until.isoformat())
        res = await query.order("id").range(start, start + PAGE_SIZE - 1).execute()
        rows.extend(res.data)
        if len(res.data) < PAGE_SIZE:
            break
        start += PAGE_SIZE
    return [r for r in rows if (r.get("original_text") or "").strip()]


async def lecture_timeline(lecture_id: str) -> dict:
    """첫 자막/마지막 자막 시각과 자막 수. 강의 경과 시간 표시와 구간 요약 기준점으로 쓴다."""
    client = await get_supabase()
    first = await client.table("lecture_contents").select("created_at") \
        .eq("lecture_id", lecture_id).order("id").limit(1).execute()
    if not first.data:
        return {"started_at": None, "last_caption_at": None, "caption_count": 0}
    last = await client.table("lecture_contents").select("created_at") \
        .eq("lecture_id", lecture_id).order("id", desc=True).limit(1).execute()
    count = await client.table("lecture_contents").select("id", count="exact") \
        .eq("lecture_id", lecture_id).limit(1).execute()
    return {
        "started_at": first.data[0]["created_at"],
        "last_caption_at": last.data[0]["created_at"],
        "caption_count": count.count or 0,
    }


def _chunks(sentences: list[str]) -> list[str]:
    chunks, current = [], ""
    for s in sentences:
        if current and len(current) + len(s) + 1 > CHUNK_CHARS:
            chunks.append(current)
            current = s
        else:
            current = f"{current} {s}".strip()
    if current:
        chunks.append(current)
    return chunks


async def _summarize_chunk(text: str, language: str) -> str:
    prompt = f"""아래는 대학 강의의 일부분 자막입니다. 자막에 있는 내용만으로 핵심을 3문장 이내로 요약하세요.
설명 없이 요약문만 {language}로 출력하세요.

[자막]
{text}
"""
    return await llm.generate(prompt, options={"temperature": 0.2})


def _parse_summary(raw: str) -> tuple[list[str], list[str]]:
    data = None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        start, end = raw.find("{"), raw.rfind("}")
        if start != -1 and end > start:
            try:
                data = json.loads(raw[start:end + 1])
            except json.JSONDecodeError:
                data = None
    if not isinstance(data, dict):
        return [raw.strip()] if raw.strip() else [], []

    summary = data.get("summary") or []
    if isinstance(summary, str):
        summary = [line.strip(" -•") for line in summary.splitlines() if line.strip()]
    keywords = data.get("keywords") or []
    if isinstance(keywords, str):
        keywords = [k.strip() for k in keywords.split(",")]
    lines = [str(s).strip() for s in summary if str(s).strip()][:5]
    keys = list(dict.fromkeys(str(k).strip() for k in keywords if str(k).strip()))[:5]
    return lines, keys


async def _summarize(sentences: list[str], scope: str, target_lang: str) -> dict:
    language = korean_lang_name(target_lang)
    chunks = _chunks(sentences)
    if len(chunks) > 1:
        print(f"[Summary] {len(sentences)}문장 → {len(chunks)}개 구간으로 나눠 1차 요약")
        partials = []
        for chunk in chunks:
            try:
                partials.append(await _summarize_chunk(chunk, language))
            except Exception as e:
                print(f"[Summary] 구간 요약 실패: {e}")
        text = "\n".join(p for p in partials if p)
        if not text:
            raise RuntimeError("구간 요약이 모두 실패했습니다.")
        scope = f"{scope}(구간별 요약본)"
    else:
        text = chunks[0] if chunks else ""

    prompt = f"""아래는 대학 강의 {scope}의 실시간 자막입니다. 음성 인식 결과라 오탈자가 있을 수 있습니다.
자막에 나온 내용만 사용해서 요약하세요. 자막에 없는 내용은 추측하거나 덧붙이지 마세요.
모든 문장은 {language}로 작성하세요.

다음 JSON 형식으로만 답하세요:
{{"summary": ["핵심 내용 1", "핵심 내용 2", "핵심 내용 3"], "keywords": ["키워드1", "키워드2", "키워드3"]}}
- summary: 핵심 내용 3개, 각각 한 문장
- keywords: 강의에 나온 핵심 용어 3~5개

[자막]
{text}
"""
    raw = await llm.generate(prompt, json_mode=True, options={"temperature": 0.2})
    lines, keywords = _parse_summary(raw)
    if not lines:
        raise RuntimeError("요약 결과가 비어 있습니다.")
    return {"summary": "\n".join(f"• {line}" for line in lines), "key_points": keywords}


async def _save(lecture_id: str, summary_type: str, result: dict) -> None:
    client = await get_supabase()
    row = {
        "lecture_id": lecture_id,
        "summary_text": result["summary"],
        "summary_type": summary_type,
        "key_points": result.get("key_points") or [],
    }
    try:
        if summary_type == "full":
            existing = await client.table("lecture_summaries").select("id") \
                .eq("lecture_id", lecture_id).eq("summary_type", "full").limit(1).execute()
            if existing.data:
                await client.table("lecture_summaries").update(row).eq("id", existing.data[0]["id"]).execute()
                return
        await client.table("lecture_summaries").insert(row).execute()
    except Exception as e:
        print(f"[Summary] DB 저장 실패 ({summary_type}): {e}")


def _empty(message: str, **extra) -> dict:
    return {"summary": message, "key_points": [], "caption_count": 0, "empty": True, **extra}


async def generate_adaptive_summary(lecture_id: str, minutes: int = 5, target_lang: str = "Korean") -> dict:
    """최근 N분 자막 요약 (Adaptive Briefing)"""
    minutes = max(1, min(int(minutes), MAX_RECENT_MINUTES))
    since = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    rows = await fetch_captions(lecture_id, since=since)
    if not rows:
        return _empty(f"최근 {minutes}분간 강의 내용이 없습니다.", minutes=minutes)

    print(f"[Adaptive] {lecture_id} 최근 {minutes}분 | {len(rows)}문장 요약")
    result = await _summarize([r["original_text"] for r in rows], f"최근 {minutes}분", target_lang)
    await _save(lecture_id, "adaptive", result)
    return {**result, "caption_count": len(rows), "minutes": minutes, "empty": False}


async def generate_range_summary(lecture_id: str, start_min: float, end_min: float,
                                 target_lang: str = "Korean") -> dict:
    """강의 시작(첫 자막) 기준 start_min ~ end_min 분 구간 요약"""
    timeline = await lecture_timeline(lecture_id)
    if not timeline["started_at"]:
        return _empty("아직 강의 자막이 없습니다.", start_min=start_min, end_min=end_min)

    started = _parse_time(timeline["started_at"])
    since = started + timedelta(minutes=start_min)
    until = started + timedelta(minutes=end_min)
    rows = await fetch_captions(lecture_id, since=since, until=until)
    label = f"{_fmt_min(start_min)}~{_fmt_min(end_min)} 구간"
    if not rows:
        return _empty(f"{label}에 강의 내용이 없습니다.", start_min=start_min, end_min=end_min)

    print(f"[Range] {lecture_id} {label} | {len(rows)}문장 요약")
    result = await _summarize([r["original_text"] for r in rows], label, target_lang)
    await _save(lecture_id, "range", result)
    return {**result, "caption_count": len(rows), "start_min": start_min, "end_min": end_min, "empty": False}


async def generate_lecture_summary(lecture_id: str, target_lang: str = "Korean") -> dict:
    """강의 전체 요약. 강의당 1개('full')로 저장한다."""
    rows = await fetch_captions(lecture_id)
    if not rows:
        return _empty("요약할 내용이 없습니다.")

    print(f"[Summary] {lecture_id} 전체 {len(rows)}문장 요약")
    result = await _summarize([r["original_text"] for r in rows], "전체", target_lang)
    await _save(lecture_id, "full", result)
    return {**result, "caption_count": len(rows), "empty": False}


async def get_saved_full_summary(lecture_id: str) -> Optional[dict]:
    client = await get_supabase()
    res = await client.table("lecture_summaries").select("summary_text, key_points, created_at") \
        .eq("lecture_id", lecture_id).eq("summary_type", "full").limit(1).execute()
    if not res.data:
        return None
    row = res.data[0]
    return {"summary": row["summary_text"], "key_points": row.get("key_points") or [],
            "created_at": row["created_at"], "empty": False}


def _fmt_min(value: float) -> str:
    total = int(round(value))
    return f"{total // 60:02d}:{total % 60:02d}"
