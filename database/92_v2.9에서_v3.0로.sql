-- 92_v2.9에서_v3.0로.sql · 이미 v2.9로 만든 계정(교육원 공용 DB 포함)을 v3.0으로 올리는 스크립트 (10/23)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.0이 됨
--
-- v3.0에서 바뀐 것
--   1) MEMBER 로그인 잠금 LOGIN_FAIL_COUNT · LOCKED_UNTIL
--   2) MEMBER 약관·개인정보 동의 버전 TERMS_VERSION · PRIVACY_VERSION (기존 회원은 '1.0', 새 가입은 기본값 없음 → 백엔드가 꼭 넣음)
--   3) EXPENSE → CARD_UPLOAD FK를 (UPLOAD_ID, MEMBER_ID) 두 칸으로 → 지출 회원 = 업로드 회원
--   4) MERCHANT_LIST (NORMALIZED_NAME, CATEGORY_ID) 중복 금지 · 이름 인덱스는 이것으로 대체
--   5) PREDICTION 결과 4칸 NOT NULL
--   6) 세법 기준값 검사 6개
--   7) EXPENSE 분류 인덱스 삭제
-- 맨 아래 4) 확인 · 5) 일부러 틀린 값 넣어 보기(전부 ROLLBACK) 결과를 보면 됨

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 둘 다 0이어야 함 (0이 아니면 멈추고 알려 주세요)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM PREDICTION
         WHERE TAXABLE_INCOME IS NULL OR CALCULATED_TAX IS NULL OR DECIDED_TAX IS NULL OR EXPECTED_REFUND IS NULL) AS 결과_빈_예측,
       (SELECT COUNT(*) FROM (SELECT NORMALIZED_NAME, CATEGORY_ID FROM MERCHANT_LIST
                               GROUP BY NORMALIZED_NAME, CATEGORY_ID HAVING COUNT(*) > 1)) AS 목록_중복,
       (SELECT COUNT(*) FROM EXPENSE E JOIN CARD_UPLOAD U ON U.UPLOAD_ID = E.UPLOAD_ID
         WHERE U.MEMBER_ID <> E.MEMBER_ID) AS 지출_회원_불일치
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 1) MEMBER: 로그인 잠금 · 동의 버전 (맨 뒤 칸 4개, 01_schema.sql 칸 순서와 같음)
-- ─────────────────────────────────────────────
ALTER TABLE MEMBER ADD (LOGIN_FAIL_COUNT NUMBER(2)    DEFAULT 0 NOT NULL,
                        LOCKED_UNTIL     DATE,
                        TERMS_VERSION    VARCHAR2(10) DEFAULT '1.0' NOT NULL,
                        PRIVACY_VERSION  VARCHAR2(10) DEFAULT '1.0' NOT NULL);
-- 기존 회원은 '1.0'으로 채워졌으니 기본값을 없앰 → 새 가입에서 버전을 빠뜨리면 오류(ORA-01400)
ALTER TABLE MEMBER MODIFY (TERMS_VERSION DEFAULT NULL, PRIVACY_VERSION DEFAULT NULL);
ALTER TABLE MEMBER ADD CONSTRAINT CK_MEMBER_LOGIN_FAIL CHECK (LOGIN_FAIL_COUNT >= 0);

-- ─────────────────────────────────────────────
-- 2) 지출 회원 = 업로드 회원 (부모 쪽 UNIQUE 먼저 → FK 다시 만들기)
-- ─────────────────────────────────────────────
ALTER TABLE CARD_UPLOAD ADD CONSTRAINT UQ_CARD_UPLOAD_MEMBER UNIQUE (UPLOAD_ID, MEMBER_ID);
ALTER TABLE EXPENSE DROP CONSTRAINT FK_EXPENSE_UPLOAD;
ALTER TABLE EXPENSE ADD CONSTRAINT FK_EXPENSE_UPLOAD FOREIGN KEY (UPLOAD_ID, MEMBER_ID)
  REFERENCES CARD_UPLOAD (UPLOAD_ID, MEMBER_ID) ON DELETE CASCADE;

-- ─────────────────────────────────────────────
-- 3) 가맹점 목록 중복 금지 (이름 대조 인덱스 대체)
-- ─────────────────────────────────────────────
DROP INDEX IX_MERCHANT_LIST_NAME;
ALTER TABLE MERCHANT_LIST ADD CONSTRAINT UQ_MERCHANT_LIST_NAME UNIQUE (NORMALIZED_NAME, CATEGORY_ID);

-- ─────────────────────────────────────────────
-- 4) 예측 결과 4칸 NOT NULL
-- ─────────────────────────────────────────────
ALTER TABLE PREDICTION MODIFY (TAXABLE_INCOME NOT NULL, CALCULATED_TAX NOT NULL, DECIDED_TAX NOT NULL, EXPECTED_REFUND NOT NULL);

-- ─────────────────────────────────────────────
-- 5) 세법 기준값 검사 6개
-- ─────────────────────────────────────────────
ALTER TABLE DEDUCTION_TYPE    ADD CONSTRAINT CK_DEDUCTION_RATE    CHECK (RATE BETWEEN 0 AND 100);
ALTER TABLE DEDUCTION_TYPE    ADD CONSTRAINT CK_DEDUCTION_CARD    CHECK (DEDUCTION_KIND <> 'CARD' OR CATEGORY_ID IS NOT NULL);
ALTER TABLE TAX_BRACKET       ADD CONSTRAINT CK_TAX_BRACKET_RATE  CHECK (RATE BETWEEN 0 AND 100);
ALTER TABLE TAX_BRACKET       ADD CONSTRAINT CK_TAX_BRACKET_RANGE CHECK (UPPER_AMOUNT IS NULL OR UPPER_AMOUNT > LOWER_AMOUNT);
ALTER TABLE BENEFIT_CONDITION ADD CONSTRAINT CK_BENEFIT_RATE      CHECK (REDUCTION_RATE BETWEEN 0 AND 100);
ALTER TABLE BENEFIT_CONDITION ADD CONSTRAINT CK_BENEFIT_AGE       CHECK (MIN_AGE IS NULL OR MAX_AGE IS NULL OR MIN_AGE <= MAX_AGE);

-- ─────────────────────────────────────────────
-- 6) 지출 분류 인덱스 삭제 (분류 행은 지우지 않음 · 값 5개라 조회에 안 쓰임)
-- ─────────────────────────────────────────────
DROP INDEX IX_EXPENSE_CATEGORY;

COMMENT ON COLUMN MEMBER.LOGIN_FAIL_COUNT IS '로그인 연속 실패 횟수(5번째 실패 시 잠금 후 0)';
COMMENT ON COLUMN MEMBER.LOCKED_UNTIL IS '로그인 잠금 해제 시각(NULL=잠금 없음)';
COMMENT ON COLUMN MEMBER.TERMS_VERSION IS '동의한 이용약관 버전';
COMMENT ON COLUMN MEMBER.PRIVACY_VERSION IS '동의한 개인정보 처리방침 버전';

-- ─────────────────────────────────────────────
-- 7) 확인 (예상 결과는 오른쪽 주석)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,   -- 40
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'U') AS UNIQUE_수,                                          -- 10
       (SELECT COUNT(*) FROM USER_INDEXES I WHERE I.INDEX_NAME LIKE 'IX\_%' ESCAPE '\') AS 일반_인덱스,                           -- 19
       (SELECT COUNT(*) FROM USER_CONS_COLUMNS WHERE CONSTRAINT_NAME = 'FK_EXPENSE_UPLOAD') AS 지출FK_칸수,                      -- 2
       (SELECT COUNT(*) FROM MEMBER WHERE TERMS_VERSION = '1.0' AND PRIVACY_VERSION = '1.0' AND LOGIN_FAIL_COUNT = 0) AS 회원_1점0,  -- 1,001 (전체 회원 수와 같으면 정상)
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'MEMBER') AS MEMBER_칸수                                        -- 23
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 8) 일부러 틀린 값 넣어 보기 - 전부 「OK」가 나와야 정상 · 마지막에 ROLLBACK이라 데이터는 안 바뀜
--    (SQL Developer: 보기 > DBMS 출력 창을 켜야 결과가 보임)
-- ─────────────────────────────────────────────
DECLARE
  v_up   NUMBER;   -- 업로드 1번의 회원
  v_oth  NUMBER;   -- 다른 회원
  PROCEDURE chk(p_name VARCHAR2, p_code NUMBER, p_expect NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_code = p_expect THEN 'OK   ' ELSE 'FAIL ' END
                         || p_name || ' (기대 ORA' || TO_CHAR(p_expect) || ' / 실제 ' || CASE WHEN p_code = 0 THEN '오류 없음' ELSE 'ORA' || TO_CHAR(p_code) END || ')');
  END;
BEGIN
  SELECT MEMBER_ID INTO v_up FROM CARD_UPLOAD WHERE UPLOAD_ID = 1;
  SELECT MIN(MEMBER_ID) INTO v_oth FROM MEMBER WHERE MEMBER_ID <> v_up;

  -- ① 다른 회원의 업로드에 지출 넣기 → ORA-02291
  BEGIN
    INSERT INTO EXPENSE (EXPENSE_ID, MEMBER_ID, UPLOAD_ID, USED_DATE, MERCHANT_NAME, PAY_METHOD, AMOUNT, CATEGORY_ID)
    VALUES (-1, v_oth, 1, DATE '2026-01-01', '테스트', 'CREDIT', 1000, 1);
    chk('① 다른 회원 업로드에 지출', 0, -2291);
  EXCEPTION WHEN OTHERS THEN chk('① 다른 회원 업로드에 지출', SQLCODE, -2291); END;

  -- ①-2 같은 회원이면 정상 저장 (오류 없음이 맞음)
  BEGIN
    INSERT INTO EXPENSE (EXPENSE_ID, MEMBER_ID, UPLOAD_ID, USED_DATE, MERCHANT_NAME, PAY_METHOD, AMOUNT, CATEGORY_ID)
    VALUES (-2, v_up, 1, DATE '2026-01-01', '테스트', 'CREDIT', 1000, 1);
    DBMS_OUTPUT.PUT_LINE('OK   ①-2 같은 회원 업로드에 지출 (오류 없음)');
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL ①-2 같은 회원 업로드에 지출 ORA' || SQLCODE); END;

  -- ② 가맹점 목록 같은 이름·같은 분류 다시 넣기 → ORA-00001
  BEGIN
    INSERT INTO MERCHANT_LIST (LIST_ID, MERCHANT_NAME, NORMALIZED_NAME, CATEGORY_ID, SOURCE_NAME)
    SELECT -1, MERCHANT_NAME, NORMALIZED_NAME, CATEGORY_ID, SOURCE_NAME FROM MERCHANT_LIST WHERE LIST_ID = 1;
    chk('② 목록 중복', 0, -1);
  EXCEPTION WHEN OTHERS THEN chk('② 목록 중복', SQLCODE, -1); END;

  -- ③ 예측 결과 빈 값으로 넣기 → ORA-01400
  BEGIN
    INSERT INTO PREDICTION (PREDICTION_ID, MEMBER_ID, TAX_YEAR) VALUES (-1, v_up, 2026);
    chk('③ 예측 결과 빈 값', 0, -1400);
  EXCEPTION WHEN OTHERS THEN chk('③ 예측 결과 빈 값', SQLCODE, -1400); END;

  -- ④ 공제율 150% → ORA-02290
  BEGIN
    UPDATE DEDUCTION_TYPE SET RATE = 150 WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_CREDIT';
    chk('④ 공제율 150', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('④ 공제율 150', SQLCODE, -2290); END;

  -- ⑤ 카드 공제 행 분류 비우기 → ORA-02290
  BEGIN
    UPDATE DEDUCTION_TYPE SET CATEGORY_ID = NULL WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_CREDIT';
    chk('⑤ 카드 공제 분류 없음', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('⑤ 카드 공제 분류 없음', SQLCODE, -2290); END;

  -- ⑥ 세율 구간 끝 < 시작 → ORA-02290
  BEGIN
    UPDATE TAX_BRACKET SET UPPER_AMOUNT = 1 WHERE TAX_YEAR = 2026 AND BRACKET_TYPE = 'TAX_RATE' AND LOWER_AMOUNT = 14000000;
    chk('⑥ 구간 끝 < 시작', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('⑥ 구간 끝 < 시작', SQLCODE, -2290); END;

  -- ⑦ 세율 150% → ORA-02290
  BEGIN
    UPDATE TAX_BRACKET SET RATE = 150 WHERE TAX_YEAR = 2026 AND BRACKET_TYPE = 'TAX_RATE' AND LOWER_AMOUNT = 0;
    chk('⑦ 세율 150', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('⑦ 세율 150', SQLCODE, -2290); END;

  -- ⑧ 청년 나이 최소 40 > 최대 34 → ORA-02290
  BEGIN
    UPDATE BENEFIT_CONDITION SET MIN_AGE = 40 WHERE TAX_YEAR = 2026 AND BENEFIT_CODE = 'SME_YOUTH';
    chk('⑧ 최소 나이 > 최대 나이', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('⑧ 최소 나이 > 최대 나이', SQLCODE, -2290); END;

  -- ⑨ 감면율 120% → ORA-02290
  BEGIN
    UPDATE BENEFIT_CONDITION SET REDUCTION_RATE = 120 WHERE TAX_YEAR = 2026 AND BENEFIT_CODE = 'SME_YOUTH';
    chk('⑨ 감면율 120', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('⑨ 감면율 120', SQLCODE, -2290); END;

  -- ⑩ 약관 버전 빼고 가입 → ORA-01400
  BEGIN
    INSERT INTO MEMBER (MEMBER_ID, LOGIN_ID, EMAIL, PASSWORD, NAME, BIRTH_DATE, TERMS_AGREED_AT, PRIVACY_AGREED_AT, PRIVACY_VERSION)
    VALUES (-1, 'v30test', 'v30test@example.com', '-', '테스트', DATE '2000-01-01', SYSDATE, SYSDATE, '1.0');
    chk('⑩ 약관 버전 없이 가입', 0, -1400);
  EXCEPTION WHEN OTHERS THEN chk('⑩ 약관 버전 없이 가입', SQLCODE, -1400); END;

  -- ⑪ 로그인 실패 횟수 -1 → ORA-02290
  BEGIN
    UPDATE MEMBER SET LOGIN_FAIL_COUNT = -1 WHERE MEMBER_ID = v_up;
    chk('⑪ 실패 횟수 음수', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('⑪ 실패 횟수 음수', SQLCODE, -2290); END;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('-- 테스트 끝 · ROLLBACK 완료 (데이터 변경 없음)');
END;
/
