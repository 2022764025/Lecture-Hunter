"""
익명 질문 · 공지 REST API

POST  /lecture/questions                 질문 등록
GET   /lecture/questions?lecture_id=     질문 목록 (최신순)
PATCH /lecture/questions/{id}            답변 완료 표시 / 교수자 답변 (향후 교수자 대시보드용)
POST  /lecture/questions/refine          AI가 질문을 다듬은 제안 (저장하지 않음)
GET   /lecture/notices?lecture_id=       이 강의 공지 + 전체 공지
"""

from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field, field_validator

from services import interaction_service as svc

router = APIRouter(tags=["Interaction"])

LECTURE_ID_PATTERN = r"^[\w\-.:]{1,128}$"


class QuestionCreate(BaseModel):
    lecture_id: str = Field(pattern=LECTURE_ID_PATTERN)
    content: str = Field(min_length=1, max_length=1000)
    client_id: Optional[str] = Field(default=None, max_length=64)
    is_ai_refined: bool = False

    @field_validator("content")
    @classmethod
    def not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("질문 내용이 비어 있습니다.")
        return v.strip()


class QuestionUpdate(BaseModel):
    is_resolved: bool = True
    answer: Optional[str] = Field(default=None, max_length=2000)


class QuestionRefine(BaseModel):
    lecture_id: str = Field(pattern=LECTURE_ID_PATTERN)
    content: str = Field(min_length=1, max_length=1000)


def _table_missing(e: svc.TableMissingError) -> HTTPException:
    return HTTPException(status_code=503, detail=str(e))


@router.post("/lecture/questions", status_code=201)
async def create_question(body: QuestionCreate):
    try:
        question = await svc.create_question(body.lecture_id, body.content, body.client_id, body.is_ai_refined)
    except svc.TableMissingError as e:
        raise _table_missing(e) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"질문 저장 실패: {e}") from e
    print(f"[Question] {body.lecture_id} 익명 질문 등록 #{question['id']}")
    return {"status": "success", "question": question}


@router.get("/lecture/questions")
async def list_questions(
    lecture_id: str = Query(pattern=LECTURE_ID_PATTERN),
    limit: int = Query(default=100, ge=1, le=500),
):
    try:
        questions = await svc.list_questions(lecture_id, limit)
    except svc.TableMissingError as e:
        raise _table_missing(e) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"질문 조회 실패: {e}") from e
    return {"lecture_id": lecture_id, "count": len(questions), "questions": questions}


@router.patch("/lecture/questions/{question_id}")
async def update_question(question_id: int, body: QuestionUpdate):
    try:
        question = await svc.resolve_question(question_id, body.is_resolved, body.answer)
    except svc.TableMissingError as e:
        raise _table_missing(e) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"질문 수정 실패: {e}") from e
    if question is None:
        raise HTTPException(status_code=404, detail="질문을 찾을 수 없습니다.")
    return {"status": "success", "question": question}


@router.post("/lecture/questions/refine")
async def refine_question(body: QuestionRefine):
    try:
        result = await svc.refine_question(body.lecture_id, body.content)
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"AI 질문 다듬기 실패: {e}") from e
    return {"original": body.content.strip(), **result}


@router.get("/lecture/notices")
async def list_notices(lecture_id: Optional[str] = Query(default=None, pattern=LECTURE_ID_PATTERN)):
    try:
        notices = await svc.list_notices(lecture_id)
    except svc.TableMissingError as e:
        raise _table_missing(e) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"공지 조회 실패: {e}") from e
    return {"lecture_id": lecture_id, "count": len(notices), "notices": notices}
