'''
요구사항의 "번역 서버 연동"을 충족하기 위해, STT 로직에서 번역 코드를 떼어내어 독립된 서비스로 만든다. 
나중에 이 파일만 따로 떼서 GPU 서버로 옮기면 바로 '번역 서버'가 된다.

<설명>
(1) 프롬프트 엔지니어링 (Refiner Persona)
    - "Professional lecture transcription refiner"라는 페르소나를 부여.
    단순히 번역만 시키는 게 아니라, STT 오버랩 과정에서 발생하는 '단어 중복(Mechanical word repetitions)'을 고치라는 지침을 넣음.
    Whisper 모델을 실시간으로 돌릴 때 생기는 "ex. 저는 오늘... 오늘 공부를... 공부를 하겠습니다" 같은 떨림 현상을 AI가 알아서 깔끔하게 다듬어주게 설계.
(2) 도메인 특화 번역 (Technical Term Mapping)
    - "경사하강법" 같은 전공 용어를 해당 국가의 학술 용어로 번역하도록 강제.
    일반 번역기는 전공 용어를 문맥 없이 직역하는 실수를 범하는데, 이 지침 덕분에 AI 전공 강의에서도 정확한 용어 전달이 가능해진다.
(3) 싱글톤 패턴 (Singleton Pattern)
    - 파일 마지막에 translation_engine = TranslationService()로 인스턴스를 하나만 생성.
    이는 서버 내에서 여러 번 번역 요청이 들어와도 엔진 객체를 새로 만들지 않고 하나로 재사용하여 메모리 낭비를 방지하는 설계이다.
'''

import ollama
from typing import Optional
from services.rag_service import ollama_client

class TranslationService:
    def __init__(self, model_name: str = "gemma2:2b"):
        self.model_name = model_name

    async def translate(self, text: str, target_lang: str = "English") -> str:
        if not text.strip():
            return ""
        
        try:
            # 전문 번역가 페르소나 부여 (요구사항: 전문성 강화)
            prompt = (
                f"You are a professional lecture transcription refiner. "
                f"Your task is to translate the following text into {target_lang}.\n"
                f"CRITICAL RULES:\n"
                f"1. DO NOT change the original speaker's tone (e.g., maintain '습니다' or '해요').\n"
                f"2. DO NOT omit any technical terms or summarize the content.\n"
                f"3. ONLY fix mechanical word repetitions caused by the STT overlap process.\n"
                f"4. Respond ONLY with the processed text without any explanations.\n\n"
                f"추가 지침:\n"
                f"- 너는 전문 번역가야. 아래의 문장을 반드시 {target_lang}로만 번역해.\n"
                f"- 한국어 조사나 감탄사(자, 음, 에 등)를 절대로 남기지 마.\n"
                f"- 오직 {target_lang}의 자연스러운 문장으로만 출력해.\n"
                f"- 전공 용어(경사하강법 등)는 해당 국가의 학술 용어로 번역해.\n\n"
                f"문장: {text}"
                f"If there are any typo-like words from STT, correct them into proper technical terms."
            )
            
            response = await ollama_client.chat(model=self.model_name, messages=[
                {'role': 'system', 'content': prompt},
                {'role': 'user', 'content': text},
            ])
            return response['message']['content'].strip()
        except Exception as e:
            print(f"Translation Error: {e}")
            return f"[Error] {text}"

# 싱글톤 패턴으로 엔진 관리
translation_engine = TranslationService()