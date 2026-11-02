-- 84_v3.5에서_v3.6로.sql · 이미 v3.5로 만든 계정(교육원 공용 DB 포함)을 v3.6으로 올리는 스크립트 (10/27)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.6이 됨
-- v3.4 계정이면 85(v3.4→v3.5)를 먼저 실행하고 이것을 실행
--
-- v3.6에서 바뀐 것 - 10/27 멘토 피드백 「급여에 따라 공제 비율·한도가 달라지는데 급여 정보와 연결돼 있지 않다 → 관계를 정립할 것」
--   지금까지: 총급여 7천만 기준으로 행을 나누되 구분을 TYPE_CODE 이름(_LOW/_HIGH)으로 해서, 백엔드가 「7천만 이하면 _LOW」를 코드에 박아야 했음
--   바꾼 것: DEDUCTION_TYPE에 급여 구간 두 칸 → 백엔드는 WHERE TYPE_CODE = :code AND :총급여 > SALARY_MIN AND (SALARY_MAX IS NULL OR :총급여 <= SALARY_MAX)
--   1) SALARY_MIN NUMBER(12) DEFAULT 0 NOT NULL  구간 시작(초과) · 맨 뒤 칸
--   2) SALARY_LIMIT → SALARY_MAX 이름 변경        구간 끝(이하 · NULL = 상한 없음) · 뜻은 그대로
--   3) CHECK CK_DEDUCTION_SALARY                   SALARY_MAX IS NULL OR SALARY_MAX > SALARY_MIN
--   4) UNIQUE (TAX_YEAR, TYPE_CODE) → (TAX_YEAR, TYPE_CODE, SALARY_MIN)   같은 코드가 구간별로 여러 행
--   5) 데이터: _LOW/_HIGH 로 나뉘어 있던 12행을 코드 6개로 통합 (행 수는 22 그대로)
--        CARD_LIMIT_BASE_LOW/HIGH → CARD_LIMIT_BASE (0~7천만 300만 · 7천만~ 250만)
--        CARD_LIMIT_EXTRA_LOW/HIGH → CARD_LIMIT_EXTRA (0~7천만 300만 · 7천만~ 200만)
--        CARD_LIMIT_CHILD1_LOW/HIGH → CARD_LIMIT_CHILD1 (350만 · 275만) · CHILD2 (400만 · 300만)
--        PENSION_HIGH/PENSION → PENSION (0~5,500만 15% · 5,500만~ 12%)
--        RENT_HIGH/RENT → RENT (0~5,500만 17% · 5,500만~8천만 15%)
--   구간 경계(7천만·5,500만·8천만)도 이제 행의 숫자 → 관리자 화면에서 한 행 수정 · 구간 추가는 행 INSERT · 코드 변경 없음
-- DB 구조 변경 있음 (ERD v3.6) · 테이블 18 · 칸 175 → 176 · CHECK 42 → 43 · 인덱스 23 · UNIQUE 10 · 기준값 22행 그대로
-- ERDCloud는 나중에 반영 (10/27 결정) · 맨 아래 4) 확인 · 5) 틀린 값 테스트(ROLLBACK) 결과를 보면 됨

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 새칸 0 · 옛칸 1 · LOW/HIGH 행 10 · CHECK 42 이어야 함 (다르면 멈추고 알려 주세요)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DEDUCTION_TYPE' AND COLUMN_NAME = 'SALARY_MIN')   AS 새칸,      -- 0
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DEDUCTION_TYPE' AND COLUMN_NAME = 'SALARY_LIMIT') AS 옛칸,      -- 1
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE LIKE '%\_LOW' ESCAPE '\' OR TYPE_CODE LIKE '%\_HIGH' ESCAPE '\') AS LOW_HIGH행,  -- 10
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수   -- 42
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 1) 구조: 칸 추가 · 이름 변경 · CHECK · UNIQUE
-- ─────────────────────────────────────────────
ALTER TABLE DEDUCTION_TYPE ADD (SALARY_MIN NUMBER(12) DEFAULT 0 NOT NULL);          -- 기존 22행은 0으로 채워짐
ALTER TABLE DEDUCTION_TYPE RENAME COLUMN SALARY_LIMIT TO SALARY_MAX;
ALTER TABLE DEDUCTION_TYPE ADD CONSTRAINT CK_DEDUCTION_SALARY CHECK (SALARY_MAX IS NULL OR SALARY_MAX > SALARY_MIN);
ALTER TABLE DEDUCTION_TYPE DROP CONSTRAINT UQ_DEDUCTION_YEAR_CODE;
ALTER TABLE DEDUCTION_TYPE ADD CONSTRAINT UQ_DEDUCTION_YEAR_CODE UNIQUE (TAX_YEAR, TYPE_CODE, SALARY_MIN);
COMMENT ON COLUMN DEDUCTION_TYPE.SALARY_MIN IS '적용 총급여 구간 시작(초과 · 0 = 처음부터) · v3.6';
COMMENT ON COLUMN DEDUCTION_TYPE.SALARY_MAX IS '적용 총급여 구간 끝(이하 · NULL = 상한 없음) · v3.6 SALARY_LIMIT에서 이름만 바뀜';
COMMENT ON COLUMN DEDUCTION_TYPE.TYPE_CODE  IS '계산 코드 · 같은 코드가 총급여 구간별로 여러 행(TAX_YEAR + TYPE_CODE + 총급여 구간으로 찾기) · v3.6';

