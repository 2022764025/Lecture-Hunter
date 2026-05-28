"""
<설명>
[비전 데이터 → 인터랙션 데이터 피벗 완료]

기존 비전 기반(gaze_x, gaze_y, Sleeping!!!) 로직을
인터랙션 기반(event_type, engagement_score)으로 전환.
B2B 핵심 로직(표준편차 기반 Stability Index)은 그대로 유지.

(1) get_interaction_intensity     ← get_heatmap_data 대체
(2) get_student_inactivity_timeline ← get_drowsiness_timeline 대체
(3) get_content_qc_analysis       ← 유지 (데이터 소스만 변경)
(4) get_instructor_report         ← 유지 (수식 동일)

engagement_score 입력 소스:
- 질문 빈도 (lecture/ask 호출)
- 위젯 클릭 (widget_click)
- 퀴즈 제출 (quiz_submit)
- 주기 핑 (periodic_ping)
"""

import numpy as np
import pandas as pd

# [기술 1] 실시간 인터랙션 활성 분포 (기존 히트맵 대체)
async def get_interaction_intensity(supabase, lecture_id: str):
    """
    학생들이 어떤 시점에 질문/퀴즈/클릭을 많이 했는지
    시간대별 인터랙션 강도를 반환
    """
    try:
        response = supabase.table("lecture_logs") \
            .select("created_at, event_type, engagement_score") \
            .eq("lecture_id", lecture_id) \
            .order("created_at") \
            .execute()

        data = response.data
        if not data:
            return []

        points = []
        for d in data:
            if d.get('created_at') is None:
                continue
            if d.get('engagement_score') is None:
                continue

            dt = pd.to_datetime(d['created_at'], utc=True).strftime('%H:%M:%S')
            points.append({
                "time":  dt,
                "event": d.get('event_type', 'unknown'),
                "score": round(float(d['engagement_score']), 2)
            })

        return points

    except Exception as e:
        print(f"[Interaction Intensity Error] {e}")
        return []

# [기술 2] 스마트 학습 공백 타임라인 (기존 졸음 타임라인 대체)
async def get_student_inactivity_timeline(
    supabase, lecture_id: str, student_id: str
):
    """
    engagement_score 0.3 미만 + periodic_ping 구간을
    '집중 탈락 구간'으로 추출
    복습 시 "이 타이밍에 딴짓했으니 집중해라" 피드백
    """
    try:
        response = supabase.table("lecture_logs") \
            .select("created_at, engagement_score, event_type") \
            .eq("lecture_id", lecture_id) \
            .eq("student_id", student_id) \
            .order("created_at") \
            .execute()

        logs = response.data
        if not logs:
            return []

        timeline = []
        start_time = None
        last_time = None

        for log in logs:
            # engagement_score None 방어
            if log.get('engagement_score') is None:
                continue

            # timezone-aware 파싱
            current_time = pd.to_datetime(log['created_at'], utc=True)

            if log['engagement_score'] < 0.3 and log.get('event_type') == 'periodic_ping':
                if start_time is None:
                    start_time = current_time
                last_time = current_time
            else:
                if start_time is not None:
                    duration = (last_time - start_time).total_seconds()
                    if duration >= 60:  # 1분 이상 집중 탈락 구간만 기록
                        timeline.append({
                            "start": start_time.isoformat(),
                            "end": last_time.isoformat(),
                            "duration_minutes": round(duration / 60, 1)
                        })
                    start_time = None
                    last_time = None

        # 루프 끝까지 비활성 상태였던 구간 마무리
        if start_time is not None and last_time is not None:
            duration = (last_time - start_time).total_seconds()
            if duration >= 60:
                timeline.append({
                    "start": start_time.isoformat(),
                    "end": last_time.isoformat(),
                    "duration_minutes": round(duration / 60, 1)
                })

        return timeline

    except Exception as e:
        print(f"[Inactivity Timeline Error] {e}")
        return []

