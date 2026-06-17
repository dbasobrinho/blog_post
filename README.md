# Blog Post — Posts Técnicos (Oracle / DBA)

Repositório de scripts e materiais que acompanham os posts técnicos.
Organização: **uma pasta por post**, nomeada `AAAAMMDD_titulo`, contendo o `.sql`,
a versão em inglês (`_ENG`) e eventuais anexos (`.docx`/`.pdf`) do mesmo artigo.

## Posts

| Data | Post | Pasta | Conteúdo |
|------|------|-------|----------|
| 2024-08-29 | Testando `PASSWORD_ROLLOVER_TIME` | [`20240829_testando_password_rollover_time/`](20240829_testando_password_rollover_time/) | SQL |
| 2024-10-01 | Evite problemas com DB Links ao clonar ambientes | [`20241001_evite_problemas_com_dblinks_ao_clonar_ambientes/`](20241001_evite_problemas_com_dblinks_ao_clonar_ambientes/) | SQL |
| 2024-11-08 | Otimização do refresh de Materialized Views | [`20241108_otimizacao_refresh_materialized_views_oracle/`](20241108_otimizacao_refresh_materialized_views_oracle/) | SQL · PT + ENG |
| 2024-11-29 | Procurar termos no corpo de Views | [`20241129_procurar_termos_corpo_views/`](20241129_procurar_termos_corpo_views/) | SQL · PT + ENG |
| 2024-12-10 | INSERT com `BULK COLLECT` / `FORALL` | [`20241210_insert_bulk_collect_forall/`](20241210_insert_bulk_collect_forall/) | SQL · com e sem sequence |
| 2025-03-03 | Auditoria unificada: login fail + all DDL | [`20250303_audit_unified_login_fail_and_all_ddl/`](20250303_audit_unified_login_fail_and_all_ddl/) | SQL + DOCX + PDF |
| 2025-03-17 | HugePages no Oracle — passo a passo no Red Hat 9.5 | [`20250317_hugepages_oracle_red_hat_9_5/`](20250317_hugepages_oracle_red_hat_9_5/) | SQL |

## Séries (sem data)

| Série | Pasta | Conteúdo |
|-------|-------|----------|
| PL/SQL Trace (DBMS_TRACE) | [`plsql_trace/`](plsql_trace/) | `01_instalar` → `02_tabela_teste` → `03_procedure`. `00_instalar_legado` é a versão antiga do instalador. |

## Convenções

- **Pasta:** `AAAAMMDD_titulo_em_snake_case`.
- **Idioma:** versão em inglês recebe o sufixo `_ENG` no mesmo diretório do post.
- **Anexos:** `.docx`/`.pdf` ficam junto do `.sql` correspondente.
- **Séries** numeradas (sem data própria) ficam em pasta de nome temático com prefixo de ordem (`01_`, `02_`, ...).
