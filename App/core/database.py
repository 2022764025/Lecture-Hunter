from supabase import create_async_client, AsyncClient
from core.config import settings

_client: AsyncClient = None

async def get_supabase() -> AsyncClient:
    global _client
    if _client is None:
        _client = await create_async_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_ANON_KEY
        )
    return _client