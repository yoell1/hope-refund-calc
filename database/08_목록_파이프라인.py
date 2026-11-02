"""
08_목록_파이프라인.py · 분류용 가맹점 목록(MERCHANT_LIST) 만들기 파이프라인 (pandas · 10/22)

공공데이터 CSV → 하나로 모으기 → 이름 정제 → 영화관 상영관 번호 정리 → 체인점 표시
→ 짧은 이름 제거 → 중복 제거 → 대조 방식 정하기 → 기존 목록과 비교 → 저장

- 정제 함수는 07_카드분류.py의 normalize_name을 그대로 씀 → 목록과 카드 내역이 항상 같은 규칙
- 기존 목록과 이름·분류가 같은 행은 LIST_ID를 그대로 유지 (지출 내역이 가리키는 번호가 안 바뀜)
- 10/22 고친 것 (예전 정제 코드의 버그)
    1) 「(주」만 있어도 지우던 규칙 삭제 → 「강화청원농협쌀(주안점)」이 「…안점」이 되던 문제
    2) 상영관 번호의 「제」는 바로 뒤에 숫자가 붙을 때만 지움 → 「CGV거제 6관」이 「CGV거」가 되던 문제

입력: 이 폴더의 바로 위 폴더(희망환급_데이터)에 있는 1차 공공데이터 CSV
      (영업 중인 곳만 / 전통시장 소속만 미리 고른 파일 · 그 앞 단계 코드는 없음)
실행: python 08_목록_파이프라인.py            → 새목록/ 폴더에 결과 + 비교 리포트 (기존 파일은 안 건드림)
      python 08_목록_파이프라인.py --sql      → 기존 목록을 새 목록으로 맞추는 SQL(새목록/목록_반영.sql)도 만듦: 이름 수정 · 없어진 행 끄기 · 새 행 추가 · 같은 이름 다시 켜기 (DELETE 없음 · v3.2)
"""
import os, re, sys, glob, importlib.util
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.dirname(HERE)
OUT = os.path.join(HERE, "새목록")

_spec = importlib.util.spec_from_file_location("card", os.path.join(HERE, "07_카드분류.py"))
_card = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_card)
normalize_name = _card.normalize_name

GENERAL, TRANSIT, MARKET, CULTURE, EXCLUDED = 1, 2, 3, 4, 5
EXCLUDE_SOURCES = [("예금보험", "예금보험공사_부보금융회사 목록", "2026-03-31"),
                   ("DART", "금융감독원 DART 회사명", "2026-10-20"),
                   ("관세청", "관세청_보세판매장 특허 현황", "2025-07-31"),
                   ("", "한국가스안전공사_도시가스 지역관리소", "2026-03-04")]
CULTURE_FILES = [("체력단련장업_영업중_utf8.csv", "행정안전부_생활_체력단련장업"),
                 ("수영장업_영업중_utf8.csv", "행정안전부_생활_수영장업"),
                 ("영화상영관_영업중_utf8.csv", "행정안전부_문화_영화상영관"),
                 ("박물관미술관_영업중_utf8.csv", "행정안전부_문화_박물관 및 미술관"),
                 ("공연장_영업중_utf8.csv", "행정안전부_문화_공연장")]
CINEMA_SUFFIX = r"(SCREENX|IMAX|4DX|DOLBY|CINEDELICHAMBER|TEMPUR|GOLDCLASS|SWEETBOX|BODYCARESEAT|SUITE|CHEF)관?$"


def read(name):
    return pd.read_csv(os.path.join(DATA, name), encoding="utf-8-sig", dtype=str)


def rows_from(df, col, cat, match, src, base, excl_col=None):
    return pd.DataFrame({"MERCHANT_NAME": df[col].astype(str).str.strip(), "CATEGORY_ID": cat,
                         "MATCH_TYPE": match, "EXCLUDE_ITEM": df[excl_col] if excl_col else "",
                         "SOURCE_NAME": src, "BASE_DATE": base})


# 1) 공공데이터 모으기 -------------------------------------------------------------
def load_sources():
    parts = []
    ex = read("공제대상아님_공식목록.csv")
    for _, sub in ex.groupby("구분", sort=False):
        origin = sub["출처"].iloc[0]
        _, src, base = next(s for s in EXCLUDE_SOURCES if s[0] in origin)
        parts.append(rows_from(sub, "상호명", EXCLUDED, "CONTAINS", src, base, "제외 항목(국세청 책자 135쪽)"))
    parts.append(rows_from(read("대중교통_공식목록.csv"), "상호명", TRANSIT, "CONTAINS",
                           "한국교통안전공단_철도운영기관 현황", "2022-06-20"))
    parts.append(rows_from(read("온누리가맹점_전통시장소속_utf8.csv"), "가맹점명", MARKET, "EXACT",
                           "소상공인시장진흥공단_온누리상품권 가맹점 현황", "2026-07-31"))
    for f, src in CULTURE_FILES:
        parts.append(rows_from(read(f), "사업장명", CULTURE, "EXACT", src, "2026-10-19"))
    books = read("문화체육_서점_utf8.csv")
    parts.append(rows_from(books, "상호명", CULTURE, "EXACT", "소상공인시장진흥공단_상가(상권)정보(서점)", "2026-06-30"))
    branch = set(books.loc[books["지점명"].fillna("").str.strip() != "", "상호명"].map(normalize_name))
    return pd.concat(parts, ignore_index=True), branch


