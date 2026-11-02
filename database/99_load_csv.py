"""
99_load_csv.py · CSV → Oracle 적재 (MERCHANT_LIST 정제본 + 가상 회원·소득·카드내역)

준비:  pip install oracledb pandas
실행:  python 99_load_csv.py --user 계정 --password 비밀번호 --dsn localhost:1521/XEPDB1
       (01_schema.sql, 02_기준데이터.sql 을 먼저 실행해 둔 상태여야 함)
옵션:  --only merchant   → MERCHANT_LIST만 적재
       --truncate        → 적재 전에 대상 테이블 비우기 (자식 테이블부터) · 새 계정·테스트 계정 전용
                           서비스 데이터(예측·대화·문의·접근 기록·인증 코드)가 있거나, 분류된 지출이 목록을 가리키고 있으면
                           지우지 않고 멈춤 (공용 DB에서는 쓰지 않기 · 목록 행은 원래 지우지 않고 USE_YN='N')
끝나면 각 시퀀스를 「현재 최대 PK + 1」부터 시작하도록 다시 만들고, 04_분류쿼리.sql로 EXPENSE를 분류한 뒤 통계를 수집함
"""
import argparse, glob, os, datetime as dt
import pandas as pd
import oracledb

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.dirname(HERE)            # 희망환급_데이터 폴더 (MERCHANT_LIST_정제_*.csv 위치)
GEN = os.path.join(HERE, "가상데이터")

DATE_COLS = {"BASE_DATE", "BIRTH_DATE", "HIRE_DATE", "CREATED_AT", "UPDATED_AT", "UPLOADED_AT", "USED_DATE",
             "WITHDRAWN_AT", "TERMS_AGREED_AT", "PRIVACY_AGREED_AT", "LOCKED_UNTIL", "FINANCE_AGREED_AT"}
# (테이블, CSV 파일들, PK 칸, 시퀀스)
PLAN = [
    ("MERCHANT_LIST", sorted(glob.glob(os.path.join(DATA, "MERCHANT_LIST_정제_*.csv"))), "LIST_ID", "SEQ_MERCHANT_LIST"),
    ("MEMBER",        [os.path.join(GEN, "MEMBER.csv")],      "MEMBER_ID",  "SEQ_MEMBER"),
    ("INCOME",        [os.path.join(GEN, "INCOME.csv")],      "INCOME_ID",  "SEQ_INCOME"),
    ("CARD_UPLOAD",   [os.path.join(GEN, "CARD_UPLOAD.csv")], "UPLOAD_ID",  "SEQ_CARD_UPLOAD"),
    ("EXPENSE",       [os.path.join(GEN, "EXPENSE.csv")],     "EXPENSE_ID", "SEQ_EXPENSE"),
]

