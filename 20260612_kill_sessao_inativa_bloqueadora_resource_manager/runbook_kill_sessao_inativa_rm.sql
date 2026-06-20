-- ============================================================================
-- RUNBOOK : Encerrar sessao INACTIVE que segura row lock (enq: TX) usando o
--           Oracle Database Resource Manager (diretiva MAX_IDLE_BLOCKER_TIME)
-- ============================================================================
--
-- Objetivo : Fazer o proprio banco encerrar, de forma automatica e nativa, a
--            sessao INACTIVE que esta segurando um row lock e travando outras
--            sessoes, sem depender de loop de shell matando sessao por fora.
--
-- Escopo   : Oracle Database 19c multitenant. O procedimento roda DENTRO do PDB
--            (Pluggable Database) de aplicacao. Em RAC (Real Application
--            Clusters) o plano e aplicado em todas as instancias do cluster.
--
-- Ambiente : PDB de aplicacao ....   : APPPDB
--            Schema de aplicacao ..  : APP_SCHEMA
--            Programa cliente .....  : AppServer.exe
--            Usuario de SO cliente   : root
--            Plano de RM ........... : RPLAN_JM
--            Consumer group ........ : GROUP_JM_KILL_INACTIVE_BLOCK
--
-- Autor    : DBA Sobrinho
-- Versao   : 1.0
--
-- Pre-requisitos:
--   1. Conectar no PDB de aplicacao (NUNCA no CDB$ROOT, a raiz do Container
--      Database, CDB) com um usuario que
--      tenha o privilegio ADMINISTER_RESOURCE_MANAGER (ou a role DBA) e acesso
--      aos pacotes DBMS_RESOURCE_MANAGER e DBMS_RESOURCE_MANAGER_PRIVS.
--   2. Rodar primeiro em uma janela de teste controlada (ver PASSO 11).
--
-- Como funciona (resumo):
--   A diretiva MAX_IDLE_BLOCKER_TIME diz ao Resource Manager para encerrar uma
--   sessao que esteja OCIOSA (INACTIVE) alem do limite E que esteja bloqueando
--   outra sessao. O PMON (Process Monitor) verifica esses limites uma vez por
--   minuto, entao o encerramento nao e instantaneo: acontece na proxima passada
--   depois de a sessao cruzar o limite.
--
-- AVISOS:
--   * MAX_IDLE_BLOCKER_TIME so encerra sessao INACTIVE que esteja bloqueando
--     alguem. Para encerrar sessao ociosa que NAO bloqueia ninguem existe o
--     MAX_IDLE_TIME (sem "BLOCKER"); aqui deixamos esse em NULL de proposito.
--   * O encerramento faz rollback da transacao da sessao alvo. Garanta que a
--     aplicacao trata reconexao e retry de forma limpa.
--   * As secoes marcadas como "Saida esperada (exemplo)" sao ilustrativas, nao
--     sao capturas reais. Rode no seu ambiente e confira os valores.
--
-- Roteiro:
--   PASSO 0  Diagnostico
--   PASSO 1  Abrir a pending area do plano
--   PASSO 2  Criar o plano
--   PASSO 3  Criar o consumer group
--   PASSO 4  Criar as diretivas
--   PASSO 5  Validar e submeter o plano
--   PASSO 6  Conceder o switch ao schema
--   PASSO 7  Mapear as sessoes ao grupo (Opcao A: mapping)
--   PASSO 8  Alternativa de mapeamento (Opcao B: trigger de logon)
--   PASSO 9  Ativar o plano
--   PASSO 10 Validar a configuracao
--   PASSO 11 Teste controlado
--   PASSO 12 Monitoramento
--   PASSO 13 Ajuste fino do limite
--   ROLLBACK Reverter tudo
--   REFERENCIAS
--
-- ============================================================================


-- ============================================================================
-- PASSO 0 : Diagnostico (antes de mexer em qualquer coisa)
-- ============================================================================

-- 0.1 Confirme o container. Em multitenant, se aparecer CDB$ROOT, pare e
--     reconecte no PDB de aplicacao: o plano precisa ser criado no PDB certo.
SHOW CON_NAME

