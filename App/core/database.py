from typing import Optional

from supabase import AsyncClient, create_async_client

from core.config import settings

_client: Optional[AsyncClient] = None


async def get_supabase() -> AsyncClient:
    global _client
    if _client is None:
        _client = await create_async_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_ANON_KEY,
        )
    return _client


async def ensure_lecture(lecture_id: str, title: Optional[str] = None) -> None:
    """
    lectures 부모 행을 만든다. 이미 있으면 그대로 둔다 (제목·생성 시각 유지).
    lecture_contents, lecture_questions 등이 외래키로 lectures를 참조하기 때문에
    자식 행을 넣기 전에 반드시 호출한다.
    """
    client = await get_supabase()
    await client.table("lectures").upsert(
        {"id": lecture_id, "title": title or f"실시간 강의 - {lecture_id}"},
        on_conflict="id",
        ignore_duplicates=True,
    ).execute()
