-- 91_v3.0¿¡¼­_v3.1·Î.sql ¡¤ ÀÌ¹Ì v3.0À¸·Î ¸¸µç °èÁ¤(±³À°¿ø °ø¿ë DB Æ÷ÇÔ)À» v3.1·Î ¿Ã¸®´Â ½ºÅ©¸³Æ® (10/23)
-- »õ·Î ¸¸µå´Â °èÁ¤Àº ÀÌ ÆÄÀÏ ¾øÀÌ 01 ¡æ 02 ¡æ 03 ¸¸ ½ÇÇàÇÏ¸é v3.1ÀÌ µÊ
-- Å×ÀÌºí¡¤Ä­¡¤µ¥ÀÌÅÍ´Â ¹Ù²îÁö ¾ÊÀ½ (ÀÎµ¦½º 1°³¿Í ÇÔ¼ö 1°³¸¸ ´Ù½Ã ¸¸µê)
--
-- v3.1¿¡¼­ ¹Ù²ï °Í
--   1) ÀÎµ¦½º IX_EXPENSE_UPLOAD (UPLOAD_ID) ¡æ (UPLOAD_ID, MEMBER_ID)
--      v3.0¿¡¼­ ÁöÃâ ¡æ ¾÷·Îµå FK°¡ µÎ Ä­ÀÌ µÆ´Âµ¥ ÀÎµ¦½º´Â ÇÑ Ä­ÀÌ¶ó, OracleÀÌ ¡¸FK¿¡ ÀÎµ¦½º ¾øÀ½¡¹À¸·Î º¸°í
--      ¾÷·Îµå »èÁ¦¡¤È¸¿ø Å»Åð ¶§ EXPENSE Å×ÀÌºí ÀüÃ¼¸¦ Àá±Û ¼ö ÀÖÀ½ ¡æ FK Ä­ µÎ °³¸¦ ¸ðµÎ ¾Õ¿¡ µÐ ÀÎµ¦½º·Î ¹Ù²Þ (°³¼ö´Â 19 ±×´ë·Î)
--   2) °¡¸ÍÁ¡¸í Á¤Á¦ ÇÔ¼ö FN_NORMALIZE_NAME
--      ¡É¡¤¾Æ·¡Ã·ÀÚ ¼ýÀÚ(©ü µî)¡¤ÀÛÀº ·Î¸¶ ¼ýÀÚ ¥¦~¥ª¡¤¿ø ¼ýÀÚ 11~20¡¤©Æ¸¦ ÆÄÀÌ½ã(07, NFKC)°ú °°°Ô ¹Ù²Þ
--      ¿¹Àü ÇÔ¼ö´Â ÀÌ ±ÛÀÚµéÀ» Áö¿ö¼­, ¸ñ·Ï 4Çà(Ä«Æä(cafe)66¡É ¡¤ 37.5¡É Æ®·¹ÀÌ´× ¼¾ÅÍ ¡¤ ¿îµ¿¼¾ÅÍ+1¡É ¡¤ Çï½º&ÈÖÆ®´Ï½º O©üZone)ÀÌ SQL ºÐ·ù·Î´Â ¾È °É·ÈÀ½
--      ¡¤ °°Àº Á¶°ÇÀÌ¸é LIST_ID°¡ ÀÛÀº ¸ñ·ÏÀ» °í¸£µµ·Ï ºÐ·ù Äõ¸®(04)µµ ¸ÂÃã (04 ÆÄÀÏ¸¸ ¹Ù²ñ ¡¤ DB¿¡ ÀúÀåµÈ Äõ¸® ¾Æ´Ô)
--   ¡Ø °¡»ó Ä«µå ³»¿ª 10,453°ÇÀº ÀÌ ±ÛÀÚ°¡ ¾ø¾î¼­ ºÐ·ù °á°ú º¯È­ ¾øÀ½ ¡æ ´Ù½Ã ºÐ·ùÇÏÁö ¾Ê¾Æµµ µÊ
-- ¸Ç ¾Æ·¡ 3) È®ÀÎ °á°ú¸¦ º¸¸é µÊ

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ½ÇÇà Àü È®ÀÎ - Áö±Ý ÀÎµ¦½º Ä­ (UPLOAD_ID ÇÑ ÁÙÀÌ¸é v3.0)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT COLUMN_NAME, COLUMN_POSITION FROM USER_IND_COLUMNS
 WHERE INDEX_NAME = 'IX_EXPENSE_UPLOAD' ORDER BY COLUMN_POSITION;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) ÀÎµ¦½º ´Ù½Ã ¸¸µé±â
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DROP INDEX IX_EXPENSE_UPLOAD;
CREATE INDEX IX_EXPENSE_UPLOAD ON EXPENSE (UPLOAD_ID, MEMBER_ID);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 2) °¡¸ÍÁ¡¸í Á¤Á¦ ÇÔ¼ö ´Ù½Ã ¸¸µé±â (04_ºÐ·ùÄõ¸®.sql 1)°ú °°À½)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
CREATE OR REPLACE FUNCTION FN_NORMALIZE_NAME (p_name IN VARCHAR2)
RETURN VARCHAR2 DETERMINISTIC
IS
  v VARCHAR2(400);
  TYPE t_list IS TABLE OF VARCHAR2(10);
  -- ·Î¸¶ ¼ýÀÚ¡¤¿ø ¹®ÀÚ´Â Python(NFKC)°ú °°°Ô ÀÏ¹Ý ±ÛÀÚ·Î ¹Ù²Þ (¿¹: »ó¿µ°ü¥° ¡æ »ó¿µ°üI)
  -- v3.1: Python(NFKC)°ú °á°ú°¡ °°µµ·Ï ¡É¡¤¾Æ·¡Ã·ÀÚ ¼ýÀÚ¡¤¥¦~¥ª¡¤¿ø ¼ýÀÚ 11~20¡¤©Æ±îÁö Ãß°¡ (¿¹: Ä«Æä(cafe)66¡É ¡æ Ä«ÆäCAFE66C)
  --       cp949¿¡ ¾ø´Â ±ÛÀÚ(¿ø ¼ýÀÚ 16~20, ¾Æ·¡Ã·ÀÚ 0¡¤5~9)´Â UNISTR·Î ÀûÀ½ (SQL Developer cp949 ÆÄÀÏ¿¡¼­µµ ±×´ë·Î ½ÇÇàµÇ°Ô)
  src t_list := t_list('¥°','¥±','¥²','¥³','¥´','¥µ','¥¶','¥·','¥¸','¥¹','¥¡','¥¢','¥£','¥¤','¥¥','¥¦','¥§','¥¨','¥©','¥ª','¨ç','¨è','¨é','¨ê','¨ë','¨ì','¨í','¨î','¨ï','¨ð','¨ñ','¨ò','¨ó','¨ô','¨õ',UNISTR('\246F'),UNISTR('\2470'),UNISTR('\2471'),UNISTR('\2472'),UNISTR('\2473'),'¡É','¢µ',UNISTR('\2080'),'©û','©ü','©ý','©þ',UNISTR('\2085'),UNISTR('\2086'),UNISTR('\2087'),UNISTR('\2088'),UNISTR('\2089'),'©ö','©÷','©ø','©Æ');
  dst t_list := t_list('I','II','III','IV','V','VI','VII','VIII','IX','X','i','ii','iii','iv','v','vi','vii','viii','ix','x','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','C','F','0','1','2','3','4','5','6','7','8','9','1','2','3','(¾Æ)');
