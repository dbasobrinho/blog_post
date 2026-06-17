set echo on
CREATE TABLE source AS
SELECT 
    LEVEL AS id,
    'Owner_' || LEVEL AS owner,
    'Object_' || LEVEL AS object_name,
    'Type_' || MOD(LEVEL, 5) AS object_type,
    SYSDATE - MOD(LEVEL, 365) AS created
FROM dual
CONNECT BY LEVEL <= 1000000;

CREATE TABLE target AS 
SELECT * FROM source WHERE 1=0;

CREATE SEQUENCE seq_GUINA_TST
    START WITH 1 
    INCREMENT BY 1 
    CACHE 1000;

set echo off;
PROMPT '  '
PROMPT ============================================
prompt TESTE 01, INSERT DIRETO SEM
PROMPT ============================================
truncate TABLE target;
SET TIMING ON; 
set echo on;
INSERT INTO target SELECT id,owner,object_name,object_type,created  FROM source;
SET TIMING off;
COMMIT;
set echo off;

PROMPT '  '
PROMPT ============================================
prompt TESTE 02, INSERT TRADICIONAL VIA PL
PROMPT ============================================
SET SERVEROUTPUT ON;
SET TIMING ON; 
set echo on;
DECLARE
    v_start NUMBER;
    v_end NUMBER;
    v_count NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE target';

    v_start := DBMS_UTILITY.GET_TIME;

    FOR rec IN (SELECT seq_GUINA_TST.NEXTVAL id, owner, object_name, object_type, created FROM source) LOOP
        INSERT INTO target VALUES (rec.id, rec.owner, rec.object_name, rec.object_type, rec.created);
    END LOOP;

    COMMIT;

    v_end := DBMS_UTILITY.GET_TIME;

    SELECT COUNT(*) INTO v_count FROM target;

    DBMS_OUTPUT.PUT_LINE('Tempo total (metodo tradicional): ' || (v_end - v_start) / 100 || ' segundos');
    DBMS_OUTPUT.PUT_LINE('Total de registros inseridos: ' || v_count);
END;
/
set echo off;
SET TIMING off;
PROMPT '  '
PROMPT ============================================
prompt TESTE 03, INSERT BULK COLLECT e FORALL
PROMPT ============================================
SET SERVEROUTPUT ON;
SET TIMING ON; 
set echo on;
DECLARE
    TYPE t_source IS TABLE OF source%ROWTYPE;
    v_data t_source;
    v_start NUMBER;
    v_end NUMBER;
    v_count NUMBER;
    CURSOR c_source IS SELECT seq_GUINA_TST.NEXTVAL ID,owner, object_name,object_type,created FROM source;
    LIMIT_CONSTANT PLS_INTEGER := 10000;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE target';

    v_start := DBMS_UTILITY.GET_TIME;

    OPEN c_source;
    LOOP
        FETCH c_source BULK COLLECT INTO v_data LIMIT LIMIT_CONSTANT;
        EXIT WHEN v_data.COUNT = 0;

        FORALL i IN v_data.FIRST..v_data.LAST
            INSERT INTO target VALUES 
            (v_data(i).id, v_data(i).owner, v_data(i).object_name, v_data(i).object_type, v_data(i).created);

        COMMIT;
    END LOOP;

    CLOSE c_source;

    v_end := DBMS_UTILITY.GET_TIME;

    SELECT COUNT(*) INTO v_count FROM target;

    DBMS_OUTPUT.PUT_LINE('Tempo total (metodo otimizado): ' || (v_end - v_start) / 100 || ' segundos');
    DBMS_OUTPUT.PUT_LINE('Total de registros inseridos: ' || v_count);
END;
/
set echo off;
SET TIMING off;
PROMPT '  '
PROMPT ============================================
prompt APAGANDO OBJETOS DO TESTE 
PROMPT ============================================

BEGIN EXECUTE IMMEDIATE 'DROP TABLE source PURGE'; EXCEPTION WHEN OTHERS THEN NULL; END; 
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE target PURGE'; EXCEPTION WHEN OTHERS THEN NULL; END; 
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_GUINA_TST'; EXCEPTION WHEN OTHERS THEN NULL; END; 
/  
