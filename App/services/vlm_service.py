"""
<설명>
(1) 멀티모달 슬라이드 분석 (LLaVA)
    - 슬라이드 화면을 분석하여 수식, 도표, 텍스트 등 시각적 요소를 텍스트로 추출.

(2) has_visual 플래그 추출
    - 정규식 파싱 1차 시도.
    - 실패 시 LLM Fallback으로 언어 무관하게 자동 판단.

(3) 분석/번역 분리 전략
    - LLaVA는 영어 분석 정확도가 높음 → 분석은 영어 고정.
    - 번역은 translation_service로 분리하여 다국어 대응.
    - 나중에 모델 교체 시 config.py의 VLM_MODEL만 바꾸면 됨.
        M1 맥북: llava (7B)
        RTX 5060: llava:13b

(4) 이미지 최적화
    - 비율 유지하면서 최대 768px로 축소 (thumbnail).

(5) 싱글톤 패턴
    - vlm_engine = VLMService()로 인스턴스 하나만 생성하여 재사용.
"""

import io
import re
import ollama
from PIL import Image
from core.config import settings
from services.translation_service import translation_engine

# 순환 참조 방지: 독립 선언
ollama_client = ollama.AsyncClient()

class VLMService:
    def __init__(self):
        self.model_name = settings.VLM_MODEL

    async def _fallback_visual_detection(self, raw_result: str) -> bool:
        """
        정규식 태그 파싱 실패 시 LLM에게 직접 판단 요청
        YES/NO만 답하게 해서 언어 무관하게 동작
        """
        try:
            prompt = f"""
            Does the following text describe any visual elements like
            charts, graphs, diagrams, or mathematical formulas?
            Answer ONLY with "YES" or "NO". No other words allowed.

            Text: "{raw_result[:200]}"
            """
            response = await ollama_client.generate(
                model=self.model_name,
                prompt=prompt
            )
            answer = response['response'].strip().upper()
            print(f"[VLM] Fallback 판단 결과: {answer}")
            return "YES" in answer
        except Exception as e:
            print(f"[VLM] Fallback 판단 에러: {e}")
            return False

    async def analyze_lecture_screen(self, image_bytes: bytes, target_lang: str = "Korean") -> dict:
        """
        슬라이드 화면을 분석하여 시각적 문맥과 시각 자료 존재 여부를 반환
        반환값: {"has_visual": bool, "summary": str}
        """
        if not image_bytes:
            return {"has_visual": False, "summary": ""}

        try:
            # 1. 이미지 최적화 (연산량 감소를 위해 리사이징)
            img = Image.open(io.BytesIO(image_bytes))

            # RGB로 변환 (PNG의 투명도 채널 등으로 인한 에러 방지)
            img = img.convert("RGB")

            # 비율 유지 리사이징 (기존 512×512 고정 → 왜곡 문제 수정)
            # RTX 5060에서 1280px로 올림
            img.thumbnail((1024, 1024))
            
            buffered = io.BytesIO()
            img.save(buffered, format="JPEG", quality=80)
            
            # Ollama 클라이언트는 bytes를 직접 받거나 base64 문자열을 받는다.
            img_data = buffered.getvalue()

            # 2. 멀티모달 프롬프트 구성
            # "설명하지 말고 핵심 수식, 도표 내용, 텍스트만 리스트업해"라고 강하게 지시
            prompt = f"""
            Analyze this lecture slide in English only.

            Step 1 - Visual Detection:
                Does it contain charts, graphs, diagrams, or formulas?
                Start with "[VISUAL: TRUE]" or "[VISUAL: FALSE]".

            Step 2 - Summary (English only):
                - Extract key formulas or technical terms.
                - If there is a chart, describe the trend in one sentence.
                - Summarize the overall context concisely.
            
            Don't include phase titles or instruction text in your response.
            """

            # 3. LLaVA, Ollama 호출
            response = await ollama_client.generate(
                model=self.model_name,
                prompt=prompt,
                images=[img_data] # bytes 데이터를 직접 전달
            )
            
            raw_result = response['response'].strip()

            # 4. 정규식 파싱 + Fallback 방어 로직
            # 대소문자 무시, 괄호 유무, 공백 변형 모두 대응
            # 예: [Visual:True], VISUAL : FALSE, [VISUAL=TRUE] 등
            match = re.search(
                r'\[?VISUAL\s*[:=]\s*(TRUE|FALSE)\]?',
                raw_result,
                re.IGNORECASE
            )

            if match:
                # 태그를 찾은 경우
                has_visual = (match.group(1).upper() == 'TRUE')
                clean_summary = re.sub(
                    r'\[?VISUAL\s*[:=]\s*(TRUE|FALSE)\]?',
                    '',
                    raw_result,
                    flags=re.IGNORECASE
                ).strip()
                print(f"[VLM] 정규식 파싱 성공 | has_visual: {has_visual}")
            else:
                # Fallback: 모델이 태그를 완전히 빠뜨린 경우
                # 요약 텍스트 내 시각 자료 관련 키워드로 판단
                print("[VLM] 정규식 파싱 실패 → LLM Fallback 시도")
                has_visual = await self._fallback_visual_detection(raw_result)
                clean_summary = raw_result

            # 5. [추가] 불필요한 머리말 제거 (모델이 가끔 붙이는 '결과:', '요약:' 등 삭제)
            clean_summary = re.sub(r'^(결과|요약|분석|Summary|Result)\s*[:=-]\s*', '', clean_summary, flags=re.IGNORECASE)

            # 앞단에 불필요하게 남은 특수기호/공백 제거
            clean_summary = clean_summary.lstrip('-:*, \n').strip()

            # 6. translation_service로 번역 분리 (영어 분석 → 목표 언어로 번역)
            if target_lang != "English":
                print(f"[VLM] {target_lang}으로 번역 중...")
                clean_summary = await translation_engine.translate(
                    clean_summary,
                    target_lang
                )

            print(f"[VLM] 분석 완료 | 모델: {self.model_name} | 언어: {target_lang} | 시각자료: {has_visual} | 요약: {clean_summary[:30]}...")

            return {
                "has_visual": has_visual,
                "summary": clean_summary
            }

        except Exception as e:
            print(f"[VLM] 에러 발생: {type(e).__name__} - {e}")
            return {"has_visual": False, "summary": f"화면 분석 에러: {str(e)}"}
        
# 싱글톤 인스턴스 생성
vlm_engine = VLMService()