"""
05_가상데이터_생성.py · 희망연봉2조 가상 회원·소득·카드내역 생성기

- 회원·소득(MEMBER, INCOME): 국세통계 2024년 귀속 분포를 따라 만듦 (실제 개인정보 없음)
    · 성별·연령대 비율, 연령대별 평균 총급여  ← 4-2-3 근로소득 연말정산 신고현황(성, 연령)
    · 급여 구간별 기납부세액·국민연금·건강보험료(v3.9 분리)·부양가족·월세·청약·연금계좌·중소기업 감면 비율 ← 4-2-4 (과세대상근로소득)
- 카드 내역(CARD_UPLOAD, EXPENSE): 업로드·분류 기능 **테스트용**
    · 가맹점명은 MERCHANT_LIST 정제본과 상가정보 샘플(일반)에서 뽑음
    · 금액·결제수단은 공식 통계가 없어 테스트용 범위로만 만듦 → 그룹 비교 통계에는 쓰지 않음
- 실행: python 05_가상데이터_생성.py  (이 폴더가 「희망환급_데이터」 폴더 안에 있어야 함)
- 결과: 가상데이터/*.csv  +  카드내역_업로드_예시/*.csv
"""
import os, re, random, datetime as dt
from decimal import Decimal, ROUND_HALF_UP   # v3.9
import numpy as np
import pandas as pd
import bcrypt

SEED = 2026
N_MEMBER = 1000          # 회원 수
N_CARD_MEMBER = 100      # 카드 내역까지 만들 회원 수 (테스트용)
TAX_YEAR = 2026
JOIN = dt.date(TAX_YEAR, 10, 20).isoformat()   # 가상 회원 가입일(= 약관·개인정보 동의 일시)
TEST_PASSWORD = "test1234!"  # 모든 가상 회원 공통 비밀번호 (BCrypt로 저장)

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.dirname(HERE)  # 희망환급_데이터
OUT = os.path.join(HERE, "가상데이터")
UP = os.path.join(HERE, "카드내역_업로드_예시")
os.makedirs(OUT, exist_ok=True); os.makedirs(UP, exist_ok=True)
rng = np.random.default_rng(SEED); random.seed(SEED)

def num(v):
    return float(str(v).replace(",", "")) if str(v).strip() not in ("", "-", "nan") else 0.0

# ── 1. 국세통계 읽기 (금액 단위: 백만 원) ───────────────────────────
s = pd.read_excel(os.path.join(DATA, "4-2-3_근로소득_연말정산_신고현황_성연령.xlsx"), header=None)
AGE_RANGE = {"30세 미만": (20, 29), "30세 이상": (30, 39), "40세 이상": (40, 49),
             "50세 이상": (50, 59), "60세 이상": (60, 69), "70세 이상": (70, 74)}
grp = {}
gender = None
for r in range(5, s.shape[0]):
    lab = str(s.iat[r, 0]).strip()
    if lab in ("남성", "여성"):
        gender = "M" if lab == "남성" else "F"; continue
    if lab in AGE_RANGE and gender:
        k = (gender, lab)
        n, amt = num(s.iat[r, 1]), num(s.iat[r, 2])
        a = grp.setdefault(k, [0.0, 0.0]); a[0] += n; a[1] += amt   # 결정세액 있는자 + 없는자 합산
groups = list(grp.keys())
g_cnt = np.array([grp[k][0] for k in groups]); g_p = g_cnt / g_cnt.sum()
g_mean = {k: grp[k][1] * 1e6 / grp[k][0] for k in groups}

b = pd.read_excel(os.path.join(DATA, "4-2-4_근로소득_연말정산_신고현황_과세대상근로소득.xlsx"), header=None)
BR = [("1천만 이하", 0, 1e7), ("1.5천만 이하", 1e7, 1.5e7), ("2천만 이하", 1.5e7, 2e7), ("3천만 이하", 2e7, 3e7),
      ("4천만 이하", 3e7, 4e7), ("4.5천만 이하", 4e7, 4.5e7), ("5천만 이하", 4.5e7, 5e7), ("6천만 이하", 5e7, 6e7),
      ("8천만 이하", 6e7, 8e7), ("1억 이하", 8e7, 1e8), ("2억 이하", 1e8, 2e8), ("3억 이하", 2e8, 3e8),
      ("5억 이하", 3e8, 5e8), ("10억 이하", 5e8, 1e9), ("10억 초과", 1e9, 9e18)]
COL = dict(n=35, sal=36, basic_amt=46, basic_n=45, nps=50, ins=56, house_n=67, house_amt=68,
           pen_n=95, pen_amt=96, rent_n=121, rent_amt=122, sme_n=129, paid=136)
