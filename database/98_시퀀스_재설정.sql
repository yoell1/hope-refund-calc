-- 98_시퀀스_재설정.sql · 시퀀스 16개를 「현재 최대 PK + 1」부터 다시 시작하게 맞춤
-- 언제: 공용 DB에 번호(PK)를 직접 지정해서 데이터를 더 넣은 뒤
--       → 안 맞추면 다음 INSERT(회원가입 등)에서 시퀀스가 이미 있는 번호를 줘서 ORA-00001(무결성 제약 조건 위반) 발생
--       (수릿 세미프로젝트 때 팀 서버 시퀀스를 손으로 최대값 뒤로 밀었던 작업을 한 번에 하는 스크립트)
-- 주의: 시퀀스를 지웠다 다시 만들므로, 실행하는 동안 다른 사람이 INSERT 하면 그 사람은 오류가 남 → 팀원이 안 쓰는 시간에 실행
-- 실행: 프로젝트 계정으로 접속 → 이 파일을 스크립트 실행(F5)
-- 03_데이터적재.sql / 99_load_csv.py 는 적재 직후 같은 작업을 자동으로 하므로, 그 뒤에는 따로 돌릴 필요 없음

DECLARE
  n NUMBER;
  PROCEDURE fix(t VARCHAR2, pk VARCHAR2, s VARCHAR2, c VARCHAR2 DEFAULT 'NOCACHE') IS
  BEGIN
    EXECUTE IMMEDIATE 'SELECT NVL(MAX(' || pk || '), 0) + 1 FROM ' || t INTO n;
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s;
    EXECUTE IMMEDIATE 'CREATE SEQUENCE ' || s || ' START WITH ' || n || ' INCREMENT BY 1 ' || c;
    DBMS_OUTPUT.PUT_LINE(RPAD(s, 25) || ' 다음 번호 ' || n);
  END;
BEGIN
  fix('MEMBER',            'MEMBER_ID',     'SEQ_MEMBER');
  fix('INCOME',            'INCOME_ID',     'SEQ_INCOME');
  fix('CARD_UPLOAD',       'UPLOAD_ID',     'SEQ_CARD_UPLOAD');
  fix('MERCHANT_LIST',     'LIST_ID',       'SEQ_MERCHANT_LIST');
  fix('EXPENSE',           'EXPENSE_ID',    'SEQ_EXPENSE',      'CACHE 20');
  fix('DEDUCTION_TYPE',    'TYPE_ID',       'SEQ_DEDUCTION_TYPE');
  fix('TAX_BRACKET',       'BRACKET_ID',    'SEQ_TAX_BRACKET');
  fix('BENEFIT_CONDITION', 'BENEFIT_ID',    'SEQ_BENEFIT_CONDITION');
  fix('PREDICTION',        'PREDICTION_ID', 'SEQ_PREDICTION');
  fix('PREDICTION_DETAIL', 'DETAIL_ID',     'SEQ_PREDICTION_DETAIL');
  fix('RECOMMENDATION',    'REC_ID',        'SEQ_RECOMMENDATION');
  fix('CHAT_SESSION',      'SESSION_ID',    'SEQ_CHAT_SESSION');
  fix('CHAT_MESSAGE',      'MESSAGE_ID',    'SEQ_CHAT_MESSAGE', 'CACHE 20');
  fix('INQUIRY',           'INQUIRY_ID',    'SEQ_INQUIRY');
  fix('ACCESS_LOG',        'LOG_ID',        'SEQ_ACCESS_LOG',   'CACHE 20');
  fix('PASSWORD_RESET',    'RESET_ID',      'SEQ_PASSWORD_RESET');
END;
/

-- 확인: 모든 행에서 「최대 번호 < 다음 번호」면 정상
SELECT 'MEMBER' T, (SELECT MAX(MEMBER_ID) FROM MEMBER) 최대번호,
       (SELECT LAST_NUMBER FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'SEQ_MEMBER') 다음번호 FROM DUAL
UNION ALL
SELECT 'EXPENSE', (SELECT MAX(EXPENSE_ID) FROM EXPENSE),
       (SELECT LAST_NUMBER FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'SEQ_EXPENSE') FROM DUAL
UNION ALL
SELECT 'MERCHANT_LIST', (SELECT MAX(LIST_ID) FROM MERCHANT_LIST),
       (SELECT LAST_NUMBER FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'SEQ_MERCHANT_LIST') FROM DUAL;