def to_rows(df):
    rows = []
    for rec in df.to_dict("records"):
        r = []
        for c, v in rec.items():
            if pd.isna(v) or v == "":
                r.append(None)
            elif c in DATE_COLS:
                r.append(dt.datetime.fromisoformat(str(v)[:10]))
            else:
                r.append(v)
        rows.append(r)
    return rows

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--user", required=True); ap.add_argument("--password", required=True)
    ap.add_argument("--dsn", required=True)
    ap.add_argument("--only", choices=["merchant"]); ap.add_argument("--truncate", action="store_true")
    a = ap.parse_args()
    plan = PLAN[:1] if a.only == "merchant" else PLAN

    con = oracledb.connect(user=a.user, password=a.password, dsn=a.dsn)
    cur = con.cursor()
    if a.truncate:
        # v3.1: 공용 DB처럼 서비스 데이터가 쌓인 계정에서는 DELETE가 FK에 걸리거나 지우면 안 되는 데이터까지 지워짐 → 멈춤
        guards = ["PREDICTION", "CHAT_SESSION", "INQUIRY", "ACCESS_LOG", "PASSWORD_RESET"]
        busy = []
        for t in guards:
            cur.execute(f"SELECT COUNT(*) FROM {t}")
            if cur.fetchone()[0]: busy.append(t)
        if a.only == "merchant":
            cur.execute("SELECT COUNT(*) FROM EXPENSE WHERE LIST_ID IS NOT NULL")
            if cur.fetchone()[0]: busy.append("EXPENSE.LIST_ID(분류 근거)")
        if busy:
            raise SystemExit("--truncate 중단: 데이터가 있는 테이블 " + ", ".join(busy) + " → 새 계정에서만 쓰기")
        for t, *_ in reversed(plan):
            cur.execute(f"DELETE FROM {t}"); print(f"{t} 비움")
        con.commit()

    for table, files, pk, seq in plan:
        if not files or not all(os.path.exists(f) for f in files):
            raise SystemExit(f"{table}: CSV가 없어요 → {files}  (05_가상데이터_생성.py 먼저 실행)")
        df = pd.concat([pd.read_csv(f, dtype=str, keep_default_na=False) for f in files], ignore_index=True)
        for c in df.columns:   # 숫자 칸은 숫자로
            if (c.endswith("_ID") and c != "LOGIN_ID") or c in ("TAX_YEAR", "TOTAL_SALARY", "WITHHELD_TAX", "NATIONAL_PENSION", "HEALTH_INSURANCE", "DEPENDENTS",
                                          "MONTHLY_RENT", "HOUSING_SAVING", "PENSION_SAVING", "MILITARY_MONTHS",
                                          "ROW_COUNT", "AMOUNT", "LOGIN_FAIL_COUNT", "CHILDREN"):   # v3.3 CHILDREN
                df[c] = pd.to_numeric(df[c].replace("", None))
        cols = list(df.columns)
        sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join(':' + str(i + 1) for i in range(len(cols)))})"
        rows = to_rows(df)
        for i in range(0, len(rows), 5000):
            cur.executemany(sql, rows[i:i + 5000])
        con.commit()
        cur.execute(f"SELECT NVL(MAX({pk}), 0) + 1 FROM {table}"); nxt = cur.fetchone()[0]
        cur.execute(f"DROP SEQUENCE {seq}")
        cur.execute(f"CREATE SEQUENCE {seq} START WITH {nxt} INCREMENT BY 1 " + ("CACHE 20" if seq == "SEQ_EXPENSE" else "NOCACHE"))
        print(f"{table}: {len(rows):,}건 적재 · {seq} 다음 번호 {nxt}")

    if a.only != "merchant":
        # 업로드 건마다 04_분류쿼리.sql 의 3) 과 같은 분류 실행
        sql = open(os.path.join(HERE, "04_분류쿼리.sql"), encoding="utf-8").read()
        func = sql.split("CREATE OR REPLACE FUNCTION")[1].split("\n/\n")[0]
        cur.execute("CREATE OR REPLACE FUNCTION" + func)
        upd = sql.split("-- 3-1)")[1].split(";")[0].split("\n", 1)[1]
        merge = sql.split("-- 3-2)")[1].split("MERGE INTO", 1)[1].split(";")[0]
        cur.execute("SELECT UPLOAD_ID FROM CARD_UPLOAD ORDER BY UPLOAD_ID")
        ids = [r[0] for r in cur.fetchall()]
        for uid in ids:
            cur.execute(upd, upload_id=uid)
            cur.execute("MERGE INTO" + merge, upload_id=uid)
        con.commit()
        cur.execute("""SELECT c.CATEGORY_NAME, COUNT(*), SUM(e.AMOUNT) FROM EXPENSE e
                       JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = e.CATEGORY_ID GROUP BY c.CATEGORY_NAME ORDER BY 2 DESC""")
        print("분류 결과:", cur.fetchall())
    # 대량 적재 직후 통계 수집 → Oracle이 인덱스를 제대로 쓰도록
    cur.execute("BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')); END;")
    print("통계 수집 완료")
    con.close()

if __name__ == "__main__":
    main()
