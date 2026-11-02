-- 90_v3.1¿¡¼­_v3.2·Î.sql ¡¤ ÀÌ¹Ì v3.1·Î ¸¸µç °èÁ¤(±³À°¿ø °ø¿ë DB Æ÷ÇÔ)À» v3.2·Î ¿Ã¸®´Â ½ºÅ©¸³Æ® (10/23)
-- »õ·Î ¸¸µå´Â °èÁ¤Àº ÀÌ ÆÄÀÏ ¾øÀÌ 01 ¡æ 02 ¡æ 03 ¸¸ ½ÇÇàÇÏ¸é v3.2°¡ µÊ
-- Å×ÀÌºí¡¤Ä­¡¤µ¥ÀÌÅÍ´Â ¹Ù²îÁö ¾ÊÀ½ (CHECK 1°³¸¸ ´Ù½Ã ¸¸µê ¡¤ °³¼ö 40 ±×´ë·Î)
--
-- v3.2¿¡¼­ ¹Ù²ï °Í
--   1) ¹®ÀÇ ´äº¯ CHECK CK_INQUIRY_ANSWER
--      ¿¹Àü: ´äº¯ ¿Ï·á(ANSWERED)¸é ´äº¯ÀÏ¸¸ È®ÀÎ ¡æ ´äº¯ ³»¿ë¡¤´äº¯ÀÚ°¡ ºñ¾î ÀÖ¾îµµ ¡¸´äº¯ ¿Ï·á¡¹·Î ÀúÀåµÆÀ½
--      Áö±Ý: ´äº¯ ¿Ï·á¸é ´äº¯ ³»¿ë ¡¤ ´äº¯ÀÏ ¡¤ ´äº¯ÀÚ ¸ðµÎ ÇÊ¼ö / Á¢¼ö(WAITING)¸é ¼Â ´Ù ºñ¾î ÀÖ¾î¾ß ÇÔ
--   2) (ÆÄÀÏ¸¸) 04 ºÐ·ù Äõ¸® ¡¤ 07 Ä«µå ºÐ·ù°¡ »ç¿ë ÁßÀÎ ºÐ·ù(SPEND_CATEGORY.USE_YN = 'Y')ÀÇ ¸ñ·Ï¸¸ ´ëÁ¶
--      ¡æ DB¿¡ ÀúÀåµÈ °ÍÀÌ ¾Æ´Ï¶ó ÀÌ ½ºÅ©¸³Æ®¿¡´Â ¾øÀ½ ¡¤ Áö±Ý ºÐ·ù 5°³ ¸ðµÎ »ç¿ë ÁßÀÌ¶ó °á°ú º¯È­ ¾øÀ½
-- ¸Ç ¾Æ·¡ 3) È®ÀÎ ¡¤ 4) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â(ÀüºÎ ROLLBACK) °á°ú¸¦ º¸¸é µÊ

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ½ÇÇà Àü È®ÀÎ - 0ÀÌ¾î¾ß ÇÔ (0ÀÌ ¾Æ´Ï¸é ¸ØÃß°í ¾Ë·Á ÁÖ¼¼¿ä ¡¤ »õ ±ÔÄ¢¿¡ ¾È ¸Â´Â ¹®ÀÇ ¼ö)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT COUNT(*) AS ±ÔÄ¢¿¡_¾È_¸Â´Â_¹®ÀÇ
  FROM INQUIRY
 WHERE (STATUS = 'ANSWERED' AND (ANSWER IS NULL OR ANSWERED_AT IS NULL OR ANSWERED_BY IS NULL))
    OR (STATUS = 'WAITING'  AND (ANSWER IS NOT NULL OR ANSWERED_AT IS NOT NULL OR ANSWERED_BY IS NOT NULL));

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) ¹®ÀÇ ´äº¯ CHECK ´Ù½Ã ¸¸µé±â
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE INQUIRY DROP CONSTRAINT CK_INQUIRY_ANSWER;
ALTER TABLE INQUIRY ADD CONSTRAINT CK_INQUIRY_ANSWER CHECK (
      (STATUS = 'WAITING'  AND ANSWER IS NULL     AND ANSWERED_AT IS NULL     AND ANSWERED_BY IS NULL)
   OR (STATUS = 'ANSWERED' AND ANSWER IS NOT NULL AND ANSWERED_AT IS NOT NULL AND ANSWERED_BY IS NOT NULL));

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 2) (º¯°æ ¾øÀ½) 04 ¡¤ 07Àº ÆÄÀÏ¸¸ ¹Ù²ñ - »õ ÆÄÀÏÀ» ¾²¸é µÊ
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) È®ÀÎ (¿¹»ó °á°ú´Â ¿À¸¥ÂÊ ÁÖ¼®)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_¼ö,   -- 40
       (SELECT STATUS FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME = 'CK_INQUIRY_ANSWER') AS ´äº¯CHECK_»óÅÂ,                       -- ENABLED
       (SELECT COUNT(*) FROM MEMBER) AS È¸¿ø,                                                                                   -- 1,001 (Å×½ºÆ® µ¥ÀÌÅÍ°¡ ´õ ÀÖÀ¸¸é ±×¸¸Å­)
       (SELECT COUNT(*) FROM INQUIRY) AS ¹®ÀÇ                                                                                   -- ½ÇÇà Àü°ú °°À½
  FROM DUAL;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 4) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â - 5ÁÙ ¸ðµÎ ¡¸OK¡¹°¡ ³ª¿Í¾ß Á¤»ó ¡¤ ¸¶Áö¸·¿¡ ROLLBACKÀÌ¶ó µ¥ÀÌÅÍ´Â ¾È ¹Ù²ñ
