'''
요구사항의 "번역 서버 연동"을 충족하기 위해, STT 로직에서 번역 코드를 떼어내어 독립된 서비스로 만든다.
나중에 이 파일만 따로 떼서 GPU 서버로 옮기면 바로 '번역 서버'가 된다.

<설명>
(1) 같은 언어는 번역하지 않음
    - 한국어 강의를 한국어로 "번역"하면 LLM이 문장을 고쳐 쓰면서 단어를 빠뜨렸다
      (예: "대표적인 활성화 함수로는…" → "활성화 함수로는…"). 원문과 목표 언어가 같으면 원문을 그대로 쓴다.
(2) 프롬프트 엔지니어링 (Refiner Persona)
    - 강의 통역사 역할을 주고, STT에서 생기는 군말·반복 단어는 정리하되 내용은 빼거나 더하지 않도록 지시한다.
(3) 도메인 특화 번역 (Glossary Prompting)
    - 강의에서 추출된 전공 용어 목록을 프롬프트에 넣어 용어 번역을 일관되게 유지하고,
      PyTorch, Vector DB 같은 고유 명칭은 번역하지 않도록 한다.
(4) 실패 처리
    - 번역에 실패하면 None을 돌려준다. 예전처럼 "[Error] 원문"을 자막으로 저장하지 않는다.
(5) 싱글톤 패턴 (Singleton Pattern)
    - translation_engine = TranslationService() 인스턴스 하나를 재사용한다.
'''

import re
from typing import Optional, Sequence

from core import llm
from core.config import settings
from core.lang import prompt_lang_name, same_language

_PREFIX_RE = re.compile(r"^\s*(translation|번역(문)?|译文|翻訳)\s*[:：]\s*", re.IGNORECASE)
_NOTE_RE = re.compile(r"^\s*[\*\(]?\s*(note|참고|注|※)", re.IGNORECASE)


def _clean_output(text: str) -> str:
    """작은 모델이 붙이는 머리말, 따옴표, 덧붙인 설명을 걷어낸다."""
    lines = []
    for line in text.strip().splitlines():
        if _NOTE_RE.match(line):
            break
        lines.append(line)
    out = "\n".join(lines).strip()
    out = _PREFIX_RE.sub("", out).strip()
    if len(out) >= 2 and out[0] == out[-1] and out[0] in "\"'“”「」":
        out = out[1:-1].strip()
    return out


class TranslationService:
    def __init__(self, model_name: Optional[str] = None):
        self.model_name = model_name or settings.LLM_MODEL

    async def translate(
        self,
        text: str,
        target_lang: str = "English",
        *,
        source_lang: Optional[str] = None,
        glossary_terms: Optional[Sequence[str]] = None,
        multiline: bool = False,
    ) -> Optional[str]:
        """multiline=False(자막): 한 문단만 번역하고 빈 줄에서 멈춘다. True(VLM 답변 등): 여러 문단 허용."""
        text = (text or "").strip()
        if not text:
            return ""
        if source_lang and same_language(source_lang, target_lang):
            return text

        target = prompt_lang_name(target_lang)
        source = prompt_lang_name(source_lang) if source_lang else "the original language"

        rules = [
            f"Output ONLY the {target} translation. No explanations, notes, quotes, or the original text.",
            "Keep code, product names, and technical names exactly as written (e.g., PyTorch, Vector DB, LMS).",
            f"Translate academic terms into the standard academic term used in {target}.",
            "The text comes from speech recognition. Remove filler words and accidental word repetitions, "
            "but do not drop or add any content.",
        ]
        if glossary_terms:
            terms = ", ".join(dict.fromkeys(t for t in glossary_terms if t))[:600]
            rules.append(f"Terms used in this lecture (translate them consistently): {terms}")

        prompt = (
            "You are a professional interpreter for university lectures.\n"
            f"Translate the lecture transcript segment below from {source} into {target}.\n\n"
            "Rules:\n"
            + "\n".join(f"{i}. {rule}" for i, rule in enumerate(rules, 1))
            + f"\n\nText: {text}\n{target} translation:"
        )

        # 자막 번역문은 한 문단이라 빈 줄에서 멈추고, 출력 길이도 원문에 맞춰 제한한다.
        # 작은 모델이 번역 뒤에 설명을 덧붙이느라 시간을 쓰는 것을 막는다 (자막 1개당 번역 시간 단축).
        options = {"temperature": 0.2, "num_predict": min(800, 48 + len(text) * 2)}
        if not multiline:
            options["stop"] = ["\n\n"]
        try:
            raw = await llm.generate(prompt, model=self.model_name, options=options)
        except Exception as e:
            print(f"[Translation] 번역 실패 ({type(e).__name__}): {e}")
            return None

        out = _clean_output(raw)
        return out or None


# 싱글톤 패턴으로 엔진 관리
translation_engine = TranslationService()
