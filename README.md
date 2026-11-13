# sqlplus-runner

## Wrapper for Oracle Database SQL*Plus

- connect using details from SQLPLUSCONNECT environment variable
- run all *.sql|pls|pck|pks|pkb files (skipping hidden paths) from provided path in order
- use any environment variable with I_|V_|SQL_ prefix in sql as substitution variables

### Prerequisites
- Oracle Instant Client
- sqlplus in $PATH
- BASH or PowerShell

### RTFM

[SQL*Plus command summary](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SQL-Plus-command-summary.html)

[SQL*Plus CONNECT command](https://docs.oracle.com/en/database/oracle/oracle-database/19/spmdu/step-4-submit-the-sql-plus-connect-command.html)

[SET System Variable summary](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SET-system-variable-summary.html)

[Using substitution variables](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqpug/using-substitution-variables-sqlplus.html)


### sql substitution variables

```bash
# BASH
export I_ORACLE_USER_TABLESPACE=DATA
export I_MY_PARAMETER=123
```

```sql
-- SQL
select count(*)
  into v_tablespace_count
  from dba_tablespaces
 where tablespace_name = upper( '&&I_ORACLE_USER_TABLESPACE' );
```

### run sing file or whole directory (sorted)

```sh
# BASH
export SQLPLUSCONNECT="username/password@host:port/service"
./sqlplusrun.sh  ./path/to/all/files
./sqlplusrun.sh  ./path/to/single/file.sql

# or set connection string before run
SQLPLUSCONNECT="ADMIN/$( cat ~/.oracle/.pass )@cloud_low"; ./sqlplusrun.sh  ./sql
```

```powershell
# POWERSHELL
$env:SQLPLUSCONNECT="username/password@host:port/service"
.\sqlplusrun.ps1 .\path\to\all\files
.\sqlplusrun.ps1 .\path\to\single\file.sql
```

### WARNING: not covered (possible TODO)
- bash 4+ is required for *.sh
- file names cannot contain & or " in their names
- multiline environment variables are skipped
- only environment variables starting with I_ V_ or SQL_ are converted into DEFINE statements
- environment variable names are stripped to 'a-zA-Z0-9_' (can cause collision of A-B and AB)
- environment variable names are limited to 128 characters
- environment variable value is cut to 240 characters
- could happen that sort places package body (*.pkb) before package head (*.pks), use numbered files or keep both in one file
- sorting of files works best with numbered 1_named 2_files
- .hidden files and subdirs are skipped, only *.sql *.pls *.pck *.pks *.pkb files are processed
- SP2- errors are not covered