-- Saida esperada (exemplo):
-- CON_NAME
-- ------------------------------
-- APPPDB

-- 0.2 Anote o plano de Resource Manager ativo agora. O ROLLBACK precisa
--     restaurar exatamente este valor no final.
SELECT name, is_top_plan FROM v$rsrc_plan WHERE is_top_plan = 'TRUE';
SHOW PARAMETER resource_manager_plan

-- 0.3 Identifique o bloqueador e os esperadores. A linha do bloqueador vem com
--     BLOCKING_SESSION nulo, STATUS INACTIVE e LAST_CALL_ET (idle) alto. As
--     linhas dos esperadores vem com STATUS ACTIVE e EVENT igual a
--     "enq: TX - row lock contention".
SELECT s.inst_id, s.sid, s.serial#, s.status, s.osuser, s.program,
       s.blocking_session, s.event, s.last_call_et AS idle_secs
FROM   gv$session s
WHERE  s.username = 'APP_SCHEMA'
AND    (s.blocking_session IS NOT NULL
        OR s.sid IN (SELECT blocking_session
                     FROM   gv$session
                     WHERE  blocking_session IS NOT NULL))
ORDER  BY s.blocking_session NULLS FIRST, s.sid;

-- 0.4 Capture as strings EXATAS de PROGRAM e OSUSER. O mapeamento compara a
--     string exata e e case sensitive: 'AppServer.exe' difere de 'APPSERVER.EXE'.
SELECT inst_id, username, osuser, program, machine, status, COUNT(*) AS qtd
FROM   gv$session
WHERE  username = 'APP_SCHEMA'
GROUP  BY inst_id, username, osuser, program, machine, status
ORDER  BY status, program;


-- ============================================================================
-- PASSO 1 : Abrir a pending area do plano
-- ============================================================================
-- Toda alteracao de plano, consumer group e diretiva acontece dentro de uma
-- pending area. O clear_pending_area descarta qualquer pendencia orfa de uma
-- tentativa anterior; o create_pending_area abre a area limpa.
BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area;
  DBMS_RESOURCE_MANAGER.create_pending_area;
END;
/


-- ============================================================================
-- PASSO 2 : Criar o plano
-- ============================================================================
BEGIN
  DBMS_RESOURCE_MANAGER.create_plan(
    plan    => 'RPLAN_JM',
    comment => 'Encerra holders de lock TX ociosos');
END;
/


-- ============================================================================
-- PASSO 3 : Criar o consumer group
-- ============================================================================
-- Este e o grupo onde caem as sessoes candidatas a encerramento por bloqueio
-- ocioso. As sessoes entram nele pelo mapeamento do PASSO 7.
BEGIN
  DBMS_RESOURCE_MANAGER.create_consumer_group(
    consumer_group => 'GROUP_JM_KILL_INACTIVE_BLOCK',
    comment        => 'Sessoes candidatas a encerramento por bloqueio ocioso');
END;
/


-- ============================================================================
-- PASSO 4 : Criar as diretivas
-- ============================================================================
-- Diretiva do grupo alvo: encerra a sessao INACTIVE que passar do limite E
-- estiver bloqueando outra. MAX_IDLE_TIME fica NULL de proposito, para nao
-- encerrar conexao apenas ociosa que nao bloqueia ninguem.
-- A diretiva OTHER_GROUPS e obrigatoria: cobre todas as demais sessoes, sem
-- encerramento por ociosidade.
BEGIN
  DBMS_RESOURCE_MANAGER.create_plan_directive(
    plan                  => 'RPLAN_JM',
    group_or_subplan      => 'GROUP_JM_KILL_INACTIVE_BLOCK',
    max_idle_blocker_time => 100,    -- segundos. Ajuste conforme o seu SLA.
    max_idle_time         => NULL,   -- NULL: nao encerra sessao so por estar ociosa
    comment               => 'Encerra apenas sessao INACTIVE que esteja bloqueando outra');

  DBMS_RESOURCE_MANAGER.create_plan_directive(
    plan             => 'RPLAN_JM',
    group_or_subplan => 'OTHER_GROUPS',
    comment          => 'Demais sessoes: sem encerramento por ociosidade');
