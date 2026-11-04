# services/vlm_service.py

"""
<설명>
(1) 화면 질문 (Visual Q&A)
    - 학생이 캡처한 강의 화면(슬라이드, 수식, 그래프, 코드)과 질문을 함께 VLM(LLaVA)에 보낸다.
    - 최근 강의 자막도 같이 넣어, 화면만으로 알 수 없는 맥락을 보충한다.
    - 화면에 답할 정보가 없으면 추측하지 말고 그렇다고 답하게 한다.
(2) 슬라이드 분석 (질문 없이 캡처만 보낸 경우)
    - 시각 자료가 있는지 [VISUAL: TRUE/FALSE] 태그로 판정하고 핵심 내용을 요약한다.
    - 태그가 없으면 텍스트 LLM(gemma2)에게 YES/NO로 다시 물어 판정한다. (예전에는 무거운 VLM에게 다시 물었다)
(3) 분석/번역 분리 전략
    - LLaVA는 영어 답변 품질이 높아 영어로 답하게 하고, translation_service로 목표 언어로 번역한다.
(4) 실패 처리
    - 모델이 없거나 응답하지 못하면 VLMError를 던진다. API는 503으로 응답한다.
      (예전에는 실패해도 200 success로 응답하고, 에러 문구가 자막 데이터에 저장될 수 있었다)
(5) 이미지 최적화
    - 비율을 유지하며 최대 1024px로 줄이고 JPEG로 다시 압축한다.
"""

import io
import re
import time

from PIL import Image, UnidentifiedImageError

from core import llm
from core.config import settings
from core.database import get_supabase
from core.lang import lang_code
from services.translation_service import translation_engine

MAX_IMAGE_SIDE = 1024
_VISUAL_TAG_RE = re.compile(r"\[?\s*VISUAL\s*[:=]\s*(TRUE|FALSE)\s*\]?", re.IGNORECASE)
_HEADER_RE = re.compile(r"^(결과|요약|분석|answer|summary|result)\s*[:=-]\s*", re.IGNORECASE)


class VLMError(Exception):
    """VLM 모델을 쓸 수 없거나 응답이 비었을 때"""


class InvalidImageError(ValueError):
    """이미지로 읽을 수 없는 데이터"""


def prepare_image(image_bytes: bytes) -> bytes:
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img = img.convert("RGB")  # PNG 투명 채널 등으로 인한 오류 방지
    except (UnidentifiedImageError, OSError) as e:
        raise InvalidImageError("이미지 형식을 읽을 수 없습니다.") from e
    img.thumbnail((MAX_IMAGE_SIDE, MAX_IMAGE_SIDE))
    buffered = io.BytesIO()
    img.save(buffered, format="JPEG", quality=85)
    return buffered.getvalue()


def _clean(text: str) -> str:
    text = _HEADER_RE.sub("", text.strip())
    return text.lstrip("-:*, \n").strip()


class VLMService:
    def __init__(self):
        self.model_name = settings.VLM_MODEL

    async def _ask_vlm(self, prompt: str, image: bytes) -> str:
        try:
            raw = await llm.generate(
                prompt, model=self.model_name, images=[image],
                options={"temperature": 0.2, "num_predict": 220},   # 답변 길이 제한 (M1에서 응답 시간 단축)
            )
        except Exception as e:
            raise VLMError(f"VLM 모델({self.model_name}) 호출 실패: {e}") from e
        if not raw:
            raise VLMError("VLM 응답이 비어 있습니다.")
        return raw

    async def _to_target(self, text: str, target_lang: str, glossary_terms=None) -> str:
        if lang_code(target_lang) == "en":
            return text
        translated = await translation_engine.translate(
            text, target_lang, source_lang="English", glossary_terms=glossary_terms, multiline=True
        )
        return translated or text

    async def answer_question(self, image_bytes: bytes, question: str, target_lang: str = "Korean",
                              lecture_context: str = "", glossary_terms=None) -> dict:
        image = prepare_image(image_bytes)
        context = lecture_context.strip() or "(none)"
        prompt = f"""You are a teaching assistant helping a university student during a lecture.
The image is a screenshot of the lecture screen (slides, formulas, graphs, or code).

Student's question: {question}

Answer by describing and explaining what is actually visible in the image.
Use the transcript below only to understand the lecture topic; do not repeat it.
If the image does not contain enough information to answer, say so instead of guessing.
Answer in English in at most 4 short sentences.

Recent lecture transcript (speech recognition, may contain typos):
{context}"""
        t0 = time.perf_counter()
        raw = _clean(await self._ask_vlm(prompt, image))
        t1 = time.perf_counter()
        answer = await self._to_target(raw, target_lang, glossary_terms)
        print(f"[VLM] 질문 답변 완료 | {self.model_name} {t1 - t0:.1f}s + 번역 {time.perf_counter() - t1:.1f}s "
              f"| {answer[:40]}...")
        return {"has_visual": True, "answer": answer, "raw": raw}

    async def _fallback_visual_detection(self, description: str) -> bool:
        prompt = (
            "Does the following text describe visual elements such as charts, graphs, diagrams, "
            'or mathematical formulas? Answer ONLY "YES" or "NO".\n\n'
            f'Text: "{description[:400]}"'
        )
        try:
            answer = await llm.generate(prompt, options={"temperature": 0})
        except Exception as e:
            print(f"[VLM] 시각 자료 판정 실패: {e}")
            return False
        return "YES" in answer.upper()

    async def analyze_slide(self, image_bytes: bytes, target_lang: str = "Korean", glossary_terms=None) -> dict:
        image = prepare_image(image_bytes)
        prompt = """Analyze this lecture slide in English only.

Step 1 - Visual Detection:
    Does it contain charts, graphs, diagrams, or formulas?
    Start your answer with "[VISUAL: TRUE]" or "[VISUAL: FALSE]".

Step 2 - Summary (English only):
    - Extract key formulas or technical terms.
    - If there is a chart, describe the trend in one sentence.
    - Summarize the overall context concisely.

Don't include step titles or instruction text in your response."""
        raw = await self._ask_vlm(prompt, image)
        match = _VISUAL_TAG_RE.search(raw)
        if match:
            has_visual = match.group(1).upper() == "TRUE"
            summary = _VISUAL_TAG_RE.sub("", raw)
        else:
            summary = raw
            has_visual = await self._fallback_visual_detection(raw)
        summary = _clean(summary)
        translated = await self._to_target(summary, target_lang, glossary_terms)
        print(f"[VLM] 슬라이드 분석 완료 | 시각자료: {has_visual} | {translated[:40]}...")
        return {"has_visual": has_visual, "answer": translated, "raw": summary}


# 싱글톤 인스턴스 생성
vlm_engine = VLMService()


async def recent_lecture_text(lecture_id: str, limit: int = 3) -> str:
    """VLM 질문에 함께 넣을 최근 자막"""
    client = await get_supabase()
    res = await client.table("lecture_contents").select("original_text") \
        .eq("lecture_id", lecture_id).order("id", desc=True).limit(limit).execute()
    return "\n".join(r["original_text"] for r in reversed(res.data) if r.get("original_text"))
