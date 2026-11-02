-- 83_v3.6에서_v3.7로.sql · 이미 v3.6으로 만든 계정(교육원 공용 DB 포함)을 v3.7로 올리는 스크립트 (10/27)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.7이 됨
-- v3.5 계정이면 84(v3.5→v3.6)를 먼저 실행하고 이것을 실행
--
-- v3.7에서 바뀐 것 - 10/27 기능명세서 v1.3 팀 댓글 「잘못 분류된 건 직접 고치기 불가」
--   사용자가 분류를 바꿀 수 없으니 「사용자가 고쳤는지」 표시 칸이 필요 없어짐 → 칸 삭제
--   1) CHECK CK_EXPENSE_EDITED 삭제
--   2) EXPENSE.USER_EDITED_YN 칸 삭제 (지금 값은 전부 'N'이라 잃는 정보 없음 - 0)에서 확인)
--   분류 쿼리(04)·파이썬 분류(07)는 「USER_EDITED_YN = 'N'인 행만」 조건을 빼고 업로드의 모든 행을 분류
-- DB 구조 변경 있음 (ERD v3.7) · 테이블 18 · 칸 176 → 175 · CHECK 43 → 42 · 인덱스 23 · UNIQUE 10
-- 백엔드: EXPENSE INSERT·UPDATE·SELECT에 USER_EDITED_YN을 쓰는 곳이 있으면 지울 것 (있으면 ORA-00904)

SET DEFINE OFF

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 칸 1 · Y인 행 0 · CHECK 43 · 칸 176 이어야 함 (다르면 멈추고 알려 주세요)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'EXPENSE' AND COLUMN_NAME = 'USER_EDITED_YN') AS 칸,   -- 1
       (SELECT COUNT(*) FROM EXPENSE WHERE USER_EDITED_YN = 'Y') AS Y인_행,                                              -- 0
       (SELECT COUNT(*) FROM EXPENSE) AS 지출_행,                                                                       -- 실행 후와 같아야 함
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,  -- 43
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS 칸_수          -- 176
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 1) 구조: CHECK 삭제 → 칸 삭제 (DDL이라 바로 반영 · COMMIT 필요 없음)
-- ─────────────────────────────────────────────
ALTER TABLE EXPENSE DROP CONSTRAINT CK_EXPENSE_EDITED;
ALTER TABLE EXPENSE DROP COLUMN USER_EDITED_YN;

-- ─────────────────────────────────────────────
-- 2) 확인 - 칸 0 · CHECK 43 → 42 · 칸 176 → 175 · 지출 행은 0)과 같음 · EXPENSE 칸 9개
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'EXPENSE' AND COLUMN_NAME = 'USER_EDITED_YN') AS 칸,   -- 0
       (SELECT COUNT(*) FROM EXPENSE) AS 지출_행,                                                                       -- 0)과 같음
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,  -- 42
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS 칸_수,         -- 175
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'EXPENSE') AS EXPENSE_칸                                -- 9
  FROM DUAL;

-- EXPENSE 칸 순서 눈으로 확인 (EXPENSE_ID … LIST_ID 9개)
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, NULLABLE FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'EXPENSE' ORDER BY COLUMN_ID;
