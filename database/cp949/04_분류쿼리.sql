-- 04_ºÐ·ùÄõ¸®.sql ¡¤ Ä«µå ³»¿ª ¡æ °øÁ¦ ¶óº§ ÀÚµ¿ ºÐ·ù (°ø°ø ¸ñ·Ï »óÈ£¸í ´ëÁ¶ ¡¤ 10/20 È®Á¤ ¹æ½Ä)
-- »ç¿ë: Ä«µå ³»¿ª ÆÄÀÏÀ» EXPENSE¿¡ ³ÖÀº µÚ(¾÷·Îµå 1°Ç = UPLOAD_ID 1°³) ¾Æ·¡ 3)À» ½ÇÇà
-- ¿ì¼±¼øÀ§: °øÁ¦ ´ë»ó ¾Æ´Ô(5) ¡æ ´ëÁß±³Åë(2) ¡æ ÀüÅë½ÃÀå(3) ¡æ ¹®È­Ã¼À°(4) ¡æ ¾îµð¿¡µµ ¾øÀ¸¸é ÀÏ¹Ý(1)
-- 10/21 Ãß°¡: 0) ¾÷·Îµå Àü Áßº¹ È®ÀÎ (DB ±¸Á¶ º¯°æ ¾øÀ½ ¡¤ v2.7 ±×´ë·Î)
-- v3.2 (10/23): »ç¿ë ÁßÀÎ ºÐ·ù(SPEND_CATEGORY.USE_YN = 'Y')ÀÇ ¸ñ·Ï¸¸ ´ëÁ¶ (ÆÄÀÏ¸¸ ¹Ù²ñ ¡¤ DB º¯°æ ¾øÀ½)
-- v3.1 (10/23): Á¤Á¦ ÇÔ¼ö°¡ ¡É¡¤©ü °°Àº ±âÈ£¸¦ ÆÄÀÌ½ã(07)°ú °°°Ô ¹Ù²Þ ¡¤ °°Àº Á¶°ÇÀÌ¸é LIST_ID ÀÛÀº °Í ¼±ÅÃ

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ¾÷·Îµå Àü Áßº¹ È®ÀÎ - ÆÄÀÏÀ» EXPENSE¿¡ ³Ö±â ¡¸Àü¡¹¿¡ ½ÇÇà
--    °°Àº ÆÄÀÏ¡¤°ãÄ¡´Â ±â°£À» ´Ù½Ã ¿Ã¸®¸é Ä«µå »ç¿ë¾×ÀÌ µÎ ¹ø Áý°èµÅ È¯±Þ¾×ÀÌ ºÎÇ®·ÁÁü
--    ¡æ ¸·Áö´Â ¾Ê°í(°°Àº ³¯ °°Àº °¡°Ô °°Àº ±Ý¾× °áÁ¦´Â Á¤»óÀÏ ¼ö ÀÖÀ½) °ãÄ¡´Â °Ç¼ö¸¦ È­¸é¿¡ °æ°í
--    Èå¸§: ÆÄÀÏ ÀÐ±â ¡æ ÆÄÀÏÀÇ °¡Àå ÀÌ¸¥/´ÊÀº »ç¿ëÀÏ·Î ¾Æ·¡ Á¶È¸ ¡æ ¹é¿£µå¿¡¼­ °ãÄ£ °Ç¼ö °è»ê
--          ¡æ 0°ÇÀÌ¸é ÀúÀå / 1°Ç ÀÌ»óÀÌ¸é °æ°í ¡æ »ç¿ëÀÚ°¡ ¡¸±×·¡µµ ¿Ã¸®±â¡¹ ´©¸£¸é ÀúÀå
--    °ãÄ£ °Ç¼ö = (»ç¿ëÀÏ¡¤°¡¸ÍÁ¡¸í¡¤±Ý¾×¡¤°áÁ¦¼ö´Ü)ÀÌ °°Àº °áÁ¦³¢¸® min(±âÁ¸ °Ç¼ö, »õ ÆÄÀÏ °Ç¼ö)ÀÇ ÇÕ
--    ÀÎµ¦½º IX_EXPENSE_MEMBER_DATE (MEMBER_ID, USED_DATE) »ç¿ë
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- SELECT USED_DATE, MERCHANT_NAME, AMOUNT, PAY_METHOD, COUNT(*) AS CNT
--   FROM EXPENSE
--  WHERE MEMBER_ID = :member_id
--    AND USED_DATE BETWEEN :min_date AND :max_date
--  GROUP BY USED_DATE, MERCHANT_NAME, AMOUNT, PAY_METHOD;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) °¡¸ÍÁ¡¸í Á¤Á¦ ÇÔ¼ö - MERCHANT_LIST.NORMALIZED_NAMEÀ» ¸¸µç ±ÔÄ¢°ú °°À½
--    (Àü°¢¡æ¹Ý°¢, ´ë¹®ÀÚ, ¹ýÀÎ Ç¥±â Á¦°Å, ³¡ÀÇ ¡¸ÇÑ±¹ÁöÁ¡¡¹ Á¦°Å, ÇÑ±Û¡¤¿µ¹®¡¤¼ýÀÚ¸¸ ³²±è)
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
-- 2) È®ÀÎ¿ë: °¡¸ÍÁ¡¸í ÇÏ³ª°¡ ¾î¶² ¶óº§·Î °¡´ÂÁö º¸±â
--    ¿¹) SELECT * FROM TABLE(...) ´ë½Å ¾Æ·¡ Äõ¸®ÀÇ :name ¿¡ °ª ³Ö°í ½ÇÇà
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- SELECT m.LIST_ID, m.MERCHANT_NAME, m.MATCH_TYPE, c.CATEGORY_NAME
--   FROM MERCHANT_LIST m JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = m.CATEGORY_ID
--  WHERE m.USE_YN = 'Y'
--    AND (   (m.MATCH_TYPE = 'EXACT'    AND m.NORMALIZED_NAME = FN_NORMALIZE_NAME(:name))
--         OR (m.MATCH_TYPE = 'CONTAINS' AND INSTR(FN_NORMALIZE_NAME(:name), m.NORMALIZED_NAME) > 0))
--  ORDER BY DECODE(m.CATEGORY_ID, 5, 1, 2, 2, 3, 3, 4, 4, 9), DECODE(m.MATCH_TYPE, 'EXACT', 1, 2);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) ¾÷·Îµå 1°Ç ºÐ·ù (v3.7: »ç¿ëÀÚ°¡ ºÐ·ù¸¦ Á÷Á¢ °íÄ¡Áö ¾ÊÀ¸¹Ç·Î ¾÷·ÎµåÀÇ ¸ðµç ÇàÀ» ºÐ·ù)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3-1) ¸ÕÀú ÀüºÎ ÀÏ¹ÝÀ¸·Î ÃÊ±âÈ­
UPDATE EXPENSE
   SET CATEGORY_ID = 1, LIST_ID = NULL
 WHERE UPLOAD_ID = :upload_id;