# 2) 정제 -----------------------------------------------------------------------
def strip_screen(norm, drop_je):
    """영화관 상영관 번호 정리 (정제한 이름 끝의 「N관」「IMAX관」 등 제거) · drop_je=True면 「제N관」의 「제」도 제거"""
    x = norm
    for _ in range(2):
        x = re.sub((r"(제)?" if drop_je else "") + r"[0-9]+관$", "", x)
        x = re.sub(CINEMA_SUFFIX, "", x)
    return x


def clean(d):
    """이름 정제 · 영화관은 상영관 번호까지 정리
    「제」 처리: 「강남제1관」「건대입구 제1관」「(제8관)」처럼 제 뒤에 숫자가 바로 붙거나 제 앞이 띄어져 있으면 상영관 번호로 보고 지움.
    「거제 6관」「율하제 3관」처럼 제가 앞 글자에 붙고 뒤가 띄어진 경우는 지명일 수도 있어서,
    「제」를 뺀 이름이 다른 상영관 행에서 나오는 극장 이름일 때만 지움 (율하제 3관 → CGV김해율하 / 거제 6관 → CGV거제)"""
    cinema = d.SOURCE_NAME.str.contains("영화상영관")
    d["NORMALIZED_NAME"] = d.MERCHANT_NAME.map(normalize_name)
    cin = d.loc[cinema, ["MERCHANT_NAME", "NORMALIZED_NAME"]]
    unsure = cin.MERCHANT_NAME.str.contains(r"[^\s(\[]제\s+\d+\s*관")
    known = set(strip_screen(n, True) for n in cin.loc[~unsure, "NORMALIZED_NAME"])
    result = []
    for n, u in zip(cin.NORMALIZED_NAME, unsure):
        drop = strip_screen(n, True)
        result.append(drop if (not u or drop in known) else strip_screen(n, False))
    d.loc[cinema, "NORMALIZED_NAME"] = result
    return d, cinema


# 3) 체인점 표시 · 짧은 이름 제거 · 중복 제거 · 대조 방식 ------------------------------------
def finalize(d, cinema, branch):
    cnt = d.groupby(["CATEGORY_ID", "NORMALIZED_NAME"])["NORMALIZED_NAME"].transform("size")
    chain = (cnt >= 3) & (d.NORMALIZED_NAME.str.len() >= 3) & (d.CATEGORY_ID == CULTURE) & ~cinema
    chain |= ((d.CATEGORY_ID == CULTURE) & d.SOURCE_NAME.str.contains("서점")
              & d.NORMALIZED_NAME.isin(branch) & (d.NORMALIZED_NAME.str.len() >= 4))
    d["_chain"] = chain
    d = d[d.NORMALIZED_NAME.str.len() >= 2]                                   # 1글자 이름 제거
    d = d.drop_duplicates(["NORMALIZED_NAME", "CATEGORY_ID"]).copy()          # 같은 분류 안 중복 제거
    d.loc[d._chain, "MATCH_TYPE"] = "CONTAINS"                                # 체인점은 포함 대조
    d.loc[d.NORMALIZED_NAME.isin(["인천국제공항공사", "남양주도시공사"]), "MATCH_TYPE"] = "EXACT"
    d.loc[(d.MATCH_TYPE == "CONTAINS") & (d.NORMALIZED_NAME.str.len() < 4), "MATCH_TYPE"] = "EXACT"  # 짧은 이름은 포함 대조 안 함
    d["USE_YN"] = "Y"
    return d.drop(columns="_chain").sort_values(["CATEGORY_ID", "NORMALIZED_NAME"], kind="stable")


# 4) 기존 목록과 비교 · 번호 정하기 --------------------------------------------------------
def load_old():
    files = sorted(glob.glob(os.path.join(DATA, "MERCHANT_LIST_정제_*.csv")))
    return pd.concat([pd.read_csv(f, encoding="utf-8-sig", dtype=str) for f in files], ignore_index=True)


