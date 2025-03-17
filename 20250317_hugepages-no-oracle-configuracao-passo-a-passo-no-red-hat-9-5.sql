--===========================================================================
--## 20250317_hugepages-no-oracle-configuracao-passo-a-passo-no-red-hat-9-5.sql
--## https://github.com/dbasobrinho/blog_post/blob/main/20250317_hugepages-no-oracle-configuracao-passo-a-passo-no-red-hat-9-5.sql
--## https://dbasobrinho.com.br/hugepages-no-oracle-configuracao-passo-a-passo-no-red-hat-9-5/
--## Autor: Roberto Fernandes Sobrinho 
--## Data de criação: 2025-03-17
--===========================================================================

--## HugePages no Oracle: Configuração Passo a Passo no Red Hat 9.5
--## A configuração de HugePages no Linux melhora o desempenho do Oracle Database ao reduzir a fragmentação de memória e evitar o uso de swap na SGA.
--## Isso garante uma alocação eficiente da RAM e otimiza a performance do banco.

--===========================================================================

--## Passo 01 – Verificar Memória Disponível

[root@lnx95orasp01 ~]$ free -g
               total        used        free      shared  buff/cache   available
Mem:              15           2          10           0           3          12
Swap:              1           0           1
[root@lnx95orasp01 ~]$

--===========================================================================

--## Passo 02 – Calcular a Quantidade de HugePages

[root@lnx95orasp01 ~]$ grep Hugepagesize /proc/meminfo
Hugepagesize:       2048 kB
[root@lnx95orasp01 ~]$

-- Cálculo SQL para validar diretamente no Oracle:

SQL> 
VARIABLE sga_size NUMBER;
EXEC :sga_size := 9; -- Definir o tamanho da SGA em GB

SELECT  
    ROUND(:sga_size * 1024 * 1024 * 1024, 2) AS SGA_TOT_BYTES,  
    ROUND(2048 * 1024, 2) AS Hugepagesize_BYTES,  
    ROUND((:sga_size * 1024 * 1024 * 1024) / (2048 * 1024), 2) AS HugePages_Required,  
    ROUND(((:sga_size * 1024 * 1024 * 1024) / (2048 * 1024)) * 1.005, 2) AS HugePages_With_Margin  
FROM DUAL;

--===========================================================================

--## Passo 03 – Configurar HugePages no Linux

[root@lnx95orasp01 ~]$ echo "vm.nr_hugepages=4631" > /etc/sysctl.d/99-hugepages.conf
[root@lnx95orasp01 ~]$ echo "vm.hugetlb_shm_group=54321" >> /etc/sysctl.d/99-hugepages.conf
[root@lnx95orasp01 ~]$ echo "vm.swappiness=2" >> /etc/sysctl.d/99-hugepages.conf
[root@lnx95orasp01 ~]$ echo "vm.vfs_cache_pressure=150" >> /etc/sysctl.d/99-hugepages.conf
[root@lnx95orasp01 ~]$ echo "vm.min_free_kbytes=2097152" >> /etc/sysctl.d/99-hugepages.conf

[root@lnx95orasp01 ~]$ sysctl --system

-- Reiniciar o servidor para garantir que as configurações sejam aplicadas corretamente
[root@lnx95orasp01 ~]$ reboot

--===========================================================================

--## Passo 04 – Configurar os Parâmetros do Oracle Database

[oracle@lnx95orasp01 ~]$ sqlplus / as sysdba

SQL> ALTER SYSTEM SET use_large_pages = ONLY SCOPE=spfile SID='*';
SQL> ALTER SYSTEM SET sga_max_size = 9G SCOPE=spfile SID='*';
SQL> ALTER SYSTEM SET sga_target = 9G SCOPE=spfile SID='*';
SQL> ALTER SYSTEM SET pga_aggregate_target = 2G SCOPE=spfile SID='*';
SQL> ALTER SYSTEM SET pga_aggregate_limit = 4G SCOPE=spfile SID='*';

SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP;

-- Verificar se as HugePages foram corretamente alocadas após o startup do banco

[oracle@lnx95orasp01 ~]$ grep Huge /proc/meminfo
AnonHugePages:    204800 kB
ShmemHugePages:        0 kB
FileHugePages:         0 kB
HugePages_Total:    4631
HugePages_Free:       32
HugePages_Rsvd:       11
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:         9484288 kB
[oracle@lnx95orasp01 ~]$

--===========================================================================

--## Passo 05 – Desativar Transparent HugePages (THP)

[root@lnx95orasp01 ~]$ vi /etc/rc.d/rc.local

-- Adicionar as seguintes linhas ao final do arquivo:
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

[root@lnx95orasp01 ~]$ chmod +x /etc/rc.d/rc.local

[root@lnx95orasp01 ~]$ vi /etc/systemd/system/rc-local.service

-- Adicionar as seguintes linhas ao arquivo:

[Unit]
Description=/etc/rc.d/rc.local Compatibility
ConditionFileIsExecutable=/etc/rc.d/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.d/rc.local start
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

[root@lnx95orasp01 ~]$ systemctl daemon-reload
[root@lnx95orasp01 ~]$ systemctl enable rc-local
[root@lnx95orasp01 ~]$ systemctl start rc-local
[root@lnx95orasp01 ~]$ systemctl status rc-local

--===========================================================================

--## Reiniciar o Servidor para Aplicar a Desativação do THP

[root@lnx95orasp01 ~]$ reboot

-- Após o reboot, verificar:

[root@lnx95orasp01 ~]$ uptime
 19:22:12 up 2 min,  1 user,  load average: 0.17, 0.14, 0.06
[root@lnx95orasp01 ~]$ cat /sys/kernel/mm/transparent_hugepage/enabled
always madvise [never]
[root@lnx95orasp01 ~]$  cat /sys/kernel/mm/transparent_hugepage/defrag
always defer defer+madvise madvise [never]
