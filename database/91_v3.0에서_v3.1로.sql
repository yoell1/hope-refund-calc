-- 91_v3.0에서_v3.1로.sql · 이미 v3.0으로 만든 계정(교육원 공용 DB 포함)을 v3.1로 올리는 스크립트 (10/23)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.1이 됨
-- 테이블·칸·데이터는 바뀌지 않음 (인덱스 1개와 함수 1개만 다시 만듦)
--
-- v3.1에서 바뀐 것
--   1) 인덱스 IX_EXPENSE_UPLOAD (UPLOAD_ID) → (UPLOAD_ID, MEMBER_ID)
--      v3.0에서 지출 → 업로드 FK가 두 칸이 됐는데 인덱스는 한 칸이라, Oracle이 「FK에 인덱스 없음」으로 보고
--      업로드 삭제·회원 탈퇴 때 EXPENSE 테이블 전체를 잠글 수 있음 → FK 칸 두 개를 모두 앞에 둔 인덱스로 바꿈 (개수는 19 그대로)
--   2) 가맹점명 정제 함수 FN_NORMALIZE_NAME
--      ℃·아래첨자 숫자(₂ 등)·작은 로마 숫자 ⅵ~ⅹ·원 숫자 11~20·㈕를 파이썬(07, NFKC)과 같게 바꿈
--      예전 함수는 이 글자들을 지워서, 목록 4행(카페(cafe)66℃ · 37.5℃ 트레이닝 센터 · 운동센터+1℃ · 헬스&휘트니스 O₂Zone)이 SQL 분류로는 안 걸렸음
--      · 같은 조건이면 LIST_ID가 작은 목록을 고르도록 분류 쿼리(04)도 맞춤 (04 파일만 바뀜 · DB에 저장된 쿼리 아님)
--   ※ 가상 카드 내역 10,453건은 이 글자가 없어서 분류 결과 변화 없음 → 다시 분류하지 않아도 됨
-- 맨 아래 3) 확인 결과를 보면 됨

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 지금 인덱스 칸 (UPLOAD_ID 한 줄이면 v3.0)
-- ─────────────────────────────────────────────
SELECT COLUMN_NAME, COLUMN_POSITION FROM USER_IND_COLUMNS
 WHERE INDEX_NAME = 'IX_EXPENSE_UPLOAD' ORDER BY COLUMN_POSITION;

-- ─────────────────────────────────────────────
-- 1) 인덱스 다시 만들기
-- ─────────────────────────────────────────────
DROP INDEX IX_EXPENSE_UPLOAD;
CREATE INDEX IX_EXPENSE_UPLOAD ON EXPENSE (UPLOAD_ID, MEMBER_ID);

-- ─────────────────────────────────────────────
-- 2) 가맹점명 정제 함수 다시 만들기 (04_분류쿼리.sql 1)과 같음)
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
-- 3) 확인
-- ─────────────────────────────────────────────
-- 3-1) 인덱스: UPLOAD_ID 1 · MEMBER_ID 2 두 줄
SELECT COLUMN_NAME, COLUMN_POSITION FROM USER_IND_COLUMNS
 WHERE INDEX_NAME = 'IX_EXPENSE_UPLOAD' ORDER BY COLUMN_POSITION;

-- 3-2) 개수: 일반 인덱스 19 · 함수 VALID
SELECT (SELECT COUNT(*) FROM USER_INDEXES WHERE INDEX_NAME LIKE 'IX\_%' ESCAPE '\') AS 일반_인덱스,   -- 19
       (SELECT STATUS FROM USER_OBJECTS WHERE OBJECT_NAME = 'FN_NORMALIZE_NAME' AND OBJECT_TYPE = 'FUNCTION') AS 함수_상태   -- VALID
  FROM DUAL;

-- 3-3) 정제 결과: 전부 OK여야 함
SELECT T.입력, FN_NORMALIZE_NAME(T.입력) AS 결과, T.기대,
       CASE WHEN FN_NORMALIZE_NAME(T.입력) = T.기대 THEN 'OK' ELSE 'NG' END AS 판정
  FROM (SELECT '카페(cafe)66℃' AS 입력, '카페CAFE66C' AS 기대 FROM DUAL
        UNION ALL SELECT '헬스&휘트니스 O₂Zone', '헬스휘트니스O2ZONE' FROM DUAL
        UNION ALL SELECT '(주)영풍문고 목포점', '영풍문고목포점' FROM DUAL
        UNION ALL SELECT 'ＣＧＶ 상영관Ⅰ', 'CGV상영관I' FROM DUAL) T;

-- 3-4) 목록 4행: 함수로 정제한 이름 = 저장된 정제 이름 → 4행 모두 OK
SELECT LIST_ID, MERCHANT_NAME, NORMALIZED_NAME,
       CASE WHEN FN_NORMALIZE_NAME(MERCHANT_NAME) = NORMALIZED_NAME THEN 'OK' ELSE 'NG' END AS 판정
  FROM MERCHANT_LIST WHERE LIST_ID IN (46720, 54801, 71516, 79893) ORDER BY LIST_ID;

-- 3-5) 데이터는 그대로: 회원 1,001 · 지출 10,453 (공용 DB에 테스트 데이터가 더 있으면 그만큼 많음)
SELECT (SELECT COUNT(*) FROM MEMBER) AS 회원, (SELECT COUNT(*) FROM EXPENSE) AS 지출 FROM DUAL;
