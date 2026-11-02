"""
06_비교통계_정리.py · 대시보드 「나와 비슷한 사람들은」 비교용 국세통계 정리 (2024년 귀속)

원본: 국세청 국세통계포털(TASIS) 4-2-3 (성, 연령) · 4-2-4 (과세대상근로소득 규모)  — 단위 백만 원
결과: 비교통계/성연령별_2024.csv · 비교통계/급여구간별_2024.csv  (1인당 평균은 원 단위)
※ 「결정세액이 있는자」 + 「없는자」를 합쳐 전체 근로자 기준으로 계산
"""
import os
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.dirname(HERE)
OUT = os.path.join(HERE, "비교통계"); os.makedirs(OUT, exist_ok=True)

def num(v):
    v = str(v).replace(",", "").strip()
    return float(v) if v not in ("", "-", "nan") else 0.0

# 값 칸 위치 (헤더 2·3행 기준, 금액 칸)
COLS = {"인원": 35, "총급여": 36, "결정세액": 134, "기납부세액": 136, "환급세액": 140, "납부할세액": 142,
        "신용카드등소득공제": 72, "월세세액공제": 122, "중소기업취업자감면": 130}
# 4-2-3도 같은 칸 구조인지 확인용 헤더 이름
CHECK = {35: "과세대상근로소득(총급여)", 134: "결정세액", 136: "기납부세액", 140: "환급세액", 142: "납부할세액",
         72: "조특법상 소득공제", 122: "월세액 세액공제 (공제세액)", 130: "세액감면"}

def load(fname, label_ok, rename=None):
    x = pd.read_excel(os.path.join(DATA, fname), header=None)
    for c, h in CHECK.items():
        assert str(x.iat[1, c]).strip() == h, f"{fname} {c}번째 칸 헤더가 다름: {x.iat[1, c]}"
    rows, gender = {}, None
    for r in range(5, x.shape[0]):
        lab = str(x.iat[r, 0]).strip()
        if lab in ("남성", "여성"): gender = lab; continue
        if rename: lab = rename.get(lab, lab)
        if not label_ok(lab): continue
        key = (gender, lab) if gender else lab
        acc = rows.setdefault(key, {k: 0.0 for k in COLS})
        for k, c in COLS.items(): acc[k] += num(x.iat[r, c])
    return rows

def table(rows, keycols):
    out = []
    for key, v in rows.items():
        key = key if isinstance(key, tuple) else (key,)
        n = v["인원"]
        rec = dict(zip(keycols, key))
        rec.update({"인원": int(n), "총급여_백만원": int(v["총급여"]),
                    "1인당_총급여": round(v["총급여"] * 1e6 / n), "1인당_결정세액": round(v["결정세액"] * 1e6 / n),
                    "1인당_기납부세액": round(v["기납부세액"] * 1e6 / n), "1인당_환급세액": round(v["환급세액"] * 1e6 / n),
                    "1인당_납부할세액": round(v["납부할세액"] * 1e6 / n),
                    "1인당_신용카드등소득공제": round(v["신용카드등소득공제"] * 1e6 / n),
                    "1인당_월세세액공제": round(v["월세세액공제"] * 1e6 / n),
                    "1인당_중소기업취업자감면": round(v["중소기업취업자감면"] * 1e6 / n),
                    "귀속연도": 2024, "출처": "국세청 TASIS 근로소득 연말정산 신고현황(2024년 귀속)"})
        out.append(rec)
    return pd.DataFrame(out)

AGES = ["30세 미만", "30세 이상", "40세 이상", "50세 이상", "60세 이상", "70세 이상"]
sa = load("4-2-3_근로소득_연말정산_신고현황_성연령.xlsx", lambda l: l in AGES)
t1 = table(sa, ["성별", "연령대"])
t1["연령대"] = t1["연령대"].map({"30세 미만": "20대 이하", "30세 이상": "30대", "40세 이상": "40대",
                               "50세 이상": "50대", "60세 이상": "60대", "70세 이상": "70대 이상"})
t1.to_csv(os.path.join(OUT, "성연령별_2024.csv"), index=False, encoding="utf-8-sig")

BR = ["1천만 이하", "1.5천만 이하", "2천만 이하", "3천만 이하", "4천만 이하", "4.5천만 이하", "5천만 이하",
      "6천만 이하", "8천만 이하", "1억 이하", "2억 이하", "3억 이하", "5억 이하", "10억 이하", "10억 초과"]
sb = load("4-2-4_근로소득_연말정산_신고현황_과세대상근로소득.xlsx", lambda l: l in BR or l.startswith("1억 초과"),
          rename={"1억 초과": "1억 초과(결정세액 없는 자)"})
t2 = table(sb, ["급여구간"])
t2.to_csv(os.path.join(OUT, "급여구간별_2024.csv"), index=False, encoding="utf-8-sig")
print(t1.to_string(index=False)); print(t2[["급여구간", "인원", "1인당_총급여", "1인당_환급세액"]].to_string(index=False))
