GRANT EXECUTE ON sys.DBMS_LOCK TO SH; 

set echo on timing off
 
CREATE OR REPLACE FUNCTION SH.FNC_PAUSA(p1 IN NUMBER) RETURN NUMBER AS
BEGIN
  sys.DBMS_LOCK.SLEEP(p1);
  RETURN 1;
END FNC_PAUSA;
/

CREATE OR REPLACE PROCEDURE SH.PRC_TX
IS
   v_SUM         NUMBER;
BEGIN
	SELECT /*SQL##0001.1##DBASOBRINHO*/ 
	       SUM(T1.SAL + T2.SAL)
	  INTO v_SUM
	  FROM  
	     (SELECT SUM(T.SAL) SAL
	        FROM SH.TX T 
           WHERE T.JOB LIKE '%MANAGER%'
	     ) T1,
	     (SELECT SUM(T.SAL) SAL
	        FROM SH.TX T 
           WHERE T.JOB LIKE '%CLERK%'
	     ) T2
		where FNC_Pausa(TRUNC(DBMS_RANDOM.VALUE(0, 16)) ) = 1;		 
    --/
    SELECT /*SQL##0001.2##DBASOBRINHO*/  
          SUM(T.SAL) 
      INTO v_SUM
      FROM SH.TX T
     WHERE T.DEPTNO = 10
	 AND FNC_Pausa(TRUNC(DBMS_RANDOM.VALUE(0, 16)) ) = 1;
    --/
	FOR C1 in(SELECT /*SQL##0001.3##DBASOBRINHO*/  
	                 EMPNO, ENAME, SAL, ROWID RW
			    FROM SH.TX
				WHERE ENAME LIKE 'A%' 
				  AND ROWNUM < 30)
	LOOP
	     update  /*SQL##0001.4##DBASOBRINHO*/  SH.TX
		 set JOB = UPPER(JOB)
		 WHERE ROWID = C1.RW
		 AND  FNC_Pausa(TRUNC(DBMS_RANDOM.VALUE(0, 3)) ) = 1;
		 
    END LOOP;
END PRC_TX;
/
set timing on