--    (º¸±â > DBMS Ãâ·Â Ã¢À» ÄÑ°í ½ÇÇà)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DECLARE
  v_user  NUMBER;   -- ÀÏ¹Ý È¸¿ø
  v_admin NUMBER;   -- °ü¸®ÀÚ
  PROCEDURE chk(p_name VARCHAR2, p_code NUMBER, p_expect NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_code = p_expect THEN 'OK   ' ELSE 'FAIL ' END
                         || p_name || ' (±â´ë ' || CASE WHEN p_expect = 0 THEN '¿À·ù ¾øÀ½' ELSE 'ORA' || TO_CHAR(p_expect) END
                         || ' / ½ÇÁ¦ ' || CASE WHEN p_code = 0 THEN '¿À·ù ¾øÀ½' ELSE 'ORA' || TO_CHAR(p_code) END || ')');
  END;
BEGIN
  SELECT MIN(MEMBER_ID) INTO v_user  FROM MEMBER WHERE ROLE = 'USER';
  SELECT MIN(MEMBER_ID) INTO v_admin FROM MEMBER WHERE ROLE = 'ADMIN';

  -- ¨ç ´äº¯ ¿Ï·áÀÎµ¥ ´äº¯ ³»¿ë ¾øÀ½ ¡æ ORA-02290
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT, STATUS, ANSWER, ANSWERED_AT, ANSWERED_BY)
    VALUES (-1, v_user, 'Å×½ºÆ®', '¹®ÀÇ', 'ANSWERED', NULL, SYSDATE, v_admin);
    chk('¨ç ´äº¯ ¿Ï·á + ´äº¯ ³»¿ë ¾øÀ½', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨ç ´äº¯ ¿Ï·á + ´äº¯ ³»¿ë ¾øÀ½', SQLCODE, -2290); END;

  -- ¨è ´äº¯ ¿Ï·áÀÎµ¥ ´äº¯ÀÚ ¾øÀ½ ¡æ ORA-02290
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT, STATUS, ANSWER, ANSWERED_AT, ANSWERED_BY)
    VALUES (-2, v_user, 'Å×½ºÆ®', '¹®ÀÇ', 'ANSWERED', '´äº¯', SYSDATE, NULL);
    chk('¨è ´äº¯ ¿Ï·á + ´äº¯ÀÚ ¾øÀ½', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨è ´äº¯ ¿Ï·á + ´äº¯ÀÚ ¾øÀ½', SQLCODE, -2290); END;

  -- ¨é Á¢¼ö »óÅÂÀÎµ¥ ´äº¯ ³»¿ëÀÌ ÀÖÀ½ ¡æ ORA-02290
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT, STATUS, ANSWER)
    VALUES (-3, v_user, 'Å×½ºÆ®', '¹®ÀÇ', 'WAITING', '´äº¯');
    chk('¨é Á¢¼ö + ´äº¯ ³»¿ë ÀÖÀ½', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨é Á¢¼ö + ´äº¯ ³»¿ë ÀÖÀ½', SQLCODE, -2290); END;

  -- ¨ê Á¤»ó Á¢¼ö ¡æ ¿À·ù ¾øÀ½
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT)
    VALUES (-4, v_user, 'Å×½ºÆ®', '¹®ÀÇ');
    chk('¨ê Á¤»ó Á¢¼ö', 0, 0);
  EXCEPTION WHEN OTHERS THEN chk('¨ê Á¤»ó Á¢¼ö', SQLCODE, 0); END;

  -- ¨ë Á¤»ó ´äº¯ (¨ê¸¦ ´äº¯ ¿Ï·á·Î) ¡æ ¿À·ù ¾øÀ½
  BEGIN
    UPDATE INQUIRY SET STATUS = 'ANSWERED', ANSWER = '´äº¯', ANSWERED_AT = SYSDATE, ANSWERED_BY = v_admin
     WHERE INQUIRY_ID = -4;
    chk('¨ë Á¤»ó ´äº¯', 0, 0);
  EXCEPTION WHEN OTHERS THEN chk('¨ë Á¤»ó ´äº¯', SQLCODE, 0); END;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('-- Å×½ºÆ® ³¡ ¡¤ ROLLBACK ¿Ï·á (µ¥ÀÌÅÍ º¯°æ ¾øÀ½)');
END;
/
