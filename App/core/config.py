"""
백엔드 환경 설정.

App/.env 값을 읽고, .env에 없는 항목은 아래 기본값을 쓴다.
실행 위치(App 폴더 안/밖)와 상관없이 App/.env를 찾도록 절대 경로를 사용한다.
"""

from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict

APP_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=APP_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",  # 팀원 .env에 예전 키가 남아 있어도 서버가 죽지 않게 한다
    )

    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str

    # STT (faster-whisper)
    WHISPER_MODEL_SIZE: str = "medium"   # M1 개발·테스트는 small, 시연은 medium
    WHISPER_DEVICE: str = "auto"         # auto: CUDA GPU가 있으면 cuda, 없으면 cpu (macOS는 항상 cpu)
    WHISPER_COMPUTE_TYPE: str = "int8"   # cuda에서는 float16 권장
    WHISPER_BEAM_SIZE: int = 1           # 5로 올리면 M1에서 약 2배 느려짐
    WHISPER_LANGUAGE: str = "ko"         # 강의 언어 코드. "auto"면 구간마다 자동 감지
    # Whisper에 한 번에 넣는 오디오 길이(초). 비워두면 모델 크기와 장치에 맞춰 자동으로 정한다.
    STT_MIN_WINDOW_SEC: Optional[float] = None
    STT_MAX_WINDOW_SEC: Optional[float] = None

    # VAD (Silero). 소음이 많은 환경이면 0.5 이상으로 올린다.
    VAD_THRESHOLD: float = 0.3

    # Ollama (LLM / 임베딩 / VLM)
    OLLAMA_HOST: Optional[str] = None    # 비워두면 http://localhost:11434
    OLLAMA_TIMEOUT_SEC: float = 120.0
    OLLAMA_KEEP_ALIVE: str = "30m"       # 강의 중 모델이 메모리에서 내려가 첫 응답이 느려지는 것을 막는다
    LLM_MODEL: str = "gemma2:2b"
    EMBED_MODEL: str = "nomic-embed-text"
    VLM_MODEL: str = "llava"

    # 자막 번역 기본 언어 (lecture_contents.target_lang)
    DEFAULT_TARGET_LANG: str = "Korean"

    # 전공 용어 자동 추출: 추출 주기(초)와 참고할 최근 자막 범위(초)
    GLOSSARY_INTERVAL_SEC: float = 60.0
    GLOSSARY_CONTEXT_SEC: float = 120.0


settings = Settings()
