begin execute immediate 'drop table SH.TX'; exception when others then null; end; 
/
create table SH.TX  (EMPNO PRIMARY KEY, ENAME, JOB, MGR, HIREDATE, SAL, COMM, DEPTNO)
as
SELECT level                                                            as EMPNO
      ,trim(DBMS_RANDOM.string ('X', TRUNC (DBMS_RANDOM.value (3,10)))) as ENAME
      ,trim(DBMS_RANDOM.string ('X', TRUNC (DBMS_RANDOM.value (5,9))))  as JOB 
	  ,DBMS_RANDOM.value(1,ROWNUM)                                      as MGR 
	  ,SYSDATE - DBMS_RANDOM.value(0,366)                               as HIREDATE
	  ,round(DBMS_RANDOM.value(1200,50000),2)                           as SAL
	  ,trunc(DBMS_RANDOM.value(1,100))                                  as COMM
	  ,trunc(DBMS_RANDOM.value(1,50))                                   as DEPTNO
FROM   dual
CONNECT BY level <= 300000;

exec DBMS_STATS.GATHER_TABLE_STATS(ownname => 'SH',tabname  => 'TX');
