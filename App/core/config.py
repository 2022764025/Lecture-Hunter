from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    
    # STT (Faster-Whisper)
    WHISPER_MODEL_SIZE: str = "medium"
    WHISPER_DEVICE: str = "auto"  # or "cpu", RTX 5060 = "cuda"
    
    # LLM (Gemma-2)
    LLM_MODEL: str = "gemma2:2b" # LLM_MODEL=gemma2:9b (RTX 5060)

    # LLM/LLaVA 엔드포인트 (필요 시 사용)
    LLM_ENDPOINT: Optional[str] = None
    LLAVA_ENDPOINT: Optional[str] = None

    # VLM (LLaVA)
    VLM_MODEL: str = "llama3.2-vision:11b" # RTX 5060: llava:13b, 빠르게 테스트 하고 싶으면 llava
    
    # VAD
    VAD_THRESHOLD: float = 0.3 # 0.5

    class Config:
        env_file = ".env"

settings = Settings()