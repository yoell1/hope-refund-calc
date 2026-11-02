-- 92_v2.9¿¡¼­_v3.0·Î.sql ¡¤ ÀÌ¹Ì v2.9·Î ¸¸µç °èÁ¤(±³À°¿ø °ø¿ë DB Æ÷ÇÔ)À» v3.0À¸·Î ¿Ã¸®´Â ½ºÅ©¸³Æ® (10/23)
-- »õ·Î ¸¸µå´Â °èÁ¤Àº ÀÌ ÆÄÀÏ ¾øÀÌ 01 ¡æ 02 ¡æ 03 ¸¸ ½ÇÇàÇÏ¸é v3.0ÀÌ µÊ
--
-- v3.0¿¡¼­ ¹Ù²ï °Í
--   1) MEMBER ·Î±×ÀÎ Àá±Ý LOGIN_FAIL_COUNT ¡¤ LOCKED_UNTIL
--   2) MEMBER ¾à°ü¡¤°³ÀÎÁ¤º¸ µ¿ÀÇ ¹öÀü TERMS_VERSION ¡¤ PRIVACY_VERSION (±âÁ¸ È¸¿øÀº '1.0', »õ °¡ÀÔÀº ±âº»°ª ¾øÀ½ ¡æ ¹é¿£µå°¡ ²À ³ÖÀ½)
--   3) EXPENSE ¡æ CARD_UPLOAD FK¸¦ (UPLOAD_ID, MEMBER_ID) µÎ Ä­À¸·Î ¡æ ÁöÃâ È¸¿ø = ¾÷·Îµå È¸¿ø
--   4) MERCHANT_LIST (NORMALIZED_NAME, CATEGORY_ID) Áßº¹ ±ÝÁö ¡¤ ÀÌ¸§ ÀÎµ¦½º´Â ÀÌ°ÍÀ¸·Î ´ëÃ¼
--   5) PREDICTION °á°ú 4Ä­ NOT NULL
--   6) ¼¼¹ý ±âÁØ°ª °Ë»ç 6°³
--   7) EXPENSE ºÐ·ù ÀÎµ¦½º »èÁ¦
-- ¸Ç ¾Æ·¡ 4) È®ÀÎ ¡¤ 5) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â(ÀüºÎ ROLLBACK) °á°ú¸¦ º¸¸é µÊ

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ½ÇÇà Àü È®ÀÎ - µÑ ´Ù 0ÀÌ¾î¾ß ÇÔ (0ÀÌ ¾Æ´Ï¸é ¸ØÃß°í ¾Ë·Á ÁÖ¼¼¿ä)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM PREDICTION
         WHERE TAXABLE_INCOME IS NULL OR CALCULATED_TAX IS NULL OR DECIDED_TAX IS NULL OR EXPECTED_REFUND IS NULL) AS °á°ú_ºó_¿¹Ãø,
       (SELECT COUNT(*) FROM (SELECT NORMALIZED_NAME, CATEGORY_ID FROM MERCHANT_LIST
                               GROUP BY NORMALIZED_NAME, CATEGORY_ID HAVING COUNT(*) > 1)) AS ¸ñ·Ï_Áßº¹,
       (SELECT COUNT(*) FROM EXPENSE E JOIN CARD_UPLOAD U ON U.UPLOAD_ID = E.UPLOAD_ID
         WHERE U.MEMBER_ID <> E.MEMBER_ID) AS ÁöÃâ_È¸¿ø_ºÒÀÏÄ¡
  FROM DUAL;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) MEMBER: ·Î±×ÀÎ Àá±Ý ¡¤ µ¿ÀÇ ¹öÀü (¸Ç µÚ Ä­ 4°³, 01_schema.sql Ä­ ¼ø¼­¿Í °°À½)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE MEMBER ADD (LOGIN_FAIL_COUNT NUMBER(2)    DEFAULT 0 NOT NULL,
                        LOCKED_UNTIL     DATE,
                        TERMS_VERSION    VARCHAR2(10) DEFAULT '1.0' NOT NULL,
                        PRIVACY_VERSION  VARCHAR2(10) DEFAULT '1.0' NOT NULL);
