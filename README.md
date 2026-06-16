# sqlplus-runner

## Wrapper for Oracle Database SQL*Plus

- to use with connection details stored in environment variable
- to run all *.sql files from provided path in order
- to use any environment variable in sql as substitution variables

### Store connection and other input variables in .env file

[SQL*Plus command summary](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SQL-Plus-command-summary.html)

[SQL*Plus CONNECT command](https://docs.oracle.com/en/database/oracle/oracle-database/19/spmdu/step-4-submit-the-sql-plus-connect-command.html)

[SET System Variable summary](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SET-system-variable-summary.html)

[Using substitution variables](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqpug/using-substitution-variables-sqlplus.html)

```bash
# .env

# connection string in a format accepted by CONNECT command
SQLPLUSCONNECT="username/password@host:port/service"

# sql substitution variables, prefix I_ is added during DEFINE
ORACLE_USER_NAME=MY_USER
ORACLE_USER_TABLESPACE=DATA
MY_PARAMETER=123
```

### Use substitution variables in sql

```sql
select count(*)
  into v_tablespace_count
  from dba_tablespaces
 where tablespace_name = upper( '&&I_ORACLE_USER_TABLESPACE' );
-- etc...
```

### Run

```sh
# BASH
export SQLPLUSCONNECT="username/password@host:port/service"
./sqlrun.sh  /path/to/sql/files

# or
BASH_ENV=.env  ./sqlrun.sh  /path/to/sql/files

# or
SQLPLUSCONNECT="ADMIN/$( cat ~/.oracle/.pass )@cloud_low"  ./sqlrun.sh  ./sql
```

```powershell
# POWERSHELL
$env:SQLPLUSCONNECT="username/password@host:port/service"
.\sqlrun.ps1 .\sql\files
```
