"""
<설명>
교수자-학생 상호작용: 익명 질문 게시판과 강의 공지

(1) 익명 질문 (lecture_questions)
    - 학생이 질문을 남기면 바로 저장하고, 프론트는 Supabase Realtime으로 새 질문을 받는다.
    - client_id는 브라우저마다 만든 임의 문자열이다. 이름·계정이 아니어서 익명성이 유지되고,
      "내가 쓴 질문" 표시와 중복 전송 방지에만 쓴다.
(2) AI 질문 다듬기 (질문 보조)
    - "질문을 바로 교수님께 전달" vs "AI가 정리한 뒤 전달"을 비교할 수 있게,
      학생이 원하면 LLM이 질문을 한두 문장으로 다듬은 제안을 돌려준다. 저장은 학생이 확인한 뒤 한다.
      어떤 방식으로 보냈는지 is_ai_refined에 남긴다.
    - 다듬은 결과에 원래 질문의 핵심 단어가 없으면(주제가 바뀌면) 원문을 그대로 돌려준다.
(3) 공지 (lecture_notices)
    - 교수자 대시보드가 없어서 Supabase 대시보드에서 직접 입력한다.
    - lecture_id가 비어 있는 공지는 모든 강의에 보이는 전체 공지다.
"""

import re
from datetime import datetime, timezone
from typing import NoReturn, Optional

from core import llm
from core.database import ensure_lecture, get_supabase

SQL_FILE = "App/sql/002_questions_notices.sql"


class TableMissingError(RuntimeError):
    def __init__(self, table: str):
        super().__init__(f"Supabase에 {table} 테이블이 없습니다. {SQL_FILE}을 SQL Editor에서 실행하세요.")
        self.table = table


def _raise_if_missing(e: Exception, table: str) -> NoReturn:
    text = str(e)
    if "PGRST205" in text or "Could not find the table" in text:
        raise TableMissingError(table) from e
    raise e


async def create_question(lecture_id: str, content: str, client_id: Optional[str],
                          is_ai_refined: bool = False) -> dict:
    await ensure_lecture(lecture_id)
    client = await get_supabase()
    row = {
        "lecture_id": lecture_id,
        "content": content.strip(),
        "client_id": client_id,
        "is_ai_refined": is_ai_refined,
    }
    try:
        res = await client.table("lecture_questions").insert(row).execute()
    except Exception as e:
        _raise_if_missing(e, "lecture_questions")
    return res.data[0]


async def list_questions(lecture_id: str, limit: int = 100) -> list[dict]:
    client = await get_supabase()
    try:
        res = await client.table("lecture_questions") \
            .select("id, lecture_id, client_id, content, is_resolved, is_ai_refined, answer, created_at, resolved_at") \
            .eq("lecture_id", lecture_id).order("created_at", desc=True).limit(limit).execute()
    except Exception as e:
        _raise_if_missing(e, "lecture_questions")
    return res.data


async def resolve_question(question_id: int, is_resolved: bool, answer: Optional[str]) -> Optional[dict]:
    """교수자가 질문을 답변 완료로 표시 (향후 교수자 대시보드용)"""
    update: dict = {
        "is_resolved": is_resolved,
        "resolved_at": datetime.now(timezone.utc).isoformat() if is_resolved else None,
    }
    if answer is not None:
        update["answer"] = answer.strip() or None
    client = await get_supabase()
    try:
        res = await client.table("lecture_questions").update(update).eq("id", question_id).execute()
    except Exception as e:
        _raise_if_missing(e, "lecture_questions")
    return res.data[0] if res.data else None


_WORD_RE = re.compile(r"[가-힣A-Za-z0-9]{2,}")
_FILLER = {"아까", "그거", "그게", "이거", "저거", "뭐였지", "뭐예요", "어쩌구", "근데", "혹시", "교수님", "질문"}


def _keywords(text: str) -> set[str]:
    return {w for w in _WORD_RE.findall(text) if w not in _FILLER}


async def refine_question(lecture_id: str, content: str) -> dict:
    """
    질문을 다듬은 제안을 만든다. 강의 자막을 함께 주면 작은 모델이 엉뚱한 주제의 질문으로 바꿔 버려서
    (실측: "경사 어쩌구" → "셀프 어텐션과 전이 학습…") 학생 질문만 보고 말투와 맞춤법을 다듬게 하고,
    결과에 원래 질문의 핵심 단어가 하나도 없으면 원문을 그대로 돌려준다.
    """
    original = content.strip()
    prompt = f"""학생이 강의 중 교수님께 익명으로 보낼 질문을 다듬어 주세요.

[학생 질문]
{original}

규칙:
- 학생 질문의 주제와 핵심 단어를 그대로 유지하세요. 다른 주제로 바꾸면 안 됩니다.
- 의미를 바꾸거나 학생이 묻지 않은 내용을 덧붙이지 마세요.
- 맞춤법과 말투만 고쳐 교수님이 바로 이해할 수 있는 한두 문장의 정중한 한국어 질문으로 만드세요.
- 다듬은 질문 문장만 출력하세요."""
    raw = await llm.generate(prompt, options={"temperature": 0.1, "num_predict": 150, "stop": ["\n\n"]})
    refined = raw.replace("**", "").strip().strip('"“”').strip()

    keys = _keywords(original)
    if not refined or (keys and not keys & _keywords(refined)):
        return {"refined": original, "changed": False}
    return {"refined": refined, "changed": refined != original}


async def list_notices(lecture_id: Optional[str]) -> list[dict]:
    client = await get_supabase()
    query = client.table("lecture_notices") \
        .select("id, lecture_id, category, title, content, is_pinned, created_at")
    if lecture_id:
        # 이 강의 공지 + 전체 공지(lecture_id 비어 있음)
        query = query.or_(f'lecture_id.eq."{lecture_id}",lecture_id.is.null')
    else:
        query = query.is_("lecture_id", "null")
    try:
        res = await query.order("is_pinned", desc=True).order("created_at", desc=True).limit(50).execute()
    except Exception as e:
        _raise_if_missing(e, "lecture_notices")
    return res.data
