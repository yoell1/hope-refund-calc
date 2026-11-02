"""
03_데이터적재_SQL만들기.py · CSV → 03_데이터적재.sql (Python·oracledb 없이 SQL Developer에서 바로 실행용)
결과 파일을 SQL Developer에서 @03_데이터적재.sql (F5)로 실행하면
MERCHANT_LIST · MEMBER · INCOME · CARD_UPLOAD · EXPENSE 적재 → 시퀀스 번호 맞춤 → 카드 내역 자동 분류 → 통계 수집까지 끝남
"""
import os, glob, sys
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.dirname(HERE)
GEN = os.path.join(HERE, "가상데이터")
ENC = sys.argv[1] if len(sys.argv) > 1 else "utf-8"
OUT = os.path.join(HERE, "03_데이터적재.sql") if ENC == "utf-8" else os.path.join(HERE, ENC, "03_데이터적재.sql")   # v3.2: cp949판은 실행 안내대로 cp949 폴더에
DATE_COLS = {"BASE_DATE", "BIRTH_DATE", "HIRE_DATE", "CREATED_AT", "UPDATED_AT", "UPLOADED_AT", "USED_DATE",
             "WITHDRAWN_AT", "TERMS_AGREED_AT", "PRIVACY_AGREED_AT", "LOCKED_UNTIL", "FINANCE_AGREED_AT"}
NUM_COLS = {"TAX_YEAR", "TOTAL_SALARY", "WITHHELD_TAX", "NATIONAL_PENSION", "HEALTH_INSURANCE", "DEPENDENTS", "MONTHLY_RENT",
            "HOUSING_SAVING", "PENSION_SAVING", "MILITARY_MONTHS", "ROW_COUNT", "AMOUNT", "LOGIN_FAIL_COUNT", "CHILDREN", "IRP_SAVING"}   # v3.0 LOGIN_FAIL_COUNT · v3.3 CHILDREN · v4.1 IRP_SAVING
PLAN = [("MERCHANT_LIST", sorted(glob.glob(os.path.join(DATA, "MERCHANT_LIST_정제_*.csv"))), "LIST_ID", "SEQ_MERCHANT_LIST"),
        ("MEMBER", [os.path.join(GEN, "MEMBER.csv")], "MEMBER_ID", "SEQ_MEMBER"),
        ("INCOME", [os.path.join(GEN, "INCOME.csv")], "INCOME_ID", "SEQ_INCOME"),
        ("CARD_UPLOAD", [os.path.join(GEN, "CARD_UPLOAD.csv")], "UPLOAD_ID", "SEQ_CARD_UPLOAD"),
        ("EXPENSE", [os.path.join(GEN, "EXPENSE.csv")], "EXPENSE_ID", "SEQ_EXPENSE")]
CHUNK = 500
# v2.9: CSV에 없는 맨 뒤 칸 값 (MERCHANT_LIST 정제본 CSV는 그대로 두고 여기서 붙임)
EXTRA = {"MERCHANT_LIST": ["'COLLECTED'", "SYSDATE"]}   # DATA_ORIGIN = 수집, UPDATED_AT = 적재 시각

def lit(c, v):
    if v is None or v == "": return "NULL"
    if c in DATE_COLS: return f"DATE '{str(v)[:10]}'"
    if (c.endswith("_ID") and c != "LOGIN_ID") or c in NUM_COLS: return str(int(float(v)))
    return "'" + str(v).replace("'", "''") + "'"

lines = ["-- 03_데이터적재.sql · 자동 생성 파일 (03_데이터적재_SQL만들기.py) · 01_schema, 02_기준데이터 다음에 실행",
         "SET DEFINE OFF", "SET FEEDBACK OFF", "SET SERVEROUTPUT ON", ""]
for table, files, pk, seq in PLAN:
    df = pd.concat([pd.read_csv(f, dtype=str, keep_default_na=False) for f in files], ignore_index=True)
    cols = list(df.columns)
    lines.append(f"PROMPT {table} {len(df):,}건 적재 중...")
    rows = df.values.tolist()
    for i in range(0, len(rows), CHUNK):
        lines.append("INSERT ALL")
        for r in rows[i:i + CHUNK]:
            lines.append(f"  INTO {table} VALUES ({', '.join([lit(c, v) for c, v in zip(cols, r)] + EXTRA.get(table, []))})")
        lines.append("SELECT 1 FROM DUAL;")
    lines.append("COMMIT;")
    lines += ["DECLARE n NUMBER; BEGIN",
              f"  SELECT NVL(MAX({pk}), 0) + 1 INTO n FROM {table};",
              f"  EXECUTE IMMEDIATE 'DROP SEQUENCE {seq}';",
              f"  EXECUTE IMMEDIATE 'CREATE SEQUENCE {seq} START WITH ' || n || ' INCREMENT BY 1 {'CACHE 20' if seq == 'SEQ_EXPENSE' else 'NOCACHE'}';",
              "END;", "/", ""]

# 카드 내역 자동 분류 — 가맹점명 정제 함수는 04_분류쿼리.sql 의 것을 그대로 가져와 만듦
_q = open(os.path.join(HERE, "04_분류쿼리.sql"), encoding="utf-8").read()
lines += ["CREATE OR REPLACE FUNCTION" + _q.split("CREATE OR REPLACE FUNCTION")[1].split("\n/\n")[0], "/", ""]
lines += ["PROMPT 카드 내역 자동 분류 중...",
          "BEGIN",
          "  FOR u IN (SELECT UPLOAD_ID FROM CARD_UPLOAD ORDER BY UPLOAD_ID) LOOP",
          "    UPDATE EXPENSE SET CATEGORY_ID = 1, LIST_ID = NULL WHERE UPLOAD_ID = u.UPLOAD_ID;",
          *["    " + l for l in _q.split("-- 3-2)")[1].split("MERGE INTO", 1)[1].join(["MERGE INTO", ""]).split(";")[0].replace(":upload_id", "u.UPLOAD_ID").splitlines()],
          "    ;",
          "  END LOOP;",
          "  COMMIT;",
          "END;", "/",
          "PROMPT 통계 수집 중... (대량 적재 직후 Oracle이 인덱스를 제대로 쓰도록)",
          "BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')); END;", "/",
          "SET FEEDBACK ON",
          "SELECT c.CATEGORY_NAME, COUNT(*) AS CNT, SUM(e.AMOUNT) AS AMT FROM EXPENSE e JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = e.CATEGORY_ID GROUP BY c.CATEGORY_NAME ORDER BY 2 DESC;",
          "SELECT 'MERCHANT_LIST' T, COUNT(*) N FROM MERCHANT_LIST UNION ALL SELECT 'MEMBER', COUNT(*) FROM MEMBER UNION ALL SELECT 'INCOME', COUNT(*) FROM INCOME",
          "UNION ALL SELECT 'CARD_UPLOAD', COUNT(*) FROM CARD_UPLOAD UNION ALL SELECT 'EXPENSE', COUNT(*) FROM EXPENSE;"]
with open(OUT, "w", encoding=ENC, errors="strict", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
print(OUT, os.path.getsize(OUT) // 1024, "KB")
