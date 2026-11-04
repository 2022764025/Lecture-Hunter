# mock_db_seed.py
# 프론트 화면 확인용 가짜 자막을 demo-lecture 강의에 넣는다. (App 폴더에서: python mock_db_seed.py)
import asyncio

from core.database import ensure_lecture, get_supabase


async def seed_lecture_data():
    supabase = await get_supabase()
    lecture_id = "demo-lecture"

    # lecture_contents가 lectures를 외래키로 참조하므로 부모 행부터 만든다
    await ensure_lecture(lecture_id, "데모 강의 - CNN 개론")

    # AI 학과 전공 수업 느낌의 가짜 자막 데이터 리스트
    mock_captions = [
        "오늘 수업에서는 컨볼루션 신경망, 즉 CNN의 핵심 구조에 대해 알아보겠습니다.",
        "CNN은 일반적인 DNN과 달리 이미지의 공간적 특성(Spatial Features)을 보존하는 장점이 있습니다.",
        "핵심 연산인 합성곱(Convolution)과 풀링(Pooling) 레이어를 거치며 특징 맵이 추출됩니다.",
        "이후 완전연결 계층(Fully Connected Layer)을 통과하여 최종적으로 이미지가 어떤 클래스인지 분류하게 됩니다."
    ]

    print("[Seed] 가짜 강의 자막 데이터 DB 적재 시작...")

    for text in mock_captions:
        await supabase.table("lecture_contents").insert({
            "lecture_id": lecture_id,
            "original_text": text,
            "translated_text": text,     # 한국어 → 한국어는 번역하지 않고 원문 그대로
            "source_lang": "ko",
            "target_lang": "Korean",
            "has_visual": False,
        }).execute()
        print(f"[Insert 완료] {text[:20]}...")
        await asyncio.sleep(0.5)

    print("[Seed] 모든 가짜 자막 적재 완료!")


if __name__ == "__main__":
    asyncio.run(seed_lecture_data())
