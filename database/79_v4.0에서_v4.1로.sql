-- 79_v4.0에서_v4.1로.sql · 이미 v4.0으로 만든 계정(교육원 공용 DB 포함)을 v4.1로 올리는 스크립트 (11/02)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v4.1이 됨
-- v3.9 계정이면 80(v3.9→v4.0)을 먼저 실행하고 이것을 실행
--
-- v4.1에서 바뀐 것 (11/02 · 계산 담당 결정 「연금저축 단독 600만 한도」)
--   1) INCOME·PREDICTION_INPUT: 연금 한 칸 → 두 칸
--        PENSION_SAVING = 연금저축만 (설명 변경 · 이름·자리 그대로)
--        IRP_SAVING 맨 뒤 추가 (IRP·퇴직연금계좌 · 기본 0)
--        이유: 연금계좌 세액공제 한도는 합계 900만이지만 그중 연금저축은 600만까지 (소득세법 §59의3)
--              → 합친 금액만 있으면 연금저축만 600만 넘게 낸 사람의 공제를 크게 계산함
--        화면(TaxInfoForm · SimulationPage)은 이미 연금저축 / IRP 두 칸으로 받고 있음 → DB를 화면에 맞춤
--   2) 가상 회원(GENERATED) 중 연금 600만 초과 행: 600만 넘는 부분을 IRP_SAVING으로 옮김
--        가상 연금 값은 국세통계 「연금계좌」(연금저축 + IRP 합계) 기준이라 합계·공제액이 바뀌지 않게 하려는 것
--        직접 입력(INPUT) 행은 그대로 둠 (있으면 그 회원이 화면에서 두 칸을 다시 입력)
--        PREDICTION_INPUT은 지난 계산 기록이라 값을 바꾸지 않음 (IRP_SAVING = 0)
--   3) CHECK CK_INCOME_AMOUNT · CK_PRED_INPUT_AMOUNT 다시 만듦 (IRP_SAVING >= 0 추가 · 개수 그대로)
--   4) DEDUCTION_TYPE 2행 추가: 연금저축 단독 한도 PENSION_SAVING_LIMIT (600만) × 2026·2025 귀속
--        RATE 0 · 공제율은 그대로 PENSION 행(5,500만 이하 15% · 초과 12%) · 합계 한도 900만도 PENSION 행
-- DB 구조 변경 있음 (ERD v4.1) · 테이블 20 그대로 · 칸 210 → 212 · CHECK 50 그대로 · UNIQUE 12 · 인덱스 25 그대로 · 기준값 50 → 52행
-- 백엔드: 소득·계산 입력 저장 때 IRP_SAVING 같이 저장 (화면의 irp 값) · 새 기준값 행도 TYPE_ID 말고 TAX_YEAR + TYPE_CODE로 찾기

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 테이블 20 · 칸 210 · CHECK 50 · 새 칸 0 · 기준값 50 · 새 코드 0 이어야 함 (다르면 멈추고 알려 주세요)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TABLES) AS 테이블_수,           -- 20
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS 칸_수,   -- 210
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,  -- 50
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE COLUMN_NAME = 'IRP_SAVING') AS 새_칸,           -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS 기준값_행,                                          -- 50
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE = 'PENSION_SAVING_LIMIT') AS 새_코드,  -- 0
       (SELECT COUNT(*) FROM INCOME) AS 소득_행,
       (SELECT COUNT(*) FROM INCOME WHERE DATA_ORIGIN = 'GENERATED' AND PENSION_SAVING > 6000000) AS 연금_600만_초과_가상,  -- 3 (가상데이터 기준)
       (SELECT COUNT(*) FROM INCOME WHERE DATA_ORIGIN <> 'GENERATED' AND PENSION_SAVING > 0) AS 연금_직접입력_행,      -- 보통 0
       (SELECT NVL(SUM(PENSION_SAVING), 0) FROM INCOME) AS 연금_합계,   -- 맨 아래 「연금저축 + IRP 합계」와 같아야 함
       (SELECT COUNT(*) FROM PREDICTION_INPUT) AS 예측입력_행
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 1) IRP 칸 추가 (맨 뒤 · 기본 0) + 연금저축 칸 설명 변경
-- ─────────────────────────────────────────────
ALTER TABLE INCOME ADD (IRP_SAVING NUMBER(10) DEFAULT 0 NOT NULL);
ALTER TABLE PREDICTION_INPUT ADD (IRP_SAVING NUMBER(10) DEFAULT 0 NOT NULL);

COMMENT ON COLUMN INCOME.PENSION_SAVING IS '연금저축 연 납입액(연금저축 600만 한도 · v4.1 IRP는 IRP_SAVING)';
COMMENT ON COLUMN INCOME.IRP_SAVING IS 'IRP(퇴직연금계좌) 연 납입액(연금저축과 합계 900만 한도 · v4.1)';
COMMENT ON COLUMN PREDICTION_INPUT.PENSION_SAVING IS '연금저축 연 납입액(연금저축 600만 한도 · v4.1 IRP는 IRP_SAVING)';
COMMENT ON COLUMN PREDICTION_INPUT.IRP_SAVING IS 'IRP(퇴직연금계좌) 연 납입액(연금저축과 합계 900만 한도 · v4.1)';