END;
/


-- ============================================================================
-- PASSO 5 : Validar e submeter o plano
-- ============================================================================
-- O validate confere a consistencia do que esta na pending area; o submit
-- aplica em definitivo. Se o validate falhar, corrija e rode tudo de novo a
-- partir do PASSO 1.
BEGIN
  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area;
END;
/


-- ============================================================================
-- PASSO 6 : Conceder o switch ao schema
-- ============================================================================
-- Sem esse grant, a sessao do schema nao consegue ser colocada no consumer
-- group. grant_option => FALSE para o schema nao repassar o privilegio adiante.
BEGIN
  DBMS_RESOURCE_MANAGER_PRIVS.grant_switch_consumer_group(
    grantee_name   => 'APP_SCHEMA',
    consumer_group => 'GROUP_JM_KILL_INACTIVE_BLOCK',
    grant_option   => FALSE);
END;
/


-- ============================================================================
-- PASSO 7 : Mapear as sessoes ao grupo (Opcao A, recomendada)
-- ============================================================================
-- Os mapeamentos definem quais sessoes NOVAS entram no grupo. Neste ambiente,
-- os set_consumer_group_mapping precisam estar dentro de uma pending area com
-- validate/submit para passarem a valer; por isso abrimos a area de novo aqui.
--
-- Importante: o mapeamento vale para sessoes que se conectam DEPOIS dele.
-- Sessoes ja conectadas continuam no grupo antigo ate reconectarem.
BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area;
  DBMS_RESOURCE_MANAGER.create_pending_area;

  -- Por programa cliente (case sensitive: 'AppServer.exe' difere de 'APPSERVER.EXE')
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping(
    attribute      => DBMS_RESOURCE_MANAGER.client_program,
    value          => 'AppServer.exe',
    consumer_group => 'GROUP_JM_KILL_INACTIVE_BLOCK');

  -- Por usuario de SO do cliente
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping(
    attribute      => DBMS_RESOURCE_MANAGER.client_os_user,
    value          => 'root',
    consumer_group => 'GROUP_JM_KILL_INACTIVE_BLOCK');

  -- Por usuario Oracle (cuidado: pega o schema inteiro, ACTIVE e INACTIVE)
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping(
    attribute      => DBMS_RESOURCE_MANAGER.oracle_user,
    value          => 'APP_SCHEMA',
    consumer_group => 'GROUP_JM_KILL_INACTIVE_BLOCK');
END;
/

-- 7.1 Prioridade dos atributos de mapeamento. Quando uma sessao casa em mais de
--     um atributo, vence o de menor numero. O switch explicito tem sempre a
--     maior prioridade. Depois validamos e submetemos a pending area dos
--     mapeamentos.
BEGIN
  DBMS_RESOURCE_MANAGER.set_consumer_group_mapping_pri(
    explicit              => 1,
    client_program        => 2,
    client_os_user        => 3,
    oracle_user           => 4,
    service_name          => 5,
    client_machine        => 6,
    module_name           => 7,
    module_name_action    => 8,
    service_module        => 9,
    service_module_action => 10);

  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area;
END;
/


-- ============================================================================
-- PASSO 8 : Alternativa de mapeamento (Opcao B, trigger de logon)
-- ============================================================================
-- Use esta opcao NO LUGAR do PASSO 7 quando voce quer que a sessao entre no
-- grupo somente quando as TRES condicoes baterem juntas (usuario Oracle E
-- usuario de SO E programa). Se ja usou a Opcao A, NAO crie esta trigger.
--
-- A trigger termina com EXCEPTION WHEN OTHERS que engole o erro: uma trigger de
-- logon que falha pode IMPEDIR o login, entao nunca propague o erro.
CREATE OR REPLACE TRIGGER trg_map_kill_idle_blocker
AFTER LOGON ON DATABASE
DECLARE
  v_program  VARCHAR2(48);
  v_old      VARCHAR2(128);