BEGIN
  IF p_name IS NULL THEN RETURN NULL; END IF;
  v := TO_SINGLE_BYTE(p_name);
  FOR i IN 1 .. src.COUNT LOOP v := REPLACE(v, src(i), dst(i)); END LOOP;
  v := UPPER(v);
  v := REPLACE(v, '¢ß', '(ÁÖ)');
  v := REGEXP_REPLACE(v, '(ÁÖ½ÄÈ¸»ç|À¯ÇÑÈ¸»ç|À¯ÇÑÃ¥ÀÓÈ¸»ç|»ç´Ü¹ýÀÎ|Àç´Ü¹ýÀÎ|»çÈ¸ÀûÇùµ¿Á¶ÇÕ|Çùµ¿Á¶ÇÕ|\(ÁÖ\)|\(À¯\)|\(»ç\)|\(Àç\)|\(ÇÕ\)|©Å|©Æ|ÁÖ\))', '');
  v := REGEXP_REPLACE(TRIM(v), 'ÇÑ±¹ÁöÁ¡$', '');
  v := REGEXP_REPLACE(v, '[^0-9A-Z°¡-ÆR]', '');
  RETURN v;
END;
/

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) È®ÀÎ
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3-1) ÀÎµ¦½º: UPLOAD_ID 1 ¡¤ MEMBER_ID 2 µÎ ÁÙ
SELECT COLUMN_NAME, COLUMN_POSITION FROM USER_IND_COLUMNS
 WHERE INDEX_NAME = 'IX_EXPENSE_UPLOAD' ORDER BY COLUMN_POSITION;

