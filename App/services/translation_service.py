'''
요구사항의 "번역 서버 연동"을 충족하기 위해, STT 로직에서 번역 코드를 떼어내어 독립된 서비스로 만든다. 
나중에 이 파일만 따로 떼서 GPU 서버로 옮기면 바로 '번역 서버'가 된다.
'''

import ollama
from typing import Optional

class TranslationService:
    def __init__(self, model_name: str = "gemma2:2b"):
        self.model_name = model_name

    async def translate(self, text: str, target_lang: str = "English") -> str:
        if not text.strip():
            return ""
        
        try:
            # 전문 번역가 페르소나 부여 (요구사항: 전문성 강화)
            prompt = f"You are a professional lecture translator. Translate the following Korean text into natural {target_lang}. Respond ONLY with the translation."
            
            response = ollama.chat(model=self.model_name, messages=[
                {'role': 'system', 'content': prompt},
                {'role': 'user', 'content': text},
            ])
            return response['message']['content'].strip()
        except Exception as e:
            print(f"Translation Error: {e}")
            return f"[Error] {text}"

# 싱글톤 패턴으로 엔진 관리
translation_engine = TranslationService()