bk = {lab: {c: 0.0 for c in COL} for lab, _, _ in BR}
for r in range(5, b.shape[0]):
    lab = str(b.iat[r, 0]).strip()
    if lab == "1억 초과": lab = "2억 이하"          # 결정세액 없는자 표에만 있는 합산 구간
    if lab in bk:
        for c, ci in COL.items(): bk[lab][c] += num(b.iat[r, ci])

def bracket(sal):
    for lab, lo, hi in BR:
        if sal <= hi: return lab
    return BR[-1][0]

def rate(lab, a, n="n"):
    d = bk[lab]; return d[a] / d[n] if d[n] else 0.0

# ── 2. 회원·소득 ───────────────────────────────────────────────
pw_hash = bcrypt.hashpw(TEST_PASSWORD.encode(), bcrypt.gensalt(rounds=10)).decode()
total_n = sum(d["n"] for d in bk.values())
youth_share = sum(grp[k][0] for k in groups if k[1] == "30세 미만") / g_cnt.sum() \
            + 0.5 * sum(grp[k][0] for k in groups if k[1] == "30세 이상") / g_cnt.sum()
SIGMA = 0.8    # 연령대 안에서의 급여 퍼짐 (로그정규)
# 후보를 많이 뽑은 뒤, 급여 구간 비율이 국세통계 4-2-4와 같아지도록 가중치를 줘서 회원을 고름
POOL = 200_000
pg = rng.choice(len(groups), size=POOL, p=g_p)
pm = np.array([np.log(g_mean[groups[j]]) - SIGMA ** 2 / 2 for j in pg])
ps = np.maximum(np.round(np.exp(rng.normal(pm, SIGMA)), -4), 1_000_000)
plab = np.array([bracket(v) for v in ps])
prop = pd.Series(plab).value_counts(normalize=True)
w = np.array([(bk[l]["n"] / total_n) / prop[l] for l in plab]); w /= w.sum()
pick = rng.choice(POOL, size=N_MEMBER, replace=False, p=w)

