from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    
    # STT (Faster-Whisper)
    WHISPER_MODEL_SIZE: str = "medium"
    WHISPER_DEVICE: str = "cuda"  # or "cpu"
    
    # LLM (Gemma-2 / LLaVA)
    LLM_ENDPOINT: Optional[str] = None
    LLAVA_ENDPOINT: Optional[str] = None
    
    # VAD
    VAD_THRESHOLD: float = 0.5

    class Config:
        env_file = ".env"

settings = Settings()