-- ±âÁ¸ È¸¿øÀº '1.0'À¸·Î Ã¤¿öÁ³À¸´Ï ±âº»°ªÀ» ¾ø¾Ú ¡æ »õ °¡ÀÔ¿¡¼­ ¹öÀüÀ» ºü¶ß¸®¸é ¿À·ù(ORA-01400)
ALTER TABLE MEMBER MODIFY (TERMS_VERSION DEFAULT NULL, PRIVACY_VERSION DEFAULT NULL);
ALTER TABLE MEMBER ADD CONSTRAINT CK_MEMBER_LOGIN_FAIL CHECK (LOGIN_FAIL_COUNT >= 0);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 2) ÁöÃâ È¸¿ø = ¾÷·Îµå È¸¿ø (ºÎ¸ð ÂÊ UNIQUE ¸ÕÀú ¡æ FK ´Ù½Ã ¸¸µé±â)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE CARD_UPLOAD ADD CONSTRAINT UQ_CARD_UPLOAD_MEMBER UNIQUE (UPLOAD_ID, MEMBER_ID);
ALTER TABLE EXPENSE DROP CONSTRAINT FK_EXPENSE_UPLOAD;
ALTER TABLE EXPENSE ADD CONSTRAINT FK_EXPENSE_UPLOAD FOREIGN KEY (UPLOAD_ID, MEMBER_ID)
  REFERENCES CARD_UPLOAD (UPLOAD_ID, MEMBER_ID) ON DELETE CASCADE;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) °¡¸ÍÁ¡ ¸ñ·Ï Áßº¹ ±ÝÁö (ÀÌ¸§ ´ëÁ¶ ÀÎµ¦½º ´ëÃ¼)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DROP INDEX IX_MERCHANT_LIST_NAME;
ALTER TABLE MERCHANT_LIST ADD CONSTRAINT UQ_MERCHANT_LIST_NAME UNIQUE (NORMALIZED_NAME, CATEGORY_ID);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 4) ¿¹Ãø °á°ú 4Ä­ NOT NULL
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE PREDICTION MODIFY (TAXABLE_INCOME NOT NULL, CALCULATED_TAX NOT NULL, DECIDED_TAX NOT NULL, EXPECTED_REFUND NOT NULL);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 5) ¼¼¹ý ±âÁØ°ª °Ë»ç 6°³
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE DEDUCTION_TYPE    ADD CONSTRAINT CK_DEDUCTION_RATE    CHECK (RATE BETWEEN 0 AND 100);
ALTER TABLE DEDUCTION_TYPE    ADD CONSTRAINT CK_DEDUCTION_CARD    CHECK (DEDUCTION_KIND <> 'CARD' OR CATEGORY_ID IS NOT NULL);
ALTER TABLE TAX_BRACKET       ADD CONSTRAINT CK_TAX_BRACKET_RATE  CHECK (RATE BETWEEN 0 AND 100);
ALTER TABLE TAX_BRACKET       ADD CONSTRAINT CK_TAX_BRACKET_RANGE CHECK (UPPER_AMOUNT IS NULL OR UPPER_AMOUNT > LOWER_AMOUNT);
ALTER TABLE BENEFIT_CONDITION ADD CONSTRAINT CK_BENEFIT_RATE      CHECK (REDUCTION_RATE BETWEEN 0 AND 100);
ALTER TABLE BENEFIT_CONDITION ADD CONSTRAINT CK_BENEFIT_AGE       CHECK (MIN_AGE IS NULL OR MAX_AGE IS NULL OR MIN_AGE <= MAX_AGE);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 6) ÁöÃâ ºÐ·ù ÀÎµ¦½º »èÁ¦ (ºÐ·ù ÇàÀº Áö¿ìÁö ¾ÊÀ½ ¡¤ °ª 5°³¶ó Á¶È¸¿¡ ¾È ¾²ÀÓ)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DROP INDEX IX_EXPENSE_CATEGORY;

COMMENT ON COLUMN MEMBER.LOGIN_FAIL_COUNT IS '·Î±×ÀÎ ¿¬¼Ó ½ÇÆÐ È½¼ö(5¹øÂ° ½ÇÆÐ ½Ã Àá±Ý ÈÄ 0)';
COMMENT ON COLUMN MEMBER.LOCKED_UNTIL IS '·Î±×ÀÎ Àá±Ý ÇØÁ¦ ½Ã°¢(NULL=Àá±Ý ¾øÀ½)';
COMMENT ON COLUMN MEMBER.TERMS_VERSION IS 'µ¿ÀÇÇÑ ÀÌ¿ë¾à°ü ¹öÀü';
COMMENT ON COLUMN MEMBER.PRIVACY_VERSION IS 'µ¿ÀÇÇÑ °³ÀÎÁ¤º¸ Ã³¸®¹æÄ§ ¹öÀü';

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 7) È®ÀÎ (¿¹»ó °á°ú´Â ¿À¸¥ÂÊ ÁÖ¼®)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_¼ö,   -- 40
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'U') AS UNIQUE_¼ö,                                          -- 10
       (SELECT COUNT(*) FROM USER_INDEXES I WHERE I.INDEX_NAME LIKE 'IX\_%' ESCAPE '\') AS ÀÏ¹Ý_ÀÎµ¦½º,                           -- 19
       (SELECT COUNT(*) FROM USER_CONS_COLUMNS WHERE CONSTRAINT_NAME = 'FK_EXPENSE_UPLOAD') AS ÁöÃâFK_Ä­¼ö,                      -- 2
       (SELECT COUNT(*) FROM MEMBER WHERE TERMS_VERSION = '1.0' AND PRIVACY_VERSION = '1.0' AND LOGIN_FAIL_COUNT = 0) AS È¸¿ø_1Á¡0,  -- 1,001 (ÀüÃ¼ È¸¿ø ¼ö¿Í °°À¸¸é Á¤»ó)
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'MEMBER') AS MEMBER_Ä­¼ö                                        -- 23
  FROM DUAL;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 8) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â - ÀüºÎ ¡¸OK¡¹°¡ ³ª¿Í¾ß Á¤»ó ¡¤ ¸¶Áö¸·¿¡ ROLLBACKÀÌ¶ó µ¥ÀÌÅÍ´Â ¾È ¹Ù²ñ