-- 3-2) °³¼ö: ÀÏ¹Ý ÀÎµ¦½º 19 ¡¤ ÇÔ¼ö VALID
SELECT (SELECT COUNT(*) FROM USER_INDEXES WHERE INDEX_NAME LIKE 'IX\_%' ESCAPE '\') AS ÀÏ¹Ý_ÀÎµ¦½º,   -- 19
       (SELECT STATUS FROM USER_OBJECTS WHERE OBJECT_NAME = 'FN_NORMALIZE_NAME' AND OBJECT_TYPE = 'FUNCTION') AS ÇÔ¼ö_»óÅÂ   -- VALID
  FROM DUAL;

-- 3-3) Á¤Á¦ °á°ú: ÀüºÎ OK¿©¾ß ÇÔ
SELECT T.ÀÔ·Â, FN_NORMALIZE_NAME(T.ÀÔ·Â) AS °á°ú, T.±â´ë,
       CASE WHEN FN_NORMALIZE_NAME(T.ÀÔ·Â) = T.±â´ë THEN 'OK' ELSE 'NG' END AS ÆÇÁ¤
  FROM (SELECT 'Ä«Æä(cafe)66¡É' AS ÀÔ·Â, 'Ä«ÆäCAFE66C' AS ±â´ë FROM DUAL
        UNION ALL SELECT 'Çï½º&ÈÖÆ®´Ï½º O©üZone', 'Çï½ºÈÖÆ®´Ï½ºO2ZONE' FROM DUAL
        UNION ALL SELECT '(ÁÖ)¿µÇ³¹®°í ¸ñÆ÷Á¡', '¿µÇ³¹®°í¸ñÆ÷Á¡' FROM DUAL
        UNION ALL SELECT '£Ã£Ç£Ö »ó¿µ°ü¥°', 'CGV»ó¿µ°üI' FROM DUAL) T;

-- 3-4) ¸ñ·Ï 4Çà: ÇÔ¼ö·Î Á¤Á¦ÇÑ ÀÌ¸§ = ÀúÀåµÈ Á¤Á¦ ÀÌ¸§ ¡æ 4Çà ¸ðµÎ OK
SELECT LIST_ID, MERCHANT_NAME, NORMALIZED_NAME,
       CASE WHEN FN_NORMALIZE_NAME(MERCHANT_NAME) = NORMALIZED_NAME THEN 'OK' ELSE 'NG' END AS ÆÇÁ¤
  FROM MERCHANT_LIST WHERE LIST_ID IN (46720, 54801, 71516, 79893) ORDER BY LIST_ID;

-- 3-5) µ¥ÀÌÅÍ´Â ±×´ë·Î: È¸¿ø 1,001 ¡¤ ÁöÃâ 10,453 (°ø¿ë DB¿¡ Å×½ºÆ® µ¥ÀÌÅÍ°¡ ´õ ÀÖÀ¸¸é ±×¸¸Å­ ¸¹À½)
SELECT (SELECT COUNT(*) FROM MEMBER) AS È¸¿ø, (SELECT COUNT(*) FROM EXPENSE) AS ÁöÃâ FROM DUAL;