def assign_ids(new, old):
    """기존 행과 (원본 이름, 분류, 출처)가 같으면 그 LIST_ID를 그대로 씀 · 새 행은 기존 최대 번호 뒤로"""
    old = old.copy(); old["CATEGORY_ID"] = old.CATEGORY_ID.astype(int)
    key = ["MERCHANT_NAME", "CATEGORY_ID", "SOURCE_NAME"]
    m = new.merge(old[key + ["LIST_ID", "NORMALIZED_NAME", "MATCH_TYPE"]].drop_duplicates(key),
                  on=key, how="left", suffixes=("", "_OLD"))
    nxt = int(old.LIST_ID.astype(int).max()) + 1
    miss = m.LIST_ID.isna()
    ids = pd.to_numeric(m.LIST_ID, errors="coerce")
    ids[miss] = range(nxt, nxt + int(miss.sum()))
    m["LIST_ID"] = ids.astype(int)
    return m


def report(m, old):
    changed = m[m.LIST_ID_OLD_present & ((m.NORMALIZED_NAME != m.NORMALIZED_NAME_OLD) | (m.MATCH_TYPE != m.MATCH_TYPE_OLD))]
    added = m[~m.LIST_ID_OLD_present]
    gone = old[~old.LIST_ID.astype(int).isin(m.LIST_ID)]
    return changed, added, gone


def q(v):
    """SQL 문자열 값 (빈 값은 NULL · 작은따옴표는 두 번)"""
    if v is None or (isinstance(v, float) and pd.isna(v)) or str(v) in ("", "nan"):
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"


def write_sql(changed, added, gone):
    """v3.2: 기존 목록을 새 목록으로 맞추는 SQL (DELETE 없음 · 운영 규칙 「분류·목록 행은 지우지 않음」)
    1) 없어진 행 중 새 행과 (정제 이름, 분류)가 같은 것 → 새 행을 넣지 않고 기존 행을 다시 USE_YN='Y'
    2) 정제 이름·대조 방식이 바뀐 행 → UPDATE (LIST_ID 그대로)
    3) 남은 없어진 행 → USE_YN='N'
    4) 새로 생긴 행 → INSERT (LIST_ID는 기존 최대 번호 뒤) → 끝나고 98_시퀀스_재설정.sql 실행
    (정제 이름, 분류)가 다른 행과 겹치면 UQ_MERCHANT_LIST_NAME(ORA-00001)이라 SQL 대신 「확인 필요」 주석으로 남김"""
    gone = gone.copy(); gone["CATEGORY_ID"] = gone.CATEGORY_ID.astype(int)
    gone_key = {(r.NORMALIZED_NAME, int(r.CATEGORY_ID)): int(r.LIST_ID) for r in gone.itertuples()}
    used = set()                      # 이번 SQL로 생기는 (정제 이름, 분류)
    revive, inserts, warns = [], [], []
    for r in added.itertuples():
        k = (r.NORMALIZED_NAME, int(r.CATEGORY_ID))
        if k in gone_key and gone_key[k] not in [x[0] for x in revive]:
            revive.append((gone_key[k], r))
        elif k in used:
            warns.append(f"새 행 {r.LIST_ID} {r.MERCHANT_NAME}: 정제 이름·분류가 다른 새 행과 겹침")
        else:
            inserts.append(r)
        used.add(k)
    revived = {x[0] for x in revive}
    upd = []
    for r in changed.itertuples():
        k = (r.NORMALIZED_NAME, int(r.CATEGORY_ID))
        if k in gone_key and gone_key[k] not in revived:
            warns.append(f"바뀐 행 {r.LIST_ID} {r.MERCHANT_NAME}: 바뀐 이름이 없어진 행 {gone_key[k]}과 겹침")
        elif k in used:
            warns.append(f"바뀐 행 {r.LIST_ID} {r.MERCHANT_NAME}: 바뀐 이름이 다른 행과 겹침")
        else:
            upd.append(r); used.add(k)
    off = [int(r.LIST_ID) for r in gone.itertuples() if int(r.LIST_ID) not in revived]
    path = os.path.join(OUT, "목록_반영.sql")
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- 목록_반영.sql · 08_목록_파이프라인.py --sql 이 만든 파일 · 기존 목록을 새 목록으로 맞춤 (DELETE 없음 · v2.9 이상 계정용)\n")
        f.write(f"-- 다시 켜기 {len(revive)} · 이름 수정 {len(upd)} · 끄기(USE_YN='N') {len(off)} · 새 행 {len(inserts)} · 확인 필요 {len(warns)}\n")
        for w in warns:
            f.write(f"-- 확인 필요: {w}\n")
        f.write("SET DEFINE OFF\n")
        for lid, r in revive:
            f.write(f"UPDATE MERCHANT_LIST SET USE_YN = 'Y', MERCHANT_NAME = {q(r.MERCHANT_NAME)}, MATCH_TYPE = {q(r.MATCH_TYPE)}, "
                    f"SOURCE_NAME = {q(r.SOURCE_NAME)}, BASE_DATE = TO_DATE({q(r.BASE_DATE)}, 'YYYY-MM-DD'), UPDATED_AT = SYSDATE WHERE LIST_ID = {lid};"
                    f"   -- 새목록 CSV의 {r.LIST_ID}번 대신 기존 {lid}번을 다시 씀 (CSV도 {lid}로 고치기)\n")
        for r in upd:
            f.write(f"UPDATE MERCHANT_LIST SET NORMALIZED_NAME = {q(r.NORMALIZED_NAME)}, MATCH_TYPE = {q(r.MATCH_TYPE)}, UPDATED_AT = SYSDATE "
                    f"WHERE LIST_ID = {r.LIST_ID};\n")
        for lid in off:
            f.write(f"UPDATE MERCHANT_LIST SET USE_YN = 'N', UPDATED_AT = SYSDATE WHERE LIST_ID = {lid};\n")
        for r in inserts:
            f.write("INSERT INTO MERCHANT_LIST (LIST_ID, MERCHANT_NAME, NORMALIZED_NAME, MATCH_TYPE, CATEGORY_ID, EXCLUDE_ITEM, SOURCE_NAME, BASE_DATE, USE_YN, DATA_ORIGIN) "
                    f"VALUES ({r.LIST_ID}, {q(r.MERCHANT_NAME)}, {q(r.NORMALIZED_NAME)}, {q(r.MATCH_TYPE)}, {int(r.CATEGORY_ID)}, {q(r.EXCLUDE_ITEM)}, "
                    f"{q(r.SOURCE_NAME)}, TO_DATE({q(r.BASE_DATE)}, 'YYYY-MM-DD'), 'Y', 'COLLECTED');\n")
        f.write("COMMIT;\n")
        if inserts:
            f.write("-- 새 행을 번호를 지정해 넣었으니 98_시퀀스_재설정.sql 실행 (SEQ_MERCHANT_LIST)\n")
    print(f"SQL: {path} (다시 켜기 {len(revive)} · 이름 수정 {len(upd)} · 끄기 {len(off)} · 새 행 {len(inserts)} · 확인 필요 {len(warns)})")


