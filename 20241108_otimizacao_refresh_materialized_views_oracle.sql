--===========================================================================

--## 20241108_otimizacao_refresh_materialized_views_oracle.sql
--## http://dbasobrinho.com.br
--## https://dbasobrinho.com.br/materialized-views-lentas-otimize-o-refresh-com-atomic_refresh/
--## Data: 08/11/2024

--===========================================================================

--## Materialized views lentas? Otimize o refresh com atomic_refresh

--## Em grandes volumes de dados, materialized views (MVIEWs) podem ter refresh completo lento no Oracle
--## Por padrão, o parâmetro de refresh ATOMIC_REFRESH = TRUE garante consistência, mas é mais lento
--## Já que o Oracle usa DELETE para limpar dados antigos, gerando undo e redo
--## Uma solução rápida? Configurar ATOMIC_REFRESH = FALSE, o que permite o uso de TRUNCATE e acelera o processo
--## Embora deixe a MVIEW indisponível temporariamente

--===========================================================================

--## Exemplo prático: Comparando atomic_refresh = true e false

--## 1. Criando a tabela para exemplo
CREATE TABLE tb_teste_dba AS
SELECT LEVEL AS id,
       'Produto ' || LEVEL AS nome,
       TRUNC(DBMS_RANDOM.VALUE(1, 1000), 2) AS preco,
       ROUND(DBMS_RANDOM.VALUE(1, 1000)) AS quantidade,
       TO_DATE('2023-01-01', 'YYYY-MM-DD') + LEVEL AS data_venda
FROM dual
CONNECT BY LEVEL <= 500000;

--===========================================================================

--## 2. Criando a materialized view MV_TESTE_DBA
CREATE TABLE tb_teste_dba AS
SELECT LEVEL AS id,
       'Produto ' || LEVEL AS nome,
       TRUNC(DBMS_RANDOM.VALUE(1, 1000), 2) AS preco,
       ROUND(DBMS_RANDOM.VALUE(1, 1000)) AS quantidade,
       TO_DATE('2023-01-01', 'YYYY-MM-DD') + LEVEL AS data_venda
FROM dual
CONNECT BY LEVEL <= 500000;

--===========================================================================

--## 3. Executando o refresh com ATOMIC_REFRESH = TRUE
SET TIMING ON;
BEGIN
   DBMS_MVIEW.REFRESH('mv_teste_dba', METHOD => 'C', ATOMIC_REFRESH => TRUE);
END;
/

--## O refresh levou 3 minutos e 58 segundos para 500 mil linhas
--## Esse modo gera undo e redo, o que impacta o tempo
--## Mas mantém a MVIEW acessível durante o refresh

--===========================================================================

--## 4. Executando o refresh com ATOMIC_REFRESH = FALSE

--## Repetimos o processo, agora com ATOMIC_REFRESH = FALSE para usar TRUNCATE

SET TIMING ON;
BEGIN
   DBMS_MVIEW.REFRESH('mv_teste_dba', METHOD => 'C', ATOMIC_REFRESH => FALSE);
END;
/

--## O refresh foi mais rápido, reduzindo o tempo para apenas 6 segundos
--## O consumo de recursos cai bastante, mas a MVIEW fica temporariamente indisponível
--## E em caso de falhas a MVIEW ficará vazia até o próximo refresh bem-sucedido

--===========================================================================

--## Comparação de tempos e impacto
--## ATOMIC_REFRESH    | Tempo de Execução | Tipo Exclusão | Durante Refresh
--## ----------------- | ----------------- | ------------- | ---------------
--## TRUE              | ~3m 58s           | DELETE        | Disponível
--## FALSE             | ~6 segundos       | TRUNCATE      | Indisponível