BEGIN
  -- Condicao 1 (usuario Oracle) E Condicao 2 (usuario de SO). Comparacoes com
  -- UPPER nos dois lados, para nao escorregar em caixa.
  IF UPPER(SYS_CONTEXT('USERENV','SESSION_USER')) = 'APP_SCHEMA'
     AND UPPER(SYS_CONTEXT('USERENV','OS_USER'))  = 'ROOT'
  THEN
    -- Condicao 3 (programa): o PROGRAM nao esta em USERENV, e lido de v$session
    -- pela SID atual, por isso o owner da trigger precisa de SELECT em v$session.
    BEGIN
      SELECT program INTO v_program
      FROM   v$session
      WHERE  sid = SYS_CONTEXT('USERENV','SID')
      AND    rownum = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN v_program := NULL;
    END;

    -- So troca de grupo se as TRES condicoes baterem.
    IF UPPER(v_program) = 'APPSERVER.EXE' THEN
      DBMS_SESSION.switch_current_consumer_group(
        new_consumer_group     => 'GROUP_JM_KILL_INACTIVE_BLOCK',
        old_consumer_group     => v_old,
        initial_group_on_error => FALSE);
    END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;  -- trigger de logon nunca pode derrubar o login
END;
/


-- ============================================================================
-- PASSO 9 : Ativar o plano
-- ============================================================================
-- SCOPE = BOTH aplica na hora e persiste no estado do PDB. SID = '*' aplica em
-- todas as instancias do RAC. O prefixo FORCE: trava o plano: impede que uma
-- janela de manutencao do Scheduler troque o resource_manager_plan para o
-- DEFAULT_MAINTENANCE_PLAN e desligue a protecao.
ALTER SYSTEM SET resource_manager_plan = 'FORCE:RPLAN_JM' SCOPE = BOTH SID = '*';

SHOW PARAMETER resource_manager_plan
SELECT name, is_top_plan FROM v$rsrc_plan WHERE is_top_plan = 'TRUE';


-- ============================================================================
-- PASSO 10 : Validar a configuracao
-- ============================================================================
-- 10.1 Diretivas do plano (esperado: o grupo com 100 e OTHER_GROUPS sem limite).
SELECT plan, group_or_subplan, max_idle_time, max_idle_blocker_time
FROM   dba_rsrc_plan_directives
WHERE  plan = 'RPLAN_JM'
ORDER  BY group_or_subplan;

-- 10.2 Em que grupo as sessoes alvo cairam. Lembre: o mapeamento so vale para
--      sessoes novas, entao reconecte a aplicacao depois de aplicar.
SELECT inst_id, username, sid, serial#, osuser, program, status,
       resource_consumer_group, blocking_session, last_call_et AS idle_secs
FROM   gv$session
WHERE  resource_consumer_group = 'GROUP_JM_KILL_INACTIVE_BLOCK'
ORDER  BY inst_id, status, sid;

-- 10.3 Contador por instancia (RAC): IDLE_BLKR_SESSIONS_KILLED sobe a cada
--      bloqueador ocioso encerrado.
SELECT inst_id, name, idle_sessions_killed, idle_blkr_sessions_killed
FROM   gv$rsrc_consumer_group
WHERE  name IN ('GROUP_JM_KILL_INACTIVE_BLOCK','OTHER_GROUPS')
ORDER  BY inst_id, name;


-- ============================================================================
-- PASSO 11 : Teste controlado (faca isto antes de confiar em producao)
-- ============================================================================
-- Crie uma tabela de teste, abra a transacao na Sessao A e deixe ociosa sem
-- commitar, dispare a Sessao B que vai esperar no lock. A Sessao B so completa
-- depois que o Resource Manager encerrar a Sessao A bloqueadora ociosa.
--
-- Preparacao:
CREATE TABLE app_schema.t_dbrm_test (id NUMBER PRIMARY KEY, v VARCHAR2(10));
INSERT INTO app_schema.t_dbrm_test VALUES (1,'X');
COMMIT;

-- Sessao A (vira o bloqueador ocioso): rode, NAO commite e deixe a sessao parada.
UPDATE app_schema.t_dbrm_test SET v='A' WHERE id=1;

