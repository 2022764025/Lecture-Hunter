"""
언어 코드/이름 변환.

Whisper는 'ko', 'en' 같은 코드를 주고, 프론트·DB는 'Korean' 같은 이름을 쓴다.
같은 언어끼리 번역을 건너뛰려면 두 표기를 같은 기준으로 비교해야 한다.
"""

from typing import Optional

# 코드 -> (DB/프롬프트용 영어 이름, 화면/프롬프트용 한국어 이름)
LANGUAGES = {
    "ko": ("Korean", "한국어"),
    "en": ("English", "영어"),
    "zh": ("Chinese", "중국어"),
    "ja": ("Japanese", "일본어"),
}

_ALIASES = {
    "ko": "ko", "kr": "ko", "kor": "ko", "korean": "ko", "한국어": "ko",
    "en": "en", "eng": "en", "english": "en", "영어": "en",
    "zh": "zh", "cn": "zh", "zh-cn": "zh", "chinese": "zh", "중국어": "zh",
    "ja": "ja", "jp": "ja", "japanese": "ja", "일본어": "ja",
}

# 번역 프롬프트에서 더 정확한 표현
_PROMPT_NAMES = {"zh": "Simplified Chinese"}


def lang_code(value: Optional[str]) -> Optional[str]:
    """'Korean', 'KR', 'ko' 등을 'ko'로 바꾼다. 모르는 값이면 None."""
    if not value:
        return None
    return _ALIASES.get(value.strip().lower())


def lang_name(value: Optional[str], default: str = "Korean") -> str:
    """DB에 저장할 영어 이름. 모르는 언어 이름은 입력값을 그대로 쓴다."""
    code = lang_code(value)
    if code:
        return LANGUAGES[code][0]
    return value.strip() if value and value.strip() else default


def prompt_lang_name(value: Optional[str]) -> str:
    code = lang_code(value)
    if code:
        return _PROMPT_NAMES.get(code, LANGUAGES[code][0])
    return value or "the original language"


def korean_lang_name(value: Optional[str]) -> str:
    code = lang_code(value)
    return LANGUAGES[code][1] if code else (value or "한국어")


def same_language(a: Optional[str], b: Optional[str]) -> bool:
    ca, cb = lang_code(a), lang_code(b)
    return ca is not None and ca == cb
