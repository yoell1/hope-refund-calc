-- 95_v2.7에서_v2.8로.sql · 이미 v2.7로 만든 계정(데이터 있음)에 v2.8 변경만 적용 · 새 계정은 01만 실행
-- v2.8: INCOME.CREATED_AT(등록일) 추가 - 다른 테이블처럼 등록일·수정일을 둘 다 둠 (10/22 팀 질문 반영)
-- 기존 행은 등록일을 알 수 없어서 수정일(UPDATED_AT)과 같게 채움

ALTER TABLE INCOME ADD (CREATED_AT DATE DEFAULT SYSDATE NOT NULL);
UPDATE INCOME SET CREATED_AT = UPDATED_AT;
COMMIT;
COMMENT ON COLUMN INCOME.CREATED_AT IS '등록일';

-- 확인: INCOME 칸 13 · 등록일 비어 있는 행 0 · 등록일이 수정일보다 늦은 행 0
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'INCOME') AS INCOME_칸수,
       (SELECT COUNT(*) FROM INCOME WHERE CREATED_AT IS NULL) AS 등록일_없음,
       (SELECT COUNT(*) FROM INCOME WHERE CREATED_AT > UPDATED_AT) AS 등록일_더늦음
  FROM DUAL;
