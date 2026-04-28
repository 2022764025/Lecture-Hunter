import base64
import io
from PIL import Image
from services.rag_service import ollama_client

class VLMService:
    def __init__(self, model_name: str = "llava"):
        self.model_name = model_name

    async def analyze_lecture_screen(self, image_bytes: bytes) -> str:
        """
        교수님의 슬라이드 화면을 분석하여 시각적 문맥을 텍스트로 추출
        """
        if not image_bytes:
            return ""

        try:
            # 1. 이미지 최적화 (연산량 감소를 위해 리사이징)
            img = Image.open(io.BytesIO(image_bytes))
            # RGB로 변환 (PNG의 투명도 채널 등으로 인한 에러 방지)
            img = img.convert("RGB")
            img = img.resize((512, 512)) # LLaVA 입력 최적화 크기
            
            buffered = io.BytesIO()
            img.save(buffered, format="JPEG", quality=80)
            
            # Ollama 클라이언트는 bytes를 직접 받거나 base64 문자열을 받는다.
            img_data = buffered.getvalue()

            # 2. 멀티모달 프롬프트 구성
            # "설명하지 말고 핵심 수식, 도표 내용, 텍스트만 리스트업해"라고 강하게 지시
            prompt = """
            Analyze this lecture slide. 
            1. Extract key formulas or technical terms.
            2. If there's a chart, describe the trend in one short sentence.
            3. Provide a brief summary of the visual context.
            Respond in Korean, concisely.
            """

            # 3. Ollama 호출
            response = await ollama_client.generate(
                model=self.model_name,
                prompt=prompt,
                images=[img_data] # bytes 데이터를 직접 전달
            )
            
            analysis_result = response['response'].strip()
            print(f"[VLM] 분석 성공: {analysis_result[:30]}...")
            return analysis_result

        except Exception as e:
            # [수정] 터미널에서 구체적인 에러 이유를 확인하기 위해 출력 강화
            print(f"[VLM 에러 발생]: {type(e).__name__} - {e}")
            return f"화면 분석 에러: {str(e)}"

# 싱글톤 인스턴스 생성
vlm_engine = VLMService()