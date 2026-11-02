-- 04_분류쿼리.sql · 카드 내역 → 공제 라벨 자동 분류 (공공 목록 상호명 대조 · 10/20 확정 방식)
-- 사용: 카드 내역 파일을 EXPENSE에 넣은 뒤(업로드 1건 = UPLOAD_ID 1개) 아래 3)을 실행
-- 우선순위: 공제 대상 아님(5) → 대중교통(2) → 전통시장(3) → 문화체육(4) → 어디에도 없으면 일반(1)
-- 10/21 추가: 0) 업로드 전 중복 확인 (DB 구조 변경 없음 · v2.7 그대로)
-- v3.2 (10/23): 사용 중인 분류(SPEND_CATEGORY.USE_YN = 'Y')의 목록만 대조 (파일만 바뀜 · DB 변경 없음)
-- v3.1 (10/23): 정제 함수가 ℃·₂ 같은 기호를 파이썬(07)과 같게 바꿈 · 같은 조건이면 LIST_ID 작은 것 선택

-- ─────────────────────────────────────────────
-- 0) 업로드 전 중복 확인 - 파일을 EXPENSE에 넣기 「전」에 실행
--    같은 파일·겹치는 기간을 다시 올리면 카드 사용액이 두 번 집계돼 환급액이 부풀려짐
--    → 막지는 않고(같은 날 같은 가게 같은 금액 결제는 정상일 수 있음) 겹치는 건수를 화면에 경고
--    흐름: 파일 읽기 → 파일의 가장 이른/늦은 사용일로 아래 조회 → 백엔드에서 겹친 건수 계산
--          → 0건이면 저장 / 1건 이상이면 경고 → 사용자가 「그래도 올리기」 누르면 저장
--    겹친 건수 = (사용일·가맹점명·금액·결제수단)이 같은 결제끼리 min(기존 건수, 새 파일 건수)의 합
--    인덱스 IX_EXPENSE_MEMBER_DATE (MEMBER_ID, USED_DATE) 사용
-- ─────────────────────────────────────────────
-- SELECT USED_DATE, MERCHANT_NAME, AMOUNT, PAY_METHOD, COUNT(*) AS CNT
--   FROM EXPENSE
--  WHERE MEMBER_ID = :member_id
--    AND USED_DATE BETWEEN :min_date AND :max_date
--  GROUP BY USED_DATE, MERCHANT_NAME, AMOUNT, PAY_METHOD;

-- ─────────────────────────────────────────────
-- 1) 가맹점명 정제 함수 - MERCHANT_LIST.NORMALIZED_NAME을 만든 규칙과 같음
--    (전각→반각, 대문자, 법인 표기 제거, 끝의 「한국지점」 제거, 한글·영문·숫자만 남김)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION FN_NORMALIZE_NAME (p_name IN VARCHAR2)
RETURN VARCHAR2 DETERMINISTIC
IS
  v VARCHAR2(400);
  TYPE t_list IS TABLE OF VARCHAR2(10);
  -- 로마 숫자·원 문자는 Python(NFKC)과 같게 일반 글자로 바꿈 (예: 상영관Ⅰ → 상영관I)
  -- v3.1: Python(NFKC)과 결과가 같도록 ℃·아래첨자 숫자·ⅵ~ⅹ·원 숫자 11~20·㈕까지 추가 (예: 카페(cafe)66℃ → 카페CAFE66C)
  --       cp949에 없는 글자(원 숫자 16~20, 아래첨자 0·5~9)는 UNISTR로 적음 (SQL Developer cp949 파일에서도 그대로 실행되게)
  src t_list := t_list('Ⅰ','Ⅱ','Ⅲ','Ⅳ','Ⅴ','Ⅵ','Ⅶ','Ⅷ','Ⅸ','Ⅹ','ⅰ','ⅱ','ⅲ','ⅳ','ⅴ','ⅵ','ⅶ','ⅷ','ⅸ','ⅹ','①','②','③','④','⑤','⑥','⑦','⑧','⑨','⑩','⑪','⑫','⑬','⑭','⑮',UNISTR('\246F'),UNISTR('\2470'),UNISTR('\2471'),UNISTR('\2472'),UNISTR('\2473'),'℃','℉',UNISTR('\2080'),'₁','₂','₃','₄',UNISTR('\2085'),UNISTR('\2086'),UNISTR('\2087'),UNISTR('\2088'),UNISTR('\2089'),'¹','²','³','㈕');
  dst t_list := t_list('I','II','III','IV','V','VI','VII','VIII','IX','X','i','ii','iii','iv','v','vi','vii','viii','ix','x','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','C','F','0','1','2','3','4','5','6','7','8','9','1','2','3','(아)');
BEGIN
  IF p_name IS NULL THEN RETURN NULL; END IF;
  v := TO_SINGLE_BYTE(p_name);
  FOR i IN 1 .. src.COUNT LOOP v := REPLACE(v, src(i), dst(i)); END LOOP;
  v := UPPER(v);
  v := REPLACE(v, '㈜', '(주)');
  v := REGEXP_REPLACE(v, '(주식회사|유한회사|유한책임회사|사단법인|재단법인|사회적협동조합|협동조합|\(주\)|\(유\)|\(사\)|\(재\)|\(합\)|㈔|㈕|주\))', '');
  v := REGEXP_REPLACE(TRIM(v), '한국지점$', '');
  v := REGEXP_REPLACE(v, '[^0-9A-Z가-힣]', '');
  RETURN v;