-- 3-2) ¸ñ·Ï¿¡ °É¸®´Â Çà¸¸ ¿ì¼±¼øÀ§°¡ °¡Àå ³ôÀº ¶óº§·Î ¹Ù²Þ
MERGE INTO EXPENSE e
USING (
  -- x: ¾÷·Îµå 1°ÇÀÇ °¡¸ÍÁ¡¸íÀ» ¸ÕÀú ÇÑ ¹ø¸¸ Á¤Á¦ (MATERIALIZE ¾øÀ¸¸é ¸ñ·Ï 8¸¸ °Ç¸¶´Ù ÇÔ¼ö°¡ ´Ù½Ã µ¹¾Æ ¸Å¿ì ´À¸²)
  WITH x AS (SELECT /*+ MATERIALIZE */ EXPENSE_ID, FN_NORMALIZE_NAME(MERCHANT_NAME) AS NNAME
               FROM EXPENSE WHERE UPLOAD_ID = :upload_id),
       -- h: EXACT(ÀÎµ¦½º·Î °°Àº ÀÌ¸§) + CONTAINS(¾à 700°³, Æ÷ÇÔ ¿©ºÎ) ÈÄº¸ ÀüºÎ
       h AS (SELECT x.EXPENSE_ID, m.LIST_ID, m.CATEGORY_ID, m.MATCH_TYPE, m.NORMALIZED_NAME
               FROM x JOIN MERCHANT_LIST m ON m.NORMALIZED_NAME = x.NNAME AND m.MATCH_TYPE = 'EXACT' AND m.USE_YN = 'Y'
                    JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = m.CATEGORY_ID AND c.USE_YN = 'Y'   -- v3.2: »ç¿ë ÁßÀÎ ºÐ·ù¸¸
             UNION ALL
             SELECT x.EXPENSE_ID, m.LIST_ID, m.CATEGORY_ID, m.MATCH_TYPE, m.NORMALIZED_NAME
               FROM x JOIN MERCHANT_LIST m ON m.MATCH_TYPE = 'CONTAINS' AND m.USE_YN = 'Y' AND INSTR(x.NNAME, m.NORMALIZED_NAME) > 0
                    JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = m.CATEGORY_ID AND c.USE_YN = 'Y')
  SELECT EXPENSE_ID, LIST_ID, CATEGORY_ID FROM (
    SELECT h.*, ROW_NUMBER() OVER (PARTITION BY EXPENSE_ID
             ORDER BY DECODE(CATEGORY_ID, 5, 1, 2, 2, 3, 3, 4, 4, 9),   -- È®Á¤ ¿ì¼±¼øÀ§
                      DECODE(MATCH_TYPE, 'EXACT', 1, 2),                 -- °°Àº ¶óº§ÀÌ¸é Á¤È®È÷ ÀÏÄ¡ ¸ÕÀú
                      LENGTH(NORMALIZED_NAME) DESC,                      -- ±×´ÙÀ½ ´õ ±ä ÀÌ¸§ ¸ÕÀú
                      LIST_ID) AS RN                                     -- v3.1: ±×·¡µµ °°À¸¸é ¹øÈ£°¡ ÀÛÀº ¸ñ·Ï (07 ÆÄÀÌ½ã°ú °°°Ô)
      FROM h)
  WHERE RN = 1
) r
ON (e.EXPENSE_ID = r.EXPENSE_ID)
WHEN MATCHED THEN UPDATE SET e.CATEGORY_ID = r.CATEGORY_ID, e.LIST_ID = r.LIST_ID;

COMMIT;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 4) °á°ú È®ÀÎ: ¾÷·Îµå 1°ÇÀÇ ¶óº§º° °Ç¼ö¡¤±Ý¾×
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- SELECT c.CATEGORY_NAME, e.PAY_METHOD, COUNT(*) AS CNT, SUM(e.AMOUNT) AS AMT
--   FROM EXPENSE e JOIN SPEND_CATEGORY c ON c.CATEGORY_ID = e.CATEGORY_ID
--  WHERE e.UPLOAD_ID = :upload_id
--  GROUP BY c.CATEGORY_NAME, e.PAY_METHOD
--  ORDER BY 1, 2;
