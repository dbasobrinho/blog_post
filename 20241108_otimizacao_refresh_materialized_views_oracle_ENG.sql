--===========================================================================
--## 20241108_optimization_refresh_materialized_views_oracle.sql
--## http://dbasobrinho.com.br
--## https://dbasobrinho.com.br/materialized-views-lentas-otimize-o-refresh-com-atomic_refresh/
--## Author: Not Specified
--## Creation Date: 08/11/2024
--===========================================================================

--## Slow materialized views? Optimize refresh with atomic_refresh

--## For large data volumes, materialized views (MVIEWs) can experience slow full refresh in Oracle.
--## By default, the ATOMIC_REFRESH = TRUE parameter ensures consistency but is slower.
--## Oracle uses DELETE to clear old data, generating undo and redo.
--## A quicker solution? Set ATOMIC_REFRESH = FALSE, which allows the use of TRUNCATE and speeds up the process,
--## though it makes the MVIEW temporarily unavailable.

--===========================================================================

--## Practical example: Comparing atomic_refresh = true and false

--## 1. Creating the sample table
CREATE TABLE tb_test_dba AS
SELECT LEVEL AS id,
       'Product ' || LEVEL AS name,
       TRUNC(DBMS_RANDOM.VALUE(1, 1000), 2) AS price,
       ROUND(DBMS_RANDOM.VALUE(1, 1000)) AS quantity,
       TO_DATE('2023-01-01', 'YYYY-MM-DD') + LEVEL AS sale_date
FROM dual
CONNECT BY LEVEL <= 500000;

--===========================================================================

--## 2. Creating the materialized view MV_TEST_DBA
CREATE MATERIALIZED VIEW mv_test_dba
BUILD IMMEDIATE
REFRESH COMPLETE
ON DEMAND
AS
SELECT id,
       name,
       price,
       quantity,
       sale_date
FROM tb_test_dba;

--===========================================================================

--## 3. Executing the refresh with ATOMIC_REFRESH = TRUE
SET TIMING ON;
BEGIN
   DBMS_MVIEW.REFRESH('mv_test_dba', METHOD => 'C', ATOMIC_REFRESH => TRUE);
END;
/ 

--## The refresh took 3 minutes and 58 seconds for 500,000 rows
--## This mode generates undo and redo, impacting time
--## But keeps the MVIEW accessible during the refresh

--===========================================================================

--## 4. Executing the refresh with ATOMIC_REFRESH = FALSE

--## Repeating the process, now with ATOMIC_REFRESH = FALSE to use TRUNCATE

SET TIMING ON;
BEGIN
   DBMS_MVIEW.REFRESH('mv_test_dba', METHOD => 'C', ATOMIC_REFRESH => FALSE);
END;
/ 

--## The refresh was faster, reducing the time to only 6 seconds
--## Resource consumption drops significantly, but the MVIEW becomes temporarily unavailable
--## In case of failures, the MVIEW will remain empty until the next successful refresh

--===========================================================================

--## Comparison of time and impact
--## ATOMIC_REFRESH    | Execution Time   | Deletion Type | During Refresh
--## ----------------- | ---------------- | ------------- | ---------------
--## TRUE              | ~3m 58s          | DELETE        | Available
--## FALSE             | ~6 seconds       | TRUNCATE      | Unavailable
