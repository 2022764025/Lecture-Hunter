"""
그래도 코드를 남겨둬야 하는 이유 (비즈니스 가치)
기술 3번과 4번(QC 분석, 강사 리포트)은 이 프로젝트가 "돈이 되는 서비스(B2B)"임을 증명하는 핵심 로직입니다. 
비전 데이터가 아니더라도, 나중에 "학생들의 퀴즈 정답률"이나 "질문 빈도" 데이터를 이 함수에 넣으면 똑같이 성과 지표를 뽑을 수 있거든요.
-> get_content_qc_analysis (콘텐츠 품질 분석), get_instructor_report (강사 성과 지표)
"""

import pandas as pd
from datetime import timedelta

async def get_heatmap_data(supabase, lecture_id: str):
    """
    [기술 1: 수평적 데이터] 시선 히트맵 로직
    """
    try:
        response = supabase.table("lecture_logs") \
            .select("gaze_x, gaze_y") \
            .eq("lecture_id", lecture_id) \
            .execute()
        
        data = response.data
        if not data: return []

        points = [[round(d['gaze_x'], 3), round(d['gaze_y'], 3)] 
                for d in data if d['gaze_x'] is not None]
        
        return points
    except Exception as e:
        print(f"Heatmap Error: {e}")
        return []

async def get_drowsiness_timeline(supabase, lecture_id: str, student_id: str):
    """
    [기술 2: 개인화 데이터] 스마트 복습 타임라인 로직
    """
    try:
        response = supabase.table("lecture_logs") \
            .select("created_at, status") \
            .eq("lecture_id", lecture_id) \
            .eq("student_id", student_id) \
            .order("created_at") \
            .execute()
        
        logs = response.data
        if not logs: return []

        timeline = []
        start_time = last_time = None

        for log in logs:
            current_time = pd.to_datetime(log['created_at'])
            if log['status'] == 'Sleeping!!!':
                if start_time is None: start_time = current_time
                last_time = current_time
            else:
                if start_time is not None:
                    duration = (last_time - start_time).total_seconds()
                    if duration >= 2:
                        timeline.append({
                            "start": start_time.isoformat(),
                            "end": last_time.isoformat(),
                            "duration": round(duration, 1)
                        })
                    start_time = None
        return timeline
    except Exception as e:
        print(f"Timeline Error: {e}")
        return []

async def get_content_qc_analysis(supabase, lecture_id: str):
    """
    [기술 3: 비즈니스 데이터] 강사/콘텐츠 이탈 분석 (QC)
    """
    try:
        response = supabase.table("lecture_logs") \
            .select("created_at, engagement_score") \
            .eq("lecture_id", lecture_id) \
            .order("created_at") \
            .execute()
        
        df = pd.DataFrame(response.data)
        if df.empty: return {"timeline": [], "danger_zones": [], "total_average": 0}

        df['created_at'] = pd.to_datetime(df['created_at'])
        df = df.set_index('created_at')
        timeline = df['engagement_score'].resample('1min').mean().fillna(0)
        danger_zones = timeline[timeline < 0.4].index.strftime('%H:%M').tolist()

        return {
            "lecture_id": lecture_id,
            "total_average": round(df['engagement_score'].mean(), 2),
            "timeline": [{"time": t.strftime('%H:%M'), "score": round(s, 2)} for t, s in timeline.items()],
            "danger_zones": danger_zones
        }
    except Exception as e:
        print(f"QC Analysis Error: {e}")
        return {"error": str(e)}

async def get_instructor_report(supabase, lecture_id: str):
    """
    [기술 4: B2B 데이터] 강사 성과 지표 (Instructor Score)
    전공자 포인트: 표준편차를 이용한 강의 안정성 점수 산출
    """
    try:
        # 기존 QC 분석 데이터를 재활용
        analysis = await get_content_qc_analysis(supabase, lecture_id)
        if not analysis.get("timeline"):
            return {"error": "데이터가 부족하여 리포트를 생성할 수 없습니다."}

        # 1. 강의 안정성(Volatility) 계산: 참여도 점수의 표준편차 활용
        df = pd.DataFrame(analysis['timeline'])
        score_std = df['score'].std() # 표준편차(점수가 얼마나 요동치는지)
        
        # 2. 지표 가공 (100점 만점 기준)
        # $$ Stability = \max(0, 100 - (\sigma \times 100)) $$
        stability_score = max(0, 100 - (score_std * 100))
        engagement_score = analysis['total_average'] * 100
        
        # 3. 종합 성과 점수 산출 (가중치: 참여도 60%, 안정성 40%)
        final_inst_score = (engagement_score * 0.6) + (stability_score * 0.4)
        
        return {
            "lecture_id": lecture_id,
            "instructor_score": round(final_inst_score, 1),
            "stability_index": "High" if score_std < 0.15 else "Normal" if score_std < 0.25 else "Low",
            "average_engagement_percent": round(engagement_score, 1),
            "feedback": (
                "강의 전반에 걸쳐 학생들이 매우 안정적으로 몰입하고 있습니다." 
                if final_inst_score > 70 else 
                "집중도가 급락하는 구간(Danger Zone)이 발견되었습니다. 콘텐츠 재구성을 권장합니다."
            )
        }
    except Exception as e:
        print(f"Instructor Report Error: {e}")
        return {"error": str(e)}