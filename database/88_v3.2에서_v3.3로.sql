-- 88_v3.2에서_v3.3로.sql · 이미 v3.2로 만든 계정(교육원 공용 DB 포함)을 v3.3으로 올리는 스크립트 (10/23)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.3이 됨
-- 89(가상 회원 입사일 수정)를 이미 했으면 그대로 두고 이것만 실행
-- ※ v3.4(87)보다 먼저 실행할 것 - 87을 먼저 하면 아래 3)의 INSERT가 칸 수(UPDATED_AT·UPDATED_BY) 안 맞아 ORA-00947로 실패
--
-- v3.3에서 바뀐 것 - 카드 소득공제 기본한도 자녀 가산 (조특법 §126의2⑩ 2025.12.23 개정 · 2026.1.1 이후 시작 과세기간 = 2026 귀속부터)
--   기본한도: 총급여 7천만 이하 300만 → 자녀 1명 350만 · 2명 이상 400만 / 7천만 초과 250만 → 자녀 1명 275만 · 2명 이상 300만
--   자녀등 = 20세 이하 직계비속·입양자·위탁아동 중 소득금액 100만 이하(근로소득만이면 총급여 500만 이하) · 다른 사람 기본공제 대상 아님 (조특령 §121의2 제18항)
--   1) INCOME · PREDICTION_INPUT 맨 뒤에 CHILDREN(20세 이하 자녀 수) 칸 추가 · 기본값 0 → 기존 행은 모두 0
--   2) 금액 0 이상 CHECK 2개(CK_INCOME_AMOUNT · CK_PRED_INPUT_AMOUNT)에 CHILDREN >= 0 추가 (CHECK 개수 40 그대로)
--   3) DEDUCTION_TYPE에 2026년 자녀 한도 4행 추가 (18 → 22행)
-- 맨 아래 4) 확인 · 5) 일부러 틀린 값 넣어 보기(전부 ROLLBACK) 결과를 보면 됨

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - CHILDREN 칸 0 · 자녀 한도 행 0 · 2026 기준 행 18 이어야 함 (다르면 멈추고 알려 주세요)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN ('INCOME', 'PREDICTION_INPUT') AND COLUMN_NAME = 'CHILDREN') AS CHILDREN_칸,   -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE LIKE 'CARD\_LIMIT\_CHILD%' ESCAPE '\') AS 자녀한도_행,                                -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TAX_YEAR = 2026) AS 기준_2026,                                                                  -- 18
       (SELECT LAST_NUMBER FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'SEQ_DEDUCTION_TYPE') AS 다음_항목번호                                       -- 19
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 1) CHILDREN 칸 추가 (DEFAULT + NOT NULL이라 기존 행은 0으로 채워짐)
-- ─────────────────────────────────────────────
ALTER TABLE INCOME ADD (CHILDREN NUMBER(2) DEFAULT 0 NOT NULL);
ALTER TABLE PREDICTION_INPUT ADD (CHILDREN NUMBER(2) DEFAULT 0 NOT NULL);
COMMENT ON COLUMN INCOME.CHILDREN IS '20세 이하 자녀 수(조특령 §121의2 제18항 자녀등 · 카드 공제 자녀 한도용)';
COMMENT ON COLUMN PREDICTION_INPUT.CHILDREN IS '20세 이하 자녀 수(조특령 §121의2 제18항 자녀등 · 카드 공제 자녀 한도용)';

-- ─────────────────────────────────────────────
-- 2) 금액 0 이상 CHECK 다시 만들기 (CHILDREN 추가)
-- ─────────────────────────────────────────────
ALTER TABLE INCOME DROP CONSTRAINT CK_INCOME_AMOUNT;
ALTER TABLE INCOME ADD CONSTRAINT CK_INCOME_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND SOCIAL_INSURANCE >= 0 AND DEPENDENTS >= 0
                                     AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0);
ALTER TABLE PREDICTION_INPUT DROP CONSTRAINT CK_PRED_INPUT_AMOUNT;
ALTER TABLE PREDICTION_INPUT ADD CONSTRAINT CK_PRED_INPUT_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND SOCIAL_INSURANCE >= 0 AND DEPENDENTS >= 0
                                         AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0);