members, incomes = [], []
for i in range(1, N_MEMBER + 1):
    j = pick[i - 1]
    k = groups[pg[j]]
    lo, hi = AGE_RANGE[k[1]]
    age = int(rng.integers(lo, hi + 1))
    birth = dt.date(TAX_YEAR - age, 1, 1) + dt.timedelta(days=int(rng.integers(0, 365)))
    sal = int(ps[j])
    lab = bracket(sal)
    d = bk[lab]
    paid = int(round(sal * (d["paid"] / d["sal"]) * rng.uniform(0.85, 1.15), -1))
    # v3.9: 사회보험료를 국민연금(연금보험료공제)과 건강·고용보험료(특별소득공제 · 표준세액공제와 택1)로 나눔 · 비율은 소수 7자리 반올림 (81번 스크립트와 같은 값)
    pension_ins = int((Decimal(sal) * Decimal(d["nps"] / d["sal"]).quantize(Decimal("0.0000001")) / 10).quantize(Decimal("1"), rounding=ROUND_HALF_UP) * 10)
    health_ins = int((Decimal(sal) * Decimal(d["ins"] / d["sal"]).quantize(Decimal("0.0000001")) / 10).quantize(Decimal("1"), rounding=ROUND_HALF_UP) * 10)
    persons = d["basic_amt"] * 1e6 / 1_500_000 / d["basic_n"] if d["basic_n"] else 1
    dependents = int(min(rng.poisson(max(persons - 1, 0)), 6))
    rent = house = pension = 0
    if rng.random() < rate(lab, "rent_n"):
        credit = d["rent_amt"] * 1e6 / d["rent_n"]
        rent_year = min(credit / (0.17 if sal <= 55_000_000 else 0.15), 10_000_000)
        rent = int(round(rent_year / 12, -4))          # MONTHLY_RENT = 월 월세액 (ERD 정의)
    if rng.random() < rate(lab, "house_n"):
        house = int(round(min(d["house_amt"] * 1e6 / d["house_n"] / 0.40, 3_000_000), -4))
    if rng.random() < rate(lab, "pen_n"):
        pension = int(round(min(d["pen_amt"] * 1e6 / d["pen_n"] / (0.15 if sal <= 55_000_000 else 0.12), 9_000_000), -4))
    youth = age <= 34
    sme = youth and rng.random() < min(rate(lab, "sme_n") / max(youth_share, 1e-9), 0.9)
    homeless = "Y" if (rent or house) else "N"
    hire = (dt.date(TAX_YEAR, 1, 1) - dt.timedelta(days=int(rng.integers(30, 365 * 5)))) if sme else None
    if hire:   # v3.2: 입사일은 만 15세 이후로 (중소기업 감면 나이 조건 15~34세 · 난수 순서는 그대로라 다른 회원 값은 안 바뀜)
        try:
            age15 = birth.replace(year=birth.year + 15)
        except ValueError:   # 2월 29일생
            age15 = birth.replace(year=birth.year + 15, day=28)
        hire = max(hire, age15)
    members.append(dict(MEMBER_ID=i, LOGIN_ID=f"test{i:04d}", EMAIL=f"test{i:04d}@example.com", PASSWORD=pw_hash, NAME=f"가상회원{i:04d}",
                        BIRTH_DATE=birth.isoformat(), GENDER=k[0], MILITARY_MONTHS=0,
                        HIRE_DATE=hire.isoformat() if hire else "", COMPANY_SIZE="SME" if sme else "",
                        HOMELESS_HEAD_YN=homeless, ROLE="USER", STATUS="ACTIVE",
                        CREATED_AT=JOIN, UPDATED_AT=JOIN, WITHDRAWN_AT="",
                        TERMS_AGREED_AT=JOIN, PRIVACY_AGREED_AT=JOIN, DATA_ORIGIN="GENERATED",   # 동의 일시 = 가입일 · v2.9 데이터 구분 = 생성
                        LOGIN_FAIL_COUNT=0, LOCKED_UNTIL="", TERMS_VERSION="1.0", PRIVACY_VERSION="1.0",
                        EMAIL_VERIFIED_YN="Y", FINANCE_AGREED_AT=JOIN, FINANCE_VERSION="1.0"))   # v3.4 인증 Y · v3.8 금융 정보 저장 동의(가입일 · 1.0) · v3.0 로그인 잠금 없음 · 약관·개인정보 1.0 동의
    incomes.append(dict(INCOME_ID=i, MEMBER_ID=i, TAX_YEAR=TAX_YEAR, TOTAL_SALARY=sal, WITHHELD_TAX=paid,
                        NATIONAL_PENSION=pension_ins, DEPENDENTS=dependents, MONTHLY_RENT=rent,
                        HOUSING_SAVING=house, PENSION_SAVING=pension, SME_REDUCTION_YN="Y" if sme else "N",
                        UPDATED_AT=dt.date(TAX_YEAR, 10, 20).isoformat(),
                        CREATED_AT=dt.date(TAX_YEAR, 10, 20).isoformat(),   # v2.8 등록일 (가상 데이터는 수정일과 같게)
                        DATA_ORIGIN="GENERATED",   # v2.9 데이터 구분 = 생성
                        CHILDREN=0, HEALTH_INSURANCE=health_ins))   # v3.9 건강·고용보험료 맨 뒤 · v3.3 20세 이하 자녀 수 - 급여구간별 자녀 수 공공 통계가 없어 0으로 둠 (자녀 한도는 사이트 입력값으로 확인)
# 관리자 1명 (P1 관리자 화면 테스트용)
members.append(dict(MEMBER_ID=N_MEMBER + 1, LOGIN_ID="admin", EMAIL="admin@example.com", PASSWORD=pw_hash, NAME="관리자",
                    BIRTH_DATE="1990-01-01", GENDER="", MILITARY_MONTHS=0, HIRE_DATE="", COMPANY_SIZE="",
                    HOMELESS_HEAD_YN="N", ROLE="ADMIN", STATUS="ACTIVE", CREATED_AT=JOIN, UPDATED_AT=JOIN,
                    WITHDRAWN_AT="", TERMS_AGREED_AT=JOIN, PRIVACY_AGREED_AT=JOIN, DATA_ORIGIN="GENERATED",
                    LOGIN_FAIL_COUNT=0, LOCKED_UNTIL="", TERMS_VERSION="1.0", PRIVACY_VERSION="1.0",
                    EMAIL_VERIFIED_YN="Y", FINANCE_AGREED_AT=JOIN, FINANCE_VERSION="1.0"))
mem = pd.DataFrame(members); inc = pd.DataFrame(incomes)
mem.to_csv(os.path.join(OUT, "MEMBER.csv"), index=False, encoding="utf-8-sig")
inc.to_csv(os.path.join(OUT, "INCOME.csv"), index=False, encoding="utf-8-sig")

# 검증표: 만든 데이터의 급여 구간 비율 vs 국세통계 4-2-4
gen = inc.TOTAL_SALARY.map(bracket).value_counts(normalize=True)
val = pd.DataFrame([{"급여구간": lab, "국세통계_비율": round(bk[lab]["n"] / total_n * 100, 2),
                     "가상데이터_비율": round(gen.get(lab, 0) * 100, 2)} for lab, _, _ in BR])