-- Sessao B (esperador): fica em enq: TX, ACTIVE, aguardando A. Quando o RM
-- encerrar A, o UPDATE de B completa.
UPDATE app_schema.t_dbrm_test SET v='B' WHERE id=1;

-- Limpeza do teste:
DROP TABLE app_schema.t_dbrm_test PURGE;


-- ============================================================================
-- PASSO 12 : Monitoramento (no dia a dia)
-- ============================================================================
-- Candidatos agora: sessao do grupo, INACTIVE e bloqueando alguem (waiters > 0).
SELECT s.sid, s.serial#, s.osuser, s.program, s.status,
       s.last_call_et AS idle_secs,
       (SELECT COUNT(*) FROM gv$session w WHERE w.blocking_session = s.sid) AS waiters
FROM   gv$session s
WHERE  s.resource_consumer_group = 'GROUP_JM_KILL_INACTIVE_BLOCK'
AND    s.status = 'INACTIVE'
AND    EXISTS (SELECT 1 FROM gv$session w WHERE w.blocking_session = s.sid)
ORDER  BY s.last_call_et DESC;


-- ============================================================================
-- PASSO 13 : Ajuste fino do limite
-- ============================================================================
-- Para mudar o limite sem recriar nada, atualize a diretiva dentro de uma
-- pending area. Exemplo: baixar de 100 para 60 segundos.
BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area;
  DBMS_RESOURCE_MANAGER.create_pending_area;
  DBMS_RESOURCE_MANAGER.update_plan_directive(
    plan                      => 'RPLAN_JM',
    group_or_subplan          => 'GROUP_JM_KILL_INACTIVE_BLOCK',
    new_max_idle_blocker_time => 60);
  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area;
END;
/


-- ============================================================================
-- ROLLBACK : Reverter tudo
-- ============================================================================
-- 1) Desative o plano, ou restaure o plano anterior que voce anotou no PASSO 0.
--    Para restaurar o anterior, troque '' pelo nome do plano (sem o FORCE:).
ALTER SYSTEM SET resource_manager_plan = '' SCOPE = BOTH;

-- 2) Remova a trigger de mapeamento (somente se usou a Opcao B do PASSO 8).
DROP TRIGGER trg_map_kill_idle_blocker;

-- 3) Revogue o switch concedido ao schema.
BEGIN
  DBMS_RESOURCE_MANAGER_PRIVS.revoke_switch_consumer_group(
    revokee_name   => 'APP_SCHEMA',
    consumer_group => 'GROUP_JM_KILL_INACTIVE_BLOCK');
END;
/

-- 4) Apague diretivas, plano e consumer group dentro de uma pending area.
BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area;
  DBMS_RESOURCE_MANAGER.create_pending_area;
  DBMS_RESOURCE_MANAGER.delete_plan_directive('RPLAN_JM','GROUP_JM_KILL_INACTIVE_BLOCK');
  DBMS_RESOURCE_MANAGER.delete_plan_directive('RPLAN_JM','OTHER_GROUPS');
  DBMS_RESOURCE_MANAGER.delete_plan('RPLAN_JM');
  DBMS_RESOURCE_MANAGER.delete_consumer_group('GROUP_JM_KILL_INACTIVE_BLOCK');
  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area;
END;
/


-- ============================================================================
-- REFERENCIAS (documentacao oficial Oracle)
-- ============================================================================
-- DBMS_RESOURCE_MANAGER (CREATE_PLAN_DIRECTIVE, UPDATE_PLAN_DIRECTIVE,
--   SET_CONSUMER_GROUP_MAPPING): Oracle Database PL/SQL Packages and Types
--   Reference, 19c.
--   https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/
-- DBMS_RESOURCE_MANAGER_PRIVS (GRANT_SWITCH_CONSUMER_GROUP,
--   REVOKE_SWITCH_CONSUMER_GROUP): mesma referencia ARPLS 19c.
-- Managing Resources with Oracle Database Resource Manager: Oracle Database
--   Administrator's Guide, 19c.
--   https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/
-- GV$RSRC_CONSUMER_GROUP e V$RSRC_PLAN: Oracle Database Reference, 19c.
-- ============================================================================