# [기술 3] 강의 콘텐츠 품질 분석 QC (유지)
async def get_content_qc_analysis(supabase, lecture_id: str):
    """
    인터랙션 기반 분당 평균 참여도로 품질 분석
    danger_zones: 참여도 0.4 미만 구간
    """
    try:
        response = supabase.table("lecture_logs") \
            .select("created_at, engagement_score") \
            .eq("lecture_id", lecture_id) \
            .order("created_at") \
            .execute()

        df = pd.DataFrame(response.data)
        if df.empty:
            return {
                "lecture_id": lecture_id,
                "timeline": [],
                "danger_zones": [],
                "total_average": 0
            }

        # timezone-aware 파싱
        df['created_at'] = pd.to_datetime(df['created_at'], utc=True)
        df = df.set_index('created_at')

        # engagement_score 숫자 강제 변환 (None, 이상값 방어)
        df['engagement_score'] = pd.to_numeric(
            df['engagement_score'], errors='coerce'
        )
        df = df.dropna(subset=['engagement_score'])

        if df.empty:
            return {
                "lecture_id": lecture_id,
                "timeline": [],
                "danger_zones": [],
                "total_average": 0
            }

        timeline = df['engagement_score'].resample('1min').mean().fillna(0)
        danger_zones = (
            timeline[timeline < 0.4]
            .index.strftime('%H:%M')
            .tolist()
        )

        return {
            "lecture_id": lecture_id,
            "total_average": round(float(df['engagement_score'].mean()), 2),
            "timeline": [
                {"time": t.strftime('%H:%M'), "score": round(float(s), 2)}
                for t, s in timeline.items()
            ],
            "danger_zones": danger_zones
        }

    except Exception as e:
        print(f"[QC Analysis Error] {e}")
        return {"error": str(e)}


# [기술 4] 강사 성과 지표 (유지, 수식 동일)
async def get_instructor_report(supabase, lecture_id: str):
    """
    Stability = max(0, 100 - (sigma x 100))
    최종점수 = 참여도(60%) + 안정성(40%)
    """
    try:
        analysis = await get_content_qc_analysis(supabase, lecture_id)

        if "error" in analysis:
            return {"error": analysis["error"]}

        if not analysis.get("timeline"):
            return {"error": "데이터가 부족하여 리포트를 생성할 수 없습니다."}

        df = pd.DataFrame(analysis["timeline"])

        # NaN 방어 (데이터 2개 미만이면 std() NaN 반환)
        if len(df) < 2:
            return {"error": "분석을 위한 데이터가 충분하지 않습니다. (최소 2분 이상 필요)"}

        score_std = float(df['score'].std())

        # NaN 추가 방어
        if np.isnan(score_std):
            return {"error": "표준편차 계산 중 오류가 발생했습니다."}

        stability_score  = max(0.0, 100.0 - (score_std * 100))
        engagement_score = analysis['total_average'] * 100
        final_inst_score = (engagement_score * 0.6) + (stability_score * 0.4)

        if score_std < 0.15:
            stability_index = "High"
        elif score_std < 0.25:
            stability_index = "Normal"
        else:
            stability_index = "Low"

        feedback = (
            "학생들의 실시간 반응과 참여 흐름이 매우 유기적이며 안정적입니다."
            if final_inst_score > 70 else
            "인터랙션이 급감하는 공백 구간(Danger Zone)이 있습니다. 수업 중간 질문 유도나 퀴즈 배치를 권장합니다."
        )

        return {
            "lecture_id":               lecture_id,
            "instructor_score":         round(final_inst_score, 1),
            "stability_index":          stability_index,
            "average_engagement_percent": round(engagement_score, 1),
            "score_std":                round(score_std, 4),
            "feedback":                 feedback
        }

    except Exception as e:
        print(f"[Instructor Report Error] {e}")
        return {"error": str(e)}