-- ─────────────────────────────────────────────
-- 2) 데이터: _HIGH 행은 구간 시작을 넣고, 코드를 통합 (TYPE_ID · 값 · 근거는 그대로)
-- ─────────────────────────────────────────────
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_BASE',   TYPE_NAME = '카드 기본한도(7천만 초과)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_BASE_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_BASE',   TYPE_NAME = '카드 기본한도(7천만 이하)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_BASE_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_EXTRA',  TYPE_NAME = '카드 추가한도(7천만 초과)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_EXTRA_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_EXTRA',  TYPE_NAME = '카드 추가한도(7천만 이하)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_EXTRA_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_CHILD1', TYPE_NAME = '카드 기본한도(자녀1·7천만 초과)'  WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD1_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_CHILD1', TYPE_NAME = '카드 기본한도(자녀1·7천만 이하)'  WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD1_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_CHILD2', TYPE_NAME = '카드 기본한도(자녀2+·7천만 초과)' WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD2_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_CHILD2', TYPE_NAME = '카드 기본한도(자녀2+·7천만 이하)' WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD2_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 55000000,                                  TYPE_NAME = '연금계좌(5,500만 초과)'           WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'PENSION';       -- 12% 행
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'PENSION',           TYPE_NAME = '연금계좌(5,500만 이하)'           WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'PENSION_HIGH';  -- 15% 행
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 55000000,                                  TYPE_NAME = '월세(5,500만 초과~8천만)'         WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'RENT';          -- 15% 행
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'RENT',              TYPE_NAME = '월세(5,500만 이하)'               WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'RENT_HIGH';     -- 17% 행
COMMIT;

-- ─────────────────────────────────────────────
-- 3) 확인 - 칸 176 · CHECK 43 · UNIQUE 10 · 기준값 22 · LOW/HIGH 행 0 · 구간 행(SALARY_MIN > 0) 6
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS 칸_수,                    -- 176
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,  -- 43
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'U') AS UNIQUE_수,                                              -- 10
       (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS 기준값_행,                                                                            -- 22
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE LIKE '%\_LOW' ESCAPE '\' OR TYPE_CODE LIKE '%\_HIGH' ESCAPE '\') AS LOW_HIGH행,  -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE SALARY_MIN > 0) AS 구간행                                                           -- 6
  FROM DUAL;

-- 구간이 있는 코드만 보기 (코드마다 구간이 이어지는지 눈으로 확인)
SELECT TYPE_CODE, SALARY_MIN, SALARY_MAX, RATE, LIMIT_AMOUNT, TYPE_NAME
  FROM DEDUCTION_TYPE
 WHERE TAX_YEAR = 2026 AND TYPE_CODE IN (SELECT TYPE_CODE FROM DEDUCTION_TYPE GROUP BY TAX_YEAR, TYPE_CODE HAVING COUNT(*) > 1)
 ORDER BY TYPE_CODE, SALARY_MIN;

-- 백엔드가 쓸 조회 예 (총급여 6,000만 · 자녀 0 → 기본한도 300만 · 월세 15% · 연금 12%)
SELECT TYPE_CODE, RATE, LIMIT_AMOUNT
  FROM DEDUCTION_TYPE
 WHERE TAX_YEAR = 2026 AND TYPE_CODE IN ('CARD_LIMIT_BASE', 'RENT', 'PENSION')
   AND 60000000 > SALARY_MIN AND (SALARY_MAX IS NULL OR 60000000 <= SALARY_MAX)
 ORDER BY TYPE_CODE;

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
  t('같은 코드·같은 구간 시작 중복',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''CARD_LIMIT_BASE'', ''중복'', ''CARD_RULE'', 0, 0)');
  t('구간 끝 <= 시작',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN, SALARY_MAX) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''TEST_X'', ''역전'', ''CARD_RULE'', 0, 70000000, 70000000)');
  t('구간 시작 NULL',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''TEST_Y'', ''널'', ''CARD_RULE'', 0, NULL)');
END;
/
