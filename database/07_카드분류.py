"""
07_카드분류.py · 카드 내역 자동 분류 (파이썬 버전 · 10/22)

04_분류쿼리.sql의 정제 함수(FN_NORMALIZE_NAME)와 분류 MERGE를 파이썬으로 옮긴 것.
백엔드(파이썬)가 카드 파일을 EXPENSE에 저장한 직후 classify_upload(conn, upload_id)를 한 번 부르면 된다.

  from 07_카드분류 import MerchantMatcher   ← 파일 이름이 숫자로 시작하면 import가 안 되므로
                                              백엔드에 넣을 때는 card_classifier.py 처럼 이름을 바꿔서 쓰기

규칙 (SQL과 같음)
  - 정제: 전각→반각(NFKC) · 대문자 · 법인 표기 제거 · 끝의 「한국지점」 제거 · 한글·영문·숫자만 남김
  - 대조: EXACT = 정제 이름이 같으면 / CONTAINS = 목록 이름이 가맹점명 안에 들어 있으면
  - 우선순위: 공제 대상 아님(5) → 대중교통(2) → 전통시장(3) → 문화체육(4), 같은 분류면 EXACT 먼저, 그다음 긴 이름 먼저
  - 어디에도 없으면 일반(1) · v3.7: 분류 직접 수정 불가 → 업로드의 모든 행을 분류

확인용 실행 (DB 없이 CSV로 Oracle 결과와 비교):
  python 07_카드분류.py
"""
import re
import unicodedata

GENERAL, TRANSIT, MARKET, CULTURE, EXCLUDED = 1, 2, 3, 4, 5
PRIORITY = {EXCLUDED: 1, TRANSIT: 2, MARKET: 3, CULTURE: 4}   # 그 밖의 분류는 9 (04의 DECODE ... 9와 같음 · v3.1)

_CORP = re.compile(r"(주식회사|유한회사|유한책임회사|사단법인|재단법인|사회적협동조합|협동조합"
                   r"|\(주\)|\(유\)|\(사\)|\(재\)|\(합\)|㈔|㈕|주\))")
_KEEP = re.compile(r"[^0-9A-Z가-힣]")


def normalize_name(name):
    """가맹점명 정제 (MERCHANT_LIST.NORMALIZED_NAME을 만든 규칙과 같음)"""
    if name is None:
        return None
    v = unicodedata.normalize("NFKC", str(name))   # 전각→반각, Ⅰ→I, ①→1, ㈜→(주)
    v = v.upper()
    v = _CORP.sub("", v)
    v = re.sub(r"한국지점$", "", v.strip())
    return _KEEP.sub("", v)


class MerchantMatcher:
    """MERCHANT_LIST를 메모리에 한 번 올려두고 가맹점명을 분류한다 (서버 시작할 때 1번 만들기)
    ※ 목록을 고치면(USE_YN='N', 94 같은 UPDATE) 서버의 matcher도 다시 만들어야 반영됨 → from_db()를 다시 호출"""

    def __init__(self, rows):
        # rows: (LIST_ID, NORMALIZED_NAME, MATCH_TYPE, CATEGORY_ID) — USE_YN='Y'인 행만
        self.exact = {}      # 정제 이름 → 후보 목록
        self.contains = []   # (이름, LIST_ID, CATEGORY_ID) — 약 700개
        for list_id, norm, match_type, cat in rows:
            cat = int(cat)
            if match_type == "EXACT":
                self.exact.setdefault(norm, []).append((int(list_id), cat, norm))
            else:
                self.contains.append((norm, int(list_id), cat))

    @classmethod
    def from_db(cls, conn):
        cur = conn.cursor()
        cur.execute("SELECT m.LIST_ID, m.NORMALIZED_NAME, m.MATCH_TYPE, m.CATEGORY_ID "
                    "FROM MERCHANT_LIST m JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = m.CATEGORY_ID "
                    "WHERE m.USE_YN = 'Y' AND c.USE_YN = 'Y'")   # v3.2: 사용 중인 분류의 목록만 (04와 같음)
        return cls(cur.fetchall())

    def classify(self, merchant_name):
        """가맹점명 → (CATEGORY_ID, LIST_ID) · 일반이면 (1, None)"""
        n = normalize_name(merchant_name)
        if not n:
            return GENERAL, None
        hits = [(PRIORITY.get(c, 9), 1, -len(nm), lid, c) for lid, c, nm in self.exact.get(n, [])]
        hits += [(PRIORITY.get(c, 9), 2, -len(nm), lid, c) for nm, lid, c in self.contains if nm in n]
        if not hits:
            return GENERAL, None
        best = min(hits)
        return best[4], best[3]


def classify_upload(conn, upload_id, matcher, commit=True):
    """업로드 1건 분류 → EXPENSE.CATEGORY_ID · LIST_ID 저장. 반환: {분류번호: 건수}
    commit=False로 부르면 백엔드가 「업로드 저장 + 분류」를 한 트랜잭션으로 묶어 직접 commit/rollback 할 수 있음"""
    cur = conn.cursor()
    cur.execute("SELECT EXPENSE_ID, MERCHANT_NAME FROM EXPENSE "
                "WHERE UPLOAD_ID = :1", [upload_id])
    updates, counts = [], {}
    for expense_id, name in cur.fetchall():
        cat, list_id = matcher.classify(name)
        updates.append([cat, list_id, expense_id])
        counts[cat] = counts.get(cat, 0) + 1
    if updates:
        cur.executemany("UPDATE EXPENSE SET CATEGORY_ID = :1, LIST_ID = :2 WHERE EXPENSE_ID = :3", updates)
    if commit:
        conn.commit()
    return counts


if __name__ == "__main__":
    # DB 없이 확인: 정제본 CSV + 가상 EXPENSE.csv로 분류해서 Oracle 결과와 비교
    import csv, glob, os
    here = os.path.dirname(os.path.abspath(__file__))
    lists = sorted(glob.glob(os.path.join(os.path.dirname(here), "MERCHANT_LIST_정제_*.csv")))
    rows = []
    for f in lists:
        for r in csv.DictReader(open(f, encoding="utf-8-sig")):
            if r["USE_YN"] == "Y":
                rows.append((r["LIST_ID"], r["NORMALIZED_NAME"], r["MATCH_TYPE"], r["CATEGORY_ID"]))
    print(f"MERCHANT_LIST {len(rows):,}행")
    m = MerchantMatcher(rows)
    names = {1: "일반", 2: "대중교통", 3: "전통시장", 4: "문화체육", 5: "공제 대상 아님"}
    oracle = {1: 5811, 4: 1590, 2: 1258, 5: 1007, 3: 787}   # 10/21·10/22 Oracle 분류 결과
    cnt = {}
    for r in csv.DictReader(open(os.path.join(here, "가상데이터", "EXPENSE.csv"), encoding="utf-8-sig")):
        c, _ = m.classify(r["MERCHANT_NAME"])
        cnt[c] = cnt.get(c, 0) + 1
    for c in (1, 4, 2, 5, 3):
        print(f"{names[c]:<8} 파이썬 {cnt.get(c, 0):>5} · Oracle {oracle[c]:>5} {'OK' if cnt.get(c, 0) == oracle[c] else '다름'}")