-- ─────────────────────────────────────────────
-- 2) 가상 회원 연금 600만 초과분 → IRP로 (합계 그대로 · 수정일은 가상 데이터라 그대로 둠)
-- ─────────────────────────────────────────────
UPDATE INCOME
   SET IRP_SAVING = PENSION_SAVING - 6000000,
       PENSION_SAVING = 6000000
 WHERE DATA_ORIGIN = 'GENERATED'
   AND PENSION_SAVING > 6000000;

-- ─────────────────────────────────────────────
-- 3) 음수 막는 CHECK 다시 만들기 (IRP_SAVING 추가)
-- ─────────────────────────────────────────────
ALTER TABLE INCOME DROP CONSTRAINT CK_INCOME_AMOUNT;
ALTER TABLE INCOME ADD CONSTRAINT CK_INCOME_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND NATIONAL_PENSION >= 0 AND DEPENDENTS >= 0
                                     AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0 AND HEALTH_INSURANCE >= 0
                                     AND IRP_SAVING >= 0);

ALTER TABLE PREDICTION_INPUT DROP CONSTRAINT CK_PRED_INPUT_AMOUNT;
ALTER TABLE PREDICTION_INPUT ADD CONSTRAINT CK_PRED_INPUT_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND NATIONAL_PENSION >= 0 AND DEPENDENTS >= 0
                                         AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0 AND HEALTH_INSURANCE >= 0
                                         AND IRP_SAVING >= 0);

-- ─────────────────────────────────────────────
-- 4) DEDUCTION_TYPE 2행 추가 (2026 → 2025 순서 · 02_기준데이터.sql 2-3)과 같은 순서)
-- ─────────────────────────────────────────────
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'PENSION_SAVING_LIMIT', '연금저축 단독 한도', 'TAX_CREDIT', 0, 6000000, NULL, NULL, NULL,
        '국세청 신고안내 요약표 · 소득세법 §59의3 (연금계좌 900만 중 연금저축은 600만까지 · 공제율은 PENSION 행)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, 'PENSION_SAVING_LIMIT', '연금저축 단독 한도', 'TAX_CREDIT', 0, 6000000, NULL, NULL, NULL,
        '국세청 신고안내 요약표 · 소득세법 §59의3 (연금계좌 900만 중 연금저축은 600만까지 · 공제율은 PENSION 행)', 0);

COMMIT;

-- ─────────────────────────────────────────────
-- 5) 확인 - 칸 212 · CHECK 50 · 새 칸 2 · 기준값 52 · 새 코드 2 · 연금 600만 초과 가상 0 · 연금 합계는 맨 위와 같음
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS 칸_수,   -- 212
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,  -- 50
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE COLUMN_NAME = 'IRP_SAVING') AS 새_칸,           -- 2
       (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS 기준값_행,                                          -- 52
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE = 'PENSION_SAVING_LIMIT') AS 새_코드,  -- 2
       (SELECT COUNT(*) FROM INCOME WHERE DATA_ORIGIN = 'GENERATED' AND PENSION_SAVING > 6000000) AS 연금_600만_초과_가상,  -- 0
       (SELECT NVL(SUM(PENSION_SAVING + IRP_SAVING), 0) FROM INCOME) AS 연금저축_IRP_합계   -- 맨 위 「연금_합계」와 같음
  FROM DUAL;

SELECT TAX_YEAR, COUNT(*) AS 행 FROM DEDUCTION_TYPE GROUP BY TAX_YEAR ORDER BY TAX_YEAR;   -- 2025 24 · 2026 28

SELECT INCOME_ID, TOTAL_SALARY, PENSION_SAVING, IRP_SAVING
  FROM INCOME WHERE IRP_SAVING > 0 ORDER BY INCOME_ID;   -- 옮긴 가상 회원 (가상데이터 기준 3행)

SELECT TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT
  FROM DEDUCTION_TYPE WHERE TYPE_CODE = 'PENSION_SAVING_LIMIT' ORDER BY TAX_YEAR DESC;

-- ─────────────────────────────────────────────
-- 6) 일부러 틀린 값 넣어 보기 - 전부 막혀야 정상 (ROLLBACK)
-- ─────────────────────────────────────────────
DECLARE
  v_cnt NUMBER;
  PROCEDURE t(p_name VARCHAR2, p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE(p_name || ': 실패 - 막히지 않음');
    ROLLBACK;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(p_name || ': OK (' || SUBSTR(SQLERRM, 1, 40) || ')');
    ROLLBACK;
  END;
BEGIN
  t('소득 IRP 음수',
    'UPDATE INCOME SET IRP_SAVING = -1 WHERE INCOME_ID = (SELECT MIN(INCOME_ID) FROM INCOME)');
  SELECT COUNT(*) INTO v_cnt FROM PREDICTION_INPUT;
  IF v_cnt > 0 THEN
    t('계산 입력 IRP 음수',
      'UPDATE PREDICTION_INPUT SET IRP_SAVING = -1 WHERE PREDICTION_ID = (SELECT MIN(PREDICTION_ID) FROM PREDICTION_INPUT)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('계산 입력 IRP 음수: 건너뜀 (PREDICTION_INPUT 0행)');
  END IF;
  t('2026 연금저축 단독 한도 중복',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''PENSION_SAVING_LIMIT'', ''t'', ''TAX_CREDIT'', 0, 0)');
END;
/
