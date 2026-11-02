-- 84_v3.5¿¡¼­_v3.6·Î.sql ¡¤ ÀÌ¹Ì v3.5·Î ¸¸µç °èÁ¤(±³À°¿ø °ø¿ë DB Æ÷ÇÔ)À» v3.6À¸·Î ¿Ã¸®´Â ½ºÅ©¸³Æ® (10/27)
-- »õ·Î ¸¸µå´Â °èÁ¤Àº ÀÌ ÆÄÀÏ ¾øÀÌ 01 ¡æ 02 ¡æ 03 ¸¸ ½ÇÇàÇÏ¸é v3.6ÀÌ µÊ
-- v3.4 °èÁ¤ÀÌ¸é 85(v3.4¡æv3.5)¸¦ ¸ÕÀú ½ÇÇàÇÏ°í ÀÌ°ÍÀ» ½ÇÇà
--
-- v3.6¿¡¼­ ¹Ù²ï °Í - 10/27 ¸àÅä ÇÇµå¹é ¡¸±Þ¿©¿¡ µû¶ó °øÁ¦ ºñÀ²¡¤ÇÑµµ°¡ ´Þ¶óÁö´Âµ¥ ±Þ¿© Á¤º¸¿Í ¿¬°áµÅ ÀÖÁö ¾Ê´Ù ¡æ °ü°è¸¦ Á¤¸³ÇÒ °Í¡¹
--   Áö±Ý±îÁö: ÃÑ±Þ¿© 7Ãµ¸¸ ±âÁØÀ¸·Î ÇàÀ» ³ª´©µÇ ±¸ºÐÀ» TYPE_CODE ÀÌ¸§(_LOW/_HIGH)À¸·Î ÇØ¼­, ¹é¿£µå°¡ ¡¸7Ãµ¸¸ ÀÌÇÏ¸é _LOW¡¹¸¦ ÄÚµå¿¡ ¹Ú¾Æ¾ß ÇßÀ½
--   ¹Ù²Û °Í: DEDUCTION_TYPE¿¡ ±Þ¿© ±¸°£ µÎ Ä­ ¡æ ¹é¿£µå´Â WHERE TYPE_CODE = :code AND :ÃÑ±Þ¿© > SALARY_MIN AND (SALARY_MAX IS NULL OR :ÃÑ±Þ¿© <= SALARY_MAX)
--   1) SALARY_MIN NUMBER(12) DEFAULT 0 NOT NULL  ±¸°£ ½ÃÀÛ(ÃÊ°ú) ¡¤ ¸Ç µÚ Ä­
--   2) SALARY_LIMIT ¡æ SALARY_MAX ÀÌ¸§ º¯°æ        ±¸°£ ³¡(ÀÌÇÏ ¡¤ NULL = »óÇÑ ¾øÀ½) ¡¤ ¶æÀº ±×´ë·Î
--   3) CHECK CK_DEDUCTION_SALARY                   SALARY_MAX IS NULL OR SALARY_MAX > SALARY_MIN
--   4) UNIQUE (TAX_YEAR, TYPE_CODE) ¡æ (TAX_YEAR, TYPE_CODE, SALARY_MIN)   °°Àº ÄÚµå°¡ ±¸°£º°·Î ¿©·¯ Çà
--   5) µ¥ÀÌÅÍ: _LOW/_HIGH ·Î ³ª´µ¾î ÀÖ´ø 12ÇàÀ» ÄÚµå 6°³·Î ÅëÇÕ (Çà ¼ö´Â 22 ±×´ë·Î)
--        CARD_LIMIT_BASE_LOW/HIGH ¡æ CARD_LIMIT_BASE (0~7Ãµ¸¸ 300¸¸ ¡¤ 7Ãµ¸¸~ 250¸¸)
--        CARD_LIMIT_EXTRA_LOW/HIGH ¡æ CARD_LIMIT_EXTRA (0~7Ãµ¸¸ 300¸¸ ¡¤ 7Ãµ¸¸~ 200¸¸)
--        CARD_LIMIT_CHILD1_LOW/HIGH ¡æ CARD_LIMIT_CHILD1 (350¸¸ ¡¤ 275¸¸) ¡¤ CHILD2 (400¸¸ ¡¤ 300¸¸)
--        PENSION_HIGH/PENSION ¡æ PENSION (0~5,500¸¸ 15% ¡¤ 5,500¸¸~ 12%)
--        RENT_HIGH/RENT ¡æ RENT (0~5,500¸¸ 17% ¡¤ 5,500¸¸~8Ãµ¸¸ 15%)
--   ±¸°£ °æ°è(7Ãµ¸¸¡¤5,500¸¸¡¤8Ãµ¸¸)µµ ÀÌÁ¦ ÇàÀÇ ¼ýÀÚ ¡æ °ü¸®ÀÚ È­¸é¿¡¼­ ÇÑ Çà ¼öÁ¤ ¡¤ ±¸°£ Ãß°¡´Â Çà INSERT ¡¤ ÄÚµå º¯°æ ¾øÀ½
-- DB ±¸Á¶ º¯°æ ÀÖÀ½ (ERD v3.6) ¡¤ Å×ÀÌºí 18 ¡¤ Ä­ 175 ¡æ 176 ¡¤ CHECK 42 ¡æ 43 ¡¤ ÀÎµ¦½º 23 ¡¤ UNIQUE 10 ¡¤ ±âÁØ°ª 22Çà ±×´ë·Î
-- ERDCloud´Â ³ªÁß¿¡ ¹Ý¿µ (10/27 °áÁ¤) ¡¤ ¸Ç ¾Æ·¡ 4) È®ÀÎ ¡¤ 5) Æ²¸° °ª Å×½ºÆ®(ROLLBACK) °á°ú¸¦ º¸¸é µÊ

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ½ÇÇà Àü È®ÀÎ - »õÄ­ 0 ¡¤ ¿¾Ä­ 1 ¡¤ LOW/HIGH Çà 10 ¡¤ CHECK 42 ÀÌ¾î¾ß ÇÔ (´Ù¸£¸é ¸ØÃß°í ¾Ë·Á ÁÖ¼¼¿ä)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DEDUCTION_TYPE' AND COLUMN_NAME = 'SALARY_MIN')   AS »õÄ­,      -- 0
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'DEDUCTION_TYPE' AND COLUMN_NAME = 'SALARY_LIMIT') AS ¿¾Ä­,      -- 1
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE LIKE '%\_LOW' ESCAPE '\' OR TYPE_CODE LIKE '%\_HIGH' ESCAPE '\') AS LOW_HIGHÇà,  -- 10
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_¼ö   -- 42
  FROM DUAL;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) ±¸Á¶: Ä­ Ãß°¡ ¡¤ ÀÌ¸§ º¯°æ ¡¤ CHECK ¡¤ UNIQUE
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE DEDUCTION_TYPE ADD (SALARY_MIN NUMBER(12) DEFAULT 0 NOT NULL);          -- ±âÁ¸ 22ÇàÀº 0À¸·Î Ã¤¿öÁü
ALTER TABLE DEDUCTION_TYPE RENAME COLUMN SALARY_LIMIT TO SALARY_MAX;
ALTER TABLE DEDUCTION_TYPE ADD CONSTRAINT CK_DEDUCTION_SALARY CHECK (SALARY_MAX IS NULL OR SALARY_MAX > SALARY_MIN);
ALTER TABLE DEDUCTION_TYPE DROP CONSTRAINT UQ_DEDUCTION_YEAR_CODE;
ALTER TABLE DEDUCTION_TYPE ADD CONSTRAINT UQ_DEDUCTION_YEAR_CODE UNIQUE (TAX_YEAR, TYPE_CODE, SALARY_MIN);
COMMENT ON COLUMN DEDUCTION_TYPE.SALARY_MIN IS 'Àû¿ë ÃÑ±Þ¿© ±¸°£ ½ÃÀÛ(ÃÊ°ú ¡¤ 0 = Ã³À½ºÎÅÍ) ¡¤ v3.6';
COMMENT ON COLUMN DEDUCTION_TYPE.SALARY_MAX IS 'Àû¿ë ÃÑ±Þ¿© ±¸°£ ³¡(ÀÌÇÏ ¡¤ NULL = »óÇÑ ¾øÀ½) ¡¤ v3.6 SALARY_LIMIT¿¡¼­ ÀÌ¸§¸¸ ¹Ù²ñ';
COMMENT ON COLUMN DEDUCTION_TYPE.TYPE_CODE  IS '°è»ê ÄÚµå ¡¤ °°Àº ÄÚµå°¡ ÃÑ±Þ¿© ±¸°£º°·Î ¿©·¯ Çà(TAX_YEAR + TYPE_CODE + ÃÑ±Þ¿© ±¸°£À¸·Î Ã£±â) ¡¤ v3.6';

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 2) µ¥ÀÌÅÍ: _HIGH ÇàÀº ±¸°£ ½ÃÀÛÀ» ³Ö°í, ÄÚµå¸¦ ÅëÇÕ (TYPE_ID ¡¤ °ª ¡¤ ±Ù°Å´Â ±×´ë·Î)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_BASE',   TYPE_NAME = 'Ä«µå ±âº»ÇÑµµ(7Ãµ¸¸ ÃÊ°ú)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_BASE_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_BASE',   TYPE_NAME = 'Ä«µå ±âº»ÇÑµµ(7Ãµ¸¸ ÀÌÇÏ)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_BASE_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_EXTRA',  TYPE_NAME = 'Ä«µå Ãß°¡ÇÑµµ(7Ãµ¸¸ ÃÊ°ú)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_EXTRA_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_EXTRA',  TYPE_NAME = 'Ä«µå Ãß°¡ÇÑµµ(7Ãµ¸¸ ÀÌÇÏ)'        WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_EXTRA_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_CHILD1', TYPE_NAME = 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à1¡¤7Ãµ¸¸ ÃÊ°ú)'  WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD1_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_CHILD1', TYPE_NAME = 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à1¡¤7Ãµ¸¸ ÀÌÇÏ)'  WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD1_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 70000000, TYPE_CODE = 'CARD_LIMIT_CHILD2', TYPE_NAME = 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à2+¡¤7Ãµ¸¸ ÃÊ°ú)' WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD2_HIGH';
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'CARD_LIMIT_CHILD2', TYPE_NAME = 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à2+¡¤7Ãµ¸¸ ÀÌÇÏ)' WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'CARD_LIMIT_CHILD2_LOW';
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 55000000,                                  TYPE_NAME = '¿¬±Ý°èÁÂ(5,500¸¸ ÃÊ°ú)'           WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'PENSION';       -- 12% Çà
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'PENSION',           TYPE_NAME = '¿¬±Ý°èÁÂ(5,500¸¸ ÀÌÇÏ)'           WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'PENSION_HIGH';  -- 15% Çà
UPDATE DEDUCTION_TYPE SET SALARY_MIN = 55000000,                                  TYPE_NAME = '¿ù¼¼(5,500¸¸ ÃÊ°ú~8Ãµ¸¸)'         WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'RENT';          -- 15% Çà
UPDATE DEDUCTION_TYPE SET                       TYPE_CODE = 'RENT',              TYPE_NAME = '¿ù¼¼(5,500¸¸ ÀÌÇÏ)'               WHERE TAX_YEAR = 2026 AND TYPE_CODE = 'RENT_HIGH';     -- 17% Çà
COMMIT;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) È®ÀÎ - Ä­ 176 ¡¤ CHECK 43 ¡¤ UNIQUE 10 ¡¤ ±âÁØ°ª 22 ¡¤ LOW/HIGH Çà 0 ¡¤ ±¸°£ Çà(SALARY_MIN > 0) 6
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS Ä­_¼ö,                    -- 176
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_¼ö,  -- 43
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'U') AS UNIQUE_¼ö,                                              -- 10
       (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS ±âÁØ°ª_Çà,                                                                            -- 22
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE LIKE '%\_LOW' ESCAPE '\' OR TYPE_CODE LIKE '%\_HIGH' ESCAPE '\') AS LOW_HIGHÇà,  -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE SALARY_MIN > 0) AS ±¸°£Çà                                                           -- 6
  FROM DUAL;

-- ±¸°£ÀÌ ÀÖ´Â ÄÚµå¸¸ º¸±â (ÄÚµå¸¶´Ù ±¸°£ÀÌ ÀÌ¾îÁö´ÂÁö ´«À¸·Î È®ÀÎ)
SELECT TYPE_CODE, SALARY_MIN, SALARY_MAX, RATE, LIMIT_AMOUNT, TYPE_NAME
  FROM DEDUCTION_TYPE
 WHERE TAX_YEAR = 2026 AND TYPE_CODE IN (SELECT TYPE_CODE FROM DEDUCTION_TYPE GROUP BY TAX_YEAR, TYPE_CODE HAVING COUNT(*) > 1)
 ORDER BY TYPE_CODE, SALARY_MIN;

-- ¹é¿£µå°¡ ¾µ Á¶È¸ ¿¹ (ÃÑ±Þ¿© 6,000¸¸ ¡¤ ÀÚ³à 0 ¡æ ±âº»ÇÑµµ 300¸¸ ¡¤ ¿ù¼¼ 15% ¡¤ ¿¬±Ý 12%)
SELECT TYPE_CODE, RATE, LIMIT_AMOUNT
  FROM DEDUCTION_TYPE
 WHERE TAX_YEAR = 2026 AND TYPE_CODE IN ('CARD_LIMIT_BASE', 'RENT', 'PENSION')
   AND 60000000 > SALARY_MIN AND (SALARY_MAX IS NULL OR 60000000 <= SALARY_MAX)
 ORDER BY TYPE_CODE;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 4) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â - ÀüºÎ ¸·Çô¾ß Á¤»ó (ROLLBACK)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DECLARE
  PROCEDURE t(p_name VARCHAR2, p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE(p_name || ': ½ÇÆÐ - ¸·È÷Áö ¾ÊÀ½');
    ROLLBACK;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(p_name || ': OK (' || SUBSTR(SQLERRM, 1, 40) || ')');
    ROLLBACK;
  END;
BEGIN
  t('°°Àº ÄÚµå¡¤°°Àº ±¸°£ ½ÃÀÛ Áßº¹',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''CARD_LIMIT_BASE'', ''Áßº¹'', ''CARD_RULE'', 0, 0)');
  t('±¸°£ ³¡ <= ½ÃÀÛ',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN, SALARY_MAX) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''TEST_X'', ''¿ªÀü'', ''CARD_RULE'', 0, 70000000, 70000000)');
  t('±¸°£ ½ÃÀÛ NULL',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''TEST_Y'', ''³Î'', ''CARD_RULE'', 0, NULL)');
END;
/