def main():
    os.makedirs(OUT, exist_ok=True)
    d, branch = load_sources()
    print(f"1) 공공데이터 모으기: {len(d):,}행")
    d, cinema = clean(d)
    d = finalize(d, cinema, branch)
    print(f"2~3) 정제·중복 제거 후: {len(d):,}행 · " +
          " · ".join(f"{n} {int((d.CATEGORY_ID == c).sum()):,}" for c, n in
                     [(TRANSIT, '대중교통'), (MARKET, '전통시장'), (CULTURE, '문화체육'), (EXCLUDED, '공제 대상 아님')]))
    old = load_old()
    m = assign_ids(d, old)
    m["LIST_ID_OLD_present"] = m.NORMALIZED_NAME_OLD.notna()
    changed, added, gone = report(m, old)
    print(f"4) 기존 목록 {len(old):,}행과 비교: 정제 이름·대조 방식이 바뀐 행 {len(changed)} · 새로 생긴 행 {len(added)} · 없어진 행 {len(gone)}")
    cols = ["LIST_ID", "MERCHANT_NAME", "NORMALIZED_NAME_OLD", "NORMALIZED_NAME", "MATCH_TYPE_OLD", "MATCH_TYPE", "SOURCE_NAME"]
    changed[cols].to_csv(os.path.join(OUT, "비교_바뀐행.csv"), index=False, encoding="utf-8-sig")
    added.to_csv(os.path.join(OUT, "비교_새로생긴행.csv"), index=False, encoding="utf-8-sig")
    gone.to_csv(os.path.join(OUT, "비교_없어진행.csv"), index=False, encoding="utf-8-sig")
    final = m[["LIST_ID", "MERCHANT_NAME", "NORMALIZED_NAME", "MATCH_TYPE", "CATEGORY_ID", "EXCLUDE_ITEM",
               "SOURCE_NAME", "BASE_DATE", "USE_YN"]].sort_values("LIST_ID")
    final.to_csv(os.path.join(OUT, "MERCHANT_LIST_새목록.csv"), index=False, encoding="utf-8-sig")
    if "--sql" in sys.argv:
        write_sql(changed, added, gone)
    print(f"결과: {OUT}")
    return changed, added, gone


if __name__ == "__main__":
    main()
