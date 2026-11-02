-- 80_v3.9에서_v4.0로.sql · 이미 v3.9로 만든 계정(교육원 공용 DB 포함)을 v4.0으로 올리는 스크립트 (10/30)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v4.0이 됨
-- v3.8 계정이면 81(v3.8→v3.9)을 먼저 실행하고 이것을 실행
--
-- v4.0에서 바뀐 것 (10/30 · 계산 담당 결정 「계산 결과 항목별 공제 내역」)
--   1) DEDUCTION_TYPE 4행 추가: 근로소득공제(EARNED_DEDUCTION) · 근로소득세액공제(EARNED_CREDIT) × 2026·2025 귀속
--        이유: 항목별 공제 내역(PREDICTION_DETAIL)은 DEDUCTION_TYPE 행을 가리켜야 저장되는데,
--              이 두 항목은 기준값이 TAX_BRACKET(구간표)에만 있어서 내역에 저장할 수 없었음
--        → 이름·종류·근거만 담는 행 (RATE 0 · 공제율과 구간은 그대로 TAX_BRACKET의 같은 이름 구간을 씀)
--        근로소득공제 한도 2,000만 원은 LIMIT_AMOUNT에 · 근로소득세액공제 한도(총급여별 74만·66만·50만·20만 하한이 있는 식)는 계산 코드
--   2) PREDICTION_DETAIL.DEDUCTION_AMOUNT 설명 수정: 카드 한도를 넘은 금액은 한도 행(CARD_LIMIT_*)에 음수로 저장 (10/30 결정 · 칸 제약 변경 없음)
-- DB 구조 변경 없음 (ERD 그림 그대로) · 테이블 20 · 칸 210 · CHECK 50 · UNIQUE 12 · 인덱스 25 그대로 · 기준값 46 → 50행
-- 백엔드: 새 행도 TYPE_ID 말고 TAX_YEAR + TYPE_CODE로 찾기 (공용 DB와 새 계정의 TYPE_ID가 다를 수 있음)

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 기준값 46 · 새 코드 0 · 구간 30 이어야 함 (다르면 멈추고 알려 주세요)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS 기준값_행,   -- 46 (2026 25 + 2025 21)
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT')) AS 새_코드,  -- 0
       (SELECT COUNT(*) FROM TAX_BRACKET) AS 구간_행,        -- 30
       (SELECT COUNT(*) FROM TAX_BRACKET WHERE BRACKET_TYPE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT')) AS 근로소득_구간  -- 14 (연도마다 공제 5 + 세액공제 2)
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 1) DEDUCTION_TYPE 4행 추가 (2026 → 2025 순서 · 02_기준데이터.sql 2-2)와 같은 순서)
-- ─────────────────────────────────────────────
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'EARNED_DEDUCTION', '근로소득공제', 'INCOME_DEDUCTION', 0, 20000000, NULL, NULL, NULL,
        '국세청 신고안내 94p · 소득세법 §47 (공제율·구간은 TAX_BRACKET EARNED_DEDUCTION · 공제액 최대 2,000만)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'EARNED_CREDIT', '근로소득세액공제', 'TAX_CREDIT', 0, NULL, NULL, NULL, NULL,
        '국세청 신고안내 162p · 소득세법 §59 (공제율·구간은 TAX_BRACKET EARNED_CREDIT · 총급여별 한도는 계산 코드)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, 'EARNED_DEDUCTION', '근로소득공제', 'INCOME_DEDUCTION', 0, 20000000, NULL, NULL, NULL,
        '국세청 신고안내 94p · 소득세법 §47 (공제율·구간은 TAX_BRACKET EARNED_DEDUCTION · 공제액 최대 2,000만)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, 'EARNED_CREDIT', '근로소득세액공제', 'TAX_CREDIT', 0, NULL, NULL, NULL, NULL,
        '국세청 신고안내 162p · 소득세법 §59 (공제율·구간은 TAX_BRACKET EARNED_CREDIT · 총급여별 한도는 계산 코드)', 0);

-- ─────────────────────────────────────────────
-- 2) 설명 수정
-- ─────────────────────────────────────────────
COMMENT ON COLUMN PREDICTION_DETAIL.DEDUCTION_AMOUNT IS '공제·감면액 (카드 한도 초과분은 CARD_LIMIT_* 행에 음수 · v4.0)';

COMMIT;

-- ─────────────────────────────────────────────
-- 3) 확인 - 기준값 50 · 새 코드 4 · 연도별 2026 27 / 2025 23
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS 기준값_행,   -- 50
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT')) AS 새_코드  -- 4
  FROM DUAL;

SELECT TAX_YEAR, COUNT(*) AS 행 FROM DEDUCTION_TYPE GROUP BY TAX_YEAR ORDER BY TAX_YEAR;   -- 2025 23 · 2026 27

SELECT TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT
  FROM DEDUCTION_TYPE WHERE TYPE_CODE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT') ORDER BY TAX_YEAR DESC, TYPE_ID;

-- ─────────────────────────────────────────────
-- 4) 일부러 틀린 값 넣어 보기 - 전부 막혀야 정상 (ROLLBACK)
-- ─────────────────────────────────────────────
DECLARE
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
  t('2026 근로소득공제 중복',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''EARNED_DEDUCTION'', ''t'', ''INCOME_DEDUCTION'', 0, 0)');
  t('2025 근로소득세액공제 중복',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, ''EARNED_CREDIT'', ''t'', ''TAX_CREDIT'', 0, 0)');
END;
/
