-- ==========================================================
-- Lecture-Hunter: 공지 탭 기본 내용 (발표 자료·과제헌터.html 디자인과 같은 내용)
-- Supabase 대시보드 → SQL Editor에서 실행하세요. 여러 번 실행해도 같은 공지가 두 번 들어가지 않습니다.
-- lecture_id를 비워 둔 "전체 공지"라 모든 강의 위젯에 보입니다.
-- 실제 강의 내용으로 바꾸려면 Table Editor → lecture_notices 에서 title / content 만 고치면 됩니다.
--
-- 위젯은 같은 묶음 안에서 최신 공지를 위에 보여주므로, 위에 보일 항목일수록 created_at을 늦게 둡니다.
-- content 안의 링크(https://...)는 글자로 보이지 않고 제목 옆 링크 버튼으로만 보입니다.
-- 제목이 '중요 공지'인 중요 공지는 박스 제목과 겹치므로 내용만 보입니다.
-- ==========================================================

INSERT INTO lecture_notices (lecture_id, category, title, content, is_pinned, created_at)
SELECT NULL, v.category, v.title, v.content, FALSE, NOW() - make_interval(secs => v.age)
FROM (VALUES
    ('important',  '중요 공지',        '이번 강의에서 우선적으로 알아야 할 내용과 학습 방향을 안내합니다.', 1),

    ('material',   '추천 교재',        '교재명 · 저자 · 출판사 · 참고 범위',                                 1),
    ('material',   '추가 참고 자료',   E'자료 제목 · 발행기관 · 출처 링크\nhttps://www.deeplearningbook.org/', 2),
    ('material',   '필요한 학습 환경', '프로그램 · 개발 환경 · 설치 안내',                                   3),

    ('assignment', '과제 설명',        '과제명 · 수행 내용 · 요구사항',                                      1),
    ('assignment', '제출 방법',        '제출 플랫폼 · 파일 형식 · 제출 절차',                                2),
    ('assignment', '제출 기한',        '제출 마감 날짜 및 시간',                                             3)
) AS v(category, title, content, age)
WHERE NOT EXISTS (
    SELECT 1 FROM lecture_notices n
    WHERE n.lecture_id IS NULL AND n.category = v.category AND n.title = v.title
);

-- 지우고 싶을 때:
-- DELETE FROM lecture_notices WHERE lecture_id IS NULL
--   AND title IN ('중요 공지', '추천 교재', '추가 참고 자료', '필요한 학습 환경', '과제 설명', '제출 방법', '제출 기한');