--    (SQL Developer: º¸±â > DBMS Ãâ·Â Ã¢À» ÄÑ¾ß °á°ú°¡ º¸ÀÓ)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DECLARE
  v_up   NUMBER;   -- ¾÷·Îµå 1¹øÀÇ È¸¿ø
  v_oth  NUMBER;   -- ´Ù¸¥ È¸¿ø
  PROCEDURE chk(p_name VARCHAR2, p_code NUMBER, p_expect NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_code = p_expect THEN 'OK   ' ELSE 'FAIL ' END
                         || p_name || ' (±â´ë ORA' || TO_CHAR(p_expect) || ' / ½ÇÁ¦ ' || CASE WHEN p_code = 0 THEN '¿À·ù ¾øÀ½' ELSE 'ORA' || TO_CHAR(p_code) END || ')');
  END;
BEGIN
  SELECT MEMBER_ID INTO v_up FROM CARD_UPLOAD WHERE UPLOAD_ID = 1;
  SELECT MIN(MEMBER_ID) INTO v_oth FROM MEMBER WHERE MEMBER_ID <> v_up;

  -- ¨ç ´Ù¸¥ È¸¿øÀÇ ¾÷·Îµå¿¡ ÁöÃâ ³Ö±â ¡æ ORA-02291
  BEGIN
    INSERT INTO EXPENSE (EXPENSE_ID, MEMBER_ID, UPLOAD_ID, USED_DATE, MERCHANT_NAME, PAY_METHOD, AMOUNT, CATEGORY_ID)
    VALUES (-1, v_oth, 1, DATE '2026-01-01', 'Å×½ºÆ®', 'CREDIT', 1000, 1);
    chk('¨ç ´Ù¸¥ È¸¿ø ¾÷·Îµå¿¡ ÁöÃâ', 0, -2291);
  EXCEPTION WHEN OTHERS THEN chk('¨ç ´Ù¸¥ È¸¿ø ¾÷·Îµå¿¡ ÁöÃâ', SQLCODE, -2291); END;

  -- ¨ç-2 °°Àº È¸¿øÀÌ¸é Á¤»ó ÀúÀå (¿À·ù ¾øÀ½ÀÌ ¸ÂÀ½)
  BEGIN
    INSERT INTO EXPENSE (EXPENSE_ID, MEMBER_ID, UPLOAD_ID, USED_DATE, MERCHANT_NAME, PAY_METHOD, AMOUNT, CATEGORY_ID)
    VALUES (-2, v_up, 1, DATE '2026-01-01', 'Å×½ºÆ®', 'CREDIT', 1000, 1);
    DBMS_OUTPUT.PUT_LINE('OK   ¨ç-2 °°Àº È¸¿ø ¾÷·Îµå¿¡ ÁöÃâ (¿À·ù ¾øÀ½)');
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL ¨ç-2 °°Àº È¸¿ø ¾÷·Îµå¿¡ ÁöÃâ ORA' || SQLCODE); END;

  -- ¨è °¡¸ÍÁ¡ ¸ñ·Ï °°Àº ÀÌ¸§¡¤°°Àº ºÐ·ù ´Ù½Ã ³Ö±â ¡æ ORA-00001
  BEGIN
    INSERT INTO MERCHANT_LIST (LIST_ID, MERCHANT_NAME, NORMALIZED_NAME, CATEGORY_ID, SOURCE_NAME)
    SELECT -1, MERCHANT_NAME, NORMALIZED_NAME, CATEGORY_ID, SOURCE_NAME FROM MERCHANT_LIST WHERE LIST_ID = 1;
    chk('¨è ¸ñ·Ï Áßº¹', 0, -1);
  EXCEPTION WHEN OTHERS THEN chk('¨è ¸ñ·Ï Áßº¹', SQLCODE, -1); END;

  -- ¨é ¿¹Ãø °á°ú ºó °ªÀ¸·Î ³Ö±â ¡æ ORA-01400
  BEGIN
    INSERT INTO PREDICTION (PREDICTION_ID, MEMBER_ID, TAX_YEAR) VALUES (-1, v_up, 2026);
    chk('¨é ¿¹Ãø °á°ú ºó °ª', 0, -1400);
  EXCEPTION WHEN OTHERS THEN chk('¨é ¿¹Ãø °á°ú ºó °ª', SQLCODE, -1400); END;

  -- ¨ê °øÁ¦À² 150% ¡æ ORA-02290
  BEGIN
    UPDATE DEDUCTION_TYPE SET RATE = 150 WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_CREDIT';
    chk('¨ê °øÁ¦À² 150', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨ê °øÁ¦À² 150', SQLCODE, -2290); END;

  -- ¨ë Ä«µå °øÁ¦ Çà ºÐ·ù ºñ¿ì±â ¡æ ORA-02290
  BEGIN
    UPDATE DEDUCTION_TYPE SET CATEGORY_ID = NULL WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_CREDIT';
    chk('¨ë Ä«µå °øÁ¦ ºÐ·ù ¾øÀ½', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨ë Ä«µå °øÁ¦ ºÐ·ù ¾øÀ½', SQLCODE, -2290); END;

  -- ¨ì ¼¼À² ±¸°£ ³¡ < ½ÃÀÛ ¡æ ORA-02290
  BEGIN
    UPDATE TAX_BRACKET SET UPPER_AMOUNT = 1 WHERE TAX_YEAR = 2026 AND BRACKET_TYPE = 'TAX_RATE' AND LOWER_AMOUNT = 14000000;
    chk('¨ì ±¸°£ ³¡ < ½ÃÀÛ', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨ì ±¸°£ ³¡ < ½ÃÀÛ', SQLCODE, -2290); END;

  -- ¨í ¼¼À² 150% ¡æ ORA-02290
  BEGIN
    UPDATE TAX_BRACKET SET RATE = 150 WHERE TAX_YEAR = 2026 AND BRACKET_TYPE = 'TAX_RATE' AND LOWER_AMOUNT = 0;
    chk('¨í ¼¼À² 150', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨í ¼¼À² 150', SQLCODE, -2290); END;

  -- ¨î Ã»³â ³ªÀÌ ÃÖ¼Ò 40 > ÃÖ´ë 34 ¡æ ORA-02290
  BEGIN
    UPDATE BENEFIT_CONDITION SET MIN_AGE = 40 WHERE TAX_YEAR = 2026 AND BENEFIT_CODE = 'SME_YOUTH';
    chk('¨î ÃÖ¼Ò ³ªÀÌ > ÃÖ´ë ³ªÀÌ', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨î ÃÖ¼Ò ³ªÀÌ > ÃÖ´ë ³ªÀÌ', SQLCODE, -2290); END;

  -- ¨ï °¨¸éÀ² 120% ¡æ ORA-02290
  BEGIN
    UPDATE BENEFIT_CONDITION SET REDUCTION_RATE = 120 WHERE TAX_YEAR = 2026 AND BENEFIT_CODE = 'SME_YOUTH';
    chk('¨ï °¨¸éÀ² 120', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨ï °¨¸éÀ² 120', SQLCODE, -2290); END;

  -- ¨ð ¾à°ü ¹öÀü »©°í °¡ÀÔ ¡æ ORA-01400
  BEGIN
    INSERT INTO MEMBER (MEMBER_ID, LOGIN_ID, EMAIL, PASSWORD, NAME, BIRTH_DATE, TERMS_AGREED_AT, PRIVACY_AGREED_AT, PRIVACY_VERSION)
    VALUES (-1, 'v30test', 'v30test@example.com', '-', 'Å×½ºÆ®', DATE '2000-01-01', SYSDATE, SYSDATE, '1.0');
    chk('¨ð ¾à°ü ¹öÀü ¾øÀÌ °¡ÀÔ', 0, -1400);
  EXCEPTION WHEN OTHERS THEN chk('¨ð ¾à°ü ¹öÀü ¾øÀÌ °¡ÀÔ', SQLCODE, -1400); END;

  -- ¨ñ ·Î±×ÀÎ ½ÇÆÐ È½¼ö -1 ¡æ ORA-02290
  BEGIN
    UPDATE MEMBER SET LOGIN_FAIL_COUNT = -1 WHERE MEMBER_ID = v_up;
    chk('¨ñ ½ÇÆÐ È½¼ö À½¼ö', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨ñ ½ÇÆÐ È½¼ö À½¼ö', SQLCODE, -2290); END;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('-- Å×½ºÆ® ³¡ ¡¤ ROLLBACK ¿Ï·á (µ¥ÀÌÅÍ º¯°æ ¾øÀ½)');
END;
/
