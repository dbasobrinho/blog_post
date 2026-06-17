

@?/rdbms/admin/tracetab.sql


set lines 300 pages 100 timing off
col OWNER for a16;
col OBJECT_NAME for a30;
col OBJECT_TYPE for a30;
col xxxxxxxxxxx for a70;
SELECT owner, object_name, object_type
  FROM dba_objects
 WHERE object_name like '%PLSQL_TRACE%'
 ORDER by 2, 1;
set echo on
select 'grant ' || privilege || ' on ' || owner || '.' || table_name || ' to '||GRANTEE ||
       decode(grantable, 'YES', ' with admin option') || ';' xxxxxxxxxxx
  from dba_tab_privs
 where table_name in ('PLSQL_TRACE_EVENTS', 'DBMS_TRACE');



create or replace view SYS.vw_plsql_trace_events as
SELECT sou.owner OBJ_owner
      ,sou.name  OBJ_NAME
      ,trc.EVENT_SEQ id
      ,trc.EVENT_TIME DT_TIME
      ,(SUBSTR(sou.text,1,100)) COMMAND_LINE
  FROM plsql_trace_events trc, dba_source sou
 WHERE sou.owner  = sou.owner
   AND sou.name   = sou.name
   AND sou.owner = trc.event_unit_owner
   AND sou.name   = trc.event_unit
   AND sou.line   = trc.event_line
   AND trc.runid  = (select max(runid) from plsql_trace_runs)
   AND trc.event_unit_owner <> 'SYS'
 ORDER BY 1
/


grant select on SYS.PLSQL_TRACE_EVENTS to public;
grant select on SYS.PLSQL_TRACE_RUNS to public;
grant select on SYS.VW_PLSQL_TRACE_EVENTS to public;
create or replace public synonym PLSQL_TRACE_EVENTS for SYS.PLSQL_TRACE_EVENTS;
create or replace public synonym PLSQL_TRACE_RUNS for SYS.PLSQL_TRACE_RUNS;
create or replace public synonym VW_PLSQL_TRACE_EVENTS for SYS.VW_PLSQL_TRACE_EVENTS;
grant EXECUTE on SYS.DBMS_TRACE to PUBLIC;

set echo off;