-- ─────────────────────────────────────────────
-- 3) 자녀 한도 4행 추가 (02_기준데이터.sql 맨 뒤 4행과 같음 · 새 계정과 항목번호 19~22로 같게)
-- ─────────────────────────────────────────────
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD1_LOW', '카드 기본한도(자녀1·7천만 이하)', 'CARD_RULE', 0, 3500000, 70000000, NULL, NULL, '조특법 §126의2⑩ (2025.12.23 개정) · 조특령 §121의2 제18항');
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD2_LOW', '카드 기본한도(자녀2+·7천만 이하)', 'CARD_RULE', 0, 4000000, 70000000, NULL, NULL, '조특법 §126의2⑩ (2025.12.23 개정) · 조특령 §121의2 제18항');
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD1_HIGH', '카드 기본한도(자녀1·7천만 초과)', 'CARD_RULE', 0, 2750000, NULL, NULL, NULL, '조특법 §126의2⑩ (2025.12.23 개정) · 조특령 §121의2 제18항');
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD2_HIGH', '카드 기본한도(자녀2+·7천만 초과)', 'CARD_RULE', 0, 3000000, NULL, NULL, NULL, '조특법 §126의2⑩ (2025.12.23 개정) · 조특령 §121의2 제18항');
COMMIT;
-- ※ 두 번 실행하면 UQ_DEDUCTION_YEAR_CODE(연도·코드 중복 금지)에 걸려 ORA-00001이 나고 행은 안 늘어남 (ALTER도 ORA-01430으로 멈춤)

-- ─────────────────────────────────────────────
-- 4) 확인 (예상 결과는 오른쪽 주석)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,   -- 40
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'INCOME') AS INCOME_칸,                                         -- 15
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'PREDICTION_INPUT') AS 예측입력_칸,                              -- 11
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TAX_YEAR = 2026) AS 기준_2026,                                                  -- 22
       (SELECT COUNT(*) FROM INCOME WHERE CHILDREN <> 0) AS 자녀수_0아닌_소득,                                                    -- 0
       (SELECT COUNT(*) FROM INCOME) AS 소득                                                                                      -- 1,000 (실행 전과 같음)
  FROM DUAL;

SELECT TYPE_ID, TYPE_CODE, LIMIT_AMOUNT, SALARY_LIMIT        -- 19 CHILD1_LOW 3500000 70000000 / 20 CHILD2_LOW 4000000 70000000
  FROM DEDUCTION_TYPE                                         -- 21 CHILD1_HIGH 2750000 (빈칸) / 22 CHILD2_HIGH 3000000 (빈칸)
 WHERE TYPE_CODE LIKE 'CARD_LIMIT%'
 ORDER BY TYPE_ID;

-- ─────────────────────────────────────────────
-- 5) 일부러 틀린 값 넣어 보기 - 4줄 모두 「OK」가 나와야 정상 · 마지막에 ROLLBACK이라 데이터는 안 바뀜
--    (보기 > DBMS 출력 창을 켜고 실행)
-- ─────────────────────────────────────────────
DECLARE
  v_income NUMBER;
  PROCEDURE chk(p_name VARCHAR2, p_code NUMBER, p_expect NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_code = p_expect THEN 'OK   ' ELSE 'FAIL ' END
                         || p_name || ' (기대 ' || CASE WHEN p_expect = 0 THEN '오류 없음' ELSE 'ORA' || TO_CHAR(p_expect) END
                         || ' / 실제 ' || CASE WHEN p_code = 0 THEN '오류 없음' ELSE 'ORA' || TO_CHAR(p_code) END || ')');
  END;
BEGIN
  SELECT MIN(INCOME_ID) INTO v_income FROM INCOME;

  -- ① 자녀 수 음수 → ORA-02290
  BEGIN
    UPDATE INCOME SET CHILDREN = -1 WHERE INCOME_ID = v_income;
    chk('① 소득 자녀 수 -1', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('① 소득 자녀 수 -1', SQLCODE, -2290); END;

  -- ② 자녀 수 NULL → ORA-01407 (NOT NULL 칸을 NULL로 UPDATE)
  BEGIN
    UPDATE INCOME SET CHILDREN = NULL WHERE INCOME_ID = v_income;
    chk('② 소득 자녀 수 NULL', 0, -1407);
  EXCEPTION WHEN OTHERS THEN chk('② 소득 자녀 수 NULL', SQLCODE, -1407); END;

  -- ③ 정상 자녀 수 2 → 오류 없음
  BEGIN
    UPDATE INCOME SET CHILDREN = 2 WHERE INCOME_ID = v_income;
    chk('③ 소득 자녀 수 2', 0, 0);
  EXCEPTION WHEN OTHERS THEN chk('③ 소득 자녀 수 2', SQLCODE, 0); END;

  -- ④ 같은 자녀 한도 행 또 넣기 → ORA-00001 (연도·코드 중복 금지)
  BEGIN
    INSERT INTO DEDUCTION_TYPE VALUES (-1, 2026, 'CARD_LIMIT_CHILD1_LOW', '테스트', 'CARD_RULE', 0, 1, NULL, NULL, NULL, NULL);
    chk('④ 자녀 한도 중복', 0, -1);
  EXCEPTION WHEN OTHERS THEN chk('④ 자녀 한도 중복', SQLCODE, -1); END;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('-- 테스트 끝 · ROLLBACK 완료 (데이터 변경 없음)');
END;
/