END;
/

-- ─────────────────────────────────────────────
-- 2) 확인용: 가맹점명 하나가 어떤 라벨로 가는지 보기
--    예) SELECT * FROM TABLE(...) 대신 아래 쿼리의 :name 에 값 넣고 실행
-- ─────────────────────────────────────────────
-- SELECT m.LIST_ID, m.MERCHANT_NAME, m.MATCH_TYPE, c.CATEGORY_NAME
--   FROM MERCHANT_LIST m JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = m.CATEGORY_ID
--  WHERE m.USE_YN = 'Y'
--    AND (   (m.MATCH_TYPE = 'EXACT'    AND m.NORMALIZED_NAME = FN_NORMALIZE_NAME(:name))
--         OR (m.MATCH_TYPE = 'CONTAINS' AND INSTR(FN_NORMALIZE_NAME(:name), m.NORMALIZED_NAME) > 0))
--  ORDER BY DECODE(m.CATEGORY_ID, 5, 1, 2, 2, 3, 3, 4, 4, 9), DECODE(m.MATCH_TYPE, 'EXACT', 1, 2);

-- ─────────────────────────────────────────────
-- 3) 업로드 1건 분류 (v3.7: 사용자가 분류를 직접 고치지 않으므로 업로드의 모든 행을 분류)
-- ─────────────────────────────────────────────
-- 3-1) 먼저 전부 일반으로 초기화
UPDATE EXPENSE
   SET CATEGORY_ID = 1, LIST_ID = NULL
 WHERE UPLOAD_ID = :upload_id;

-- 3-2) 목록에 걸리는 행만 우선순위가 가장 높은 라벨로 바꿈
MERGE INTO EXPENSE e
USING (
  -- x: 업로드 1건의 가맹점명을 먼저 한 번만 정제 (MATERIALIZE 없으면 목록 8만 건마다 함수가 다시 돌아 매우 느림)
  WITH x AS (SELECT /*+ MATERIALIZE */ EXPENSE_ID, FN_NORMALIZE_NAME(MERCHANT_NAME) AS NNAME
               FROM EXPENSE WHERE UPLOAD_ID = :upload_id),
       -- h: EXACT(인덱스로 같은 이름) + CONTAINS(약 700개, 포함 여부) 후보 전부
       h AS (SELECT x.EXPENSE_ID, m.LIST_ID, m.CATEGORY_ID, m.MATCH_TYPE, m.NORMALIZED_NAME
               FROM x JOIN MERCHANT_LIST m ON m.NORMALIZED_NAME = x.NNAME AND m.MATCH_TYPE = 'EXACT' AND m.USE_YN = 'Y'
                    JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = m.CATEGORY_ID AND c.USE_YN = 'Y'   -- v3.2: 사용 중인 분류만
             UNION ALL
             SELECT x.EXPENSE_ID, m.LIST_ID, m.CATEGORY_ID, m.MATCH_TYPE, m.NORMALIZED_NAME
               FROM x JOIN MERCHANT_LIST m ON m.MATCH_TYPE = 'CONTAINS' AND m.USE_YN = 'Y' AND INSTR(x.NNAME, m.NORMALIZED_NAME) > 0
                    JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = m.CATEGORY_ID AND c.USE_YN = 'Y')
  SELECT EXPENSE_ID, LIST_ID, CATEGORY_ID FROM (
    SELECT h.*, ROW_NUMBER() OVER (PARTITION BY EXPENSE_ID
             ORDER BY DECODE(CATEGORY_ID, 5, 1, 2, 2, 3, 3, 4, 4, 9),   -- 확정 우선순위
                      DECODE(MATCH_TYPE, 'EXACT', 1, 2),                 -- 같은 라벨이면 정확히 일치 먼저
                      LENGTH(NORMALIZED_NAME) DESC,                      -- 그다음 더 긴 이름 먼저
                      LIST_ID) AS RN                                     -- v3.1: 그래도 같으면 번호가 작은 목록 (07 파이썬과 같게)
      FROM h)
  WHERE RN = 1
) r
ON (e.EXPENSE_ID = r.EXPENSE_ID)
WHEN MATCHED THEN UPDATE SET e.CATEGORY_ID = r.CATEGORY_ID, e.LIST_ID = r.LIST_ID;

COMMIT;

-- ─────────────────────────────────────────────
-- 4) 결과 확인: 업로드 1건의 라벨별 건수·금액
-- ─────────────────────────────────────────────
-- SELECT c.CATEGORY_NAME, e.PAY_METHOD, COUNT(*) AS CNT, SUM(e.AMOUNT) AS AMT
--   FROM EXPENSE e JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = e.CATEGORY_ID
--  WHERE e.UPLOAD_ID = :upload_id
--  GROUP BY c.CATEGORY_NAME, e.PAY_METHOD
--  ORDER BY 1, 2;
