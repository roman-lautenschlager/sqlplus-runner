# sqlplus-runner

## Wrapper for Oracle Database SQL*Plus

- to use with connection details stored in environment variable (by default only not yet set variables are loaded from .env file, to overwrite already set variables, source .env file before calling the script to load all)
- to run all *.sql files from provided path in order (when a single file is passed .env is loaded from the directory containing the file)
- to use any environment variable in sql as substitution variables (all available env vars become available in sqlplus call as SQL defines with the I_ prefix)

### Prerequisites
- Oracle Instant Client
- sqlplus in $PATH
- BASH or PowerShell

### RTFM

[SQL*Plus command summary](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SQL-Plus-command-summary.html)

[SQL*Plus CONNECT command](https://docs.oracle.com/en/database/oracle/oracle-database/19/spmdu/step-4-submit-the-sql-plus-connect-command.html)

[SET System Variable summary](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SET-system-variable-summary.html)

[Using substitution variables](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqpug/using-substitution-variables-sqlplus.html)

### .env

```bash
# connection string in a format accepted by CONNECT command
SQLPLUSCONNECT="username/password@host:port/service"

# sql substitution variables, prefix I_ is added during DEFINE
ORACLE_USER_NAME=MY_USER
ORACLE_USER_TABLESPACE=DATA
MY_PARAMETER=123
```

### .sql

```sql
-- use substitution variables in sql
select count(*)
  into v_tablespace_count
  from dba_tablespaces
 where tablespace_name = upper( '&&I_ORACLE_USER_TABLESPACE' );
-- etc...
```

### .run

```sh
# BASH
export SQLPLUSCONNECT="username/password@host:port/service"
./sqlrun.sh  /path/to/sql/files
./sqlrun.sh  /path/to/single/script.sql

# or
SQLPLUSCONNECT="ADMIN/$( cat ~/.oracle/.pass )@cloud_low"  ./sqlrun.sh  ./sql
```

```powershell
# POWERSHELL
$env:SQLPLUSCONNECT="username/password@host:port/service"
.\sqlrun.ps1 .\path\to\sql\files
.\sqlrun.ps1 .\path\to\single\script.sql
```