val.to_csv(os.path.join(OUT, "검증_급여구간_비율비교.csv"), index=False, encoding="utf-8-sig")
gv = mem[mem.ROLE == "USER"].assign(AGE_GROUP=lambda x: TAX_YEAR - pd.to_datetime(x.BIRTH_DATE).dt.year)
val2 = pd.DataFrame([{"성별": k[0], "연령대": k[1], "국세통계_비율": round(grp[k][0] / g_cnt.sum() * 100, 2),
                      "가상데이터_비율": round(((gv.GENDER == k[0]) & gv.AGE_GROUP.between(*AGE_RANGE[k[1]])).mean() * 100, 2)}
                     for k in groups])
val2.to_csv(os.path.join(OUT, "검증_성연령_비율비교.csv"), index=False, encoding="utf-8-sig")

# ── 3. 카드 내역 (테스트용) ─────────────────────────────────────
ml = pd.concat([pd.read_csv(os.path.join(DATA, f), dtype=str) for f in sorted(os.listdir(DATA))
                if f.startswith("MERCHANT_LIST_정제_") and f.endswith(".csv")])
gen_names = pd.read_csv(os.path.join(DATA, "일반_상가정보샘플_utf8.csv"), dtype=str)
gen_names = (gen_names["상호명"].fillna("") + " " + gen_names["지점명"].fillna("")).str.strip().tolist()
pool = {c: ml[ml.CATEGORY_ID == str(c)].MERCHANT_NAME.tolist() for c in (2, 3, 4, 5)}
# 카드 명세서처럼 보이게: 문화체육 영화관은 정제 이름(관 번호 없는 이름)을 씀
movie = ml[(ml.CATEGORY_ID == "4") & ml.SOURCE_NAME.str.contains("영화")].NORMALIZED_NAME.tolist()
MIX = [(1, 0.55), (5, 0.10), (2, 0.12), (3, 0.08), (4, 0.15)]   # 테스트용 비율 (공식 통계 아님)
AMT = {1: (3000, 80000), 5: (20000, 150000), 2: (1250, 3000), 3: (3000, 40000), 4: (8000, 70000)}
uploads, expenses = [], []
eid = 0
for m in range(1, N_CARD_MEMBER + 1):
    uid = m
    n_rows = int(rng.integers(60, 151))
    rows = []
    for _ in range(n_rows):
        cat = [c for c, _ in MIX][rng.choice(len(MIX), p=[p for _, p in MIX])]
        if cat == 1: name = random.choice(gen_names)
        elif cat == 4 and rng.random() < 0.3: name = random.choice(movie)
        else: name = random.choice(pool[cat])
        lo, hi = AMT[cat]
        amt = int(round(rng.uniform(lo, hi), -1))
        day = dt.date(TAX_YEAR, 1, 1) + dt.timedelta(days=int(rng.integers(0, 292)))   # 1/1 ~ 10/19
        pay = ["CREDIT", "CHECK"][rng.integers(0, 2)]
        rows.append((day, name, amt, pay))
    rows.sort()
    fname = f"카드내역_test{m:04d}.csv"
    pd.DataFrame([{"이용일자": d.isoformat(), "가맹점명": n, "이용금액": a,
                   "결제수단": {"CREDIT": "신용", "CHECK": "체크"}[p]} for d, n, a, p in rows]) \
      .to_csv(os.path.join(UP, fname), index=False, encoding="utf-8-sig")
    uploads.append(dict(UPLOAD_ID=uid, MEMBER_ID=m, FILE_NAME=fname, ROW_COUNT=len(rows),
                        UPLOADED_AT=dt.date(TAX_YEAR, 10, 20).isoformat(), DATA_ORIGIN="GENERATED"))
    for d, n, a, p in rows:
        eid += 1
        expenses.append(dict(EXPENSE_ID=eid, MEMBER_ID=m, UPLOAD_ID=uid, USED_DATE=d.isoformat(), MERCHANT_NAME=n,
                             PAY_METHOD=p, AMOUNT=a, CATEGORY_ID=1, LIST_ID=""))
pd.DataFrame(uploads).to_csv(os.path.join(OUT, "CARD_UPLOAD.csv"), index=False, encoding="utf-8-sig")
pd.DataFrame(expenses).to_csv(os.path.join(OUT, "EXPENSE.csv"), index=False, encoding="utf-8-sig")
print(f"MEMBER {len(mem)} · INCOME {len(inc)} · CARD_UPLOAD {len(uploads)} · EXPENSE {len(expenses)}")
print(val.to_string(index=False))
