#!/usr/bin/env bash

sql_path="";

# is $ORACLE_HOME environment path set
if [[ -z "${ORACLE_HOME+set}" ]]; then
  printf "%s%03d\t%s\n" "W" "$LINENO" "\$ORACLE_HOME path is not set" >&2;
fi

# is sqlplus command available
if ! command -v sqlplus &>/dev/null; then
  printf "%s%03d\t%s\n" "E" "$LINENO" "sqlplus is NOT installed or not in \$PATH" >&2;
  exit 1;
fi
## echo "exit" | sqlplus -S /nolog > /dev/null
## export RETURN_CODE=$?

# at least one input parameter was provided
if [[ $# -gt 0 ]]; then
  # read full path
  sql_path=$( readlink -f "${1%/}" );
  # path exist
  if [[ -d "${sql_path}" || -f "${sql_path}" ]]; then
    # dir contains .env file
    env_file="${sql_path}/.env";
    if [[ -f "${env_file}" ]]; then
      # read each line
      while IFS= read -r env_line || [[ -n "${env_line}" ]]; do
        # remove Windows CR (\r) and any trailing spaces/tabs
        #env_line=$( sed -e 's/[[:space:]]*$//' <<< "${env_line}" );
        # Skip empty lines or lines starting with comments
        [[ -z "${env_line}" || "${env_line}" =~ ^[[:space:]]*# ]] && continue
        # match simple assignments VAR=value or export VAR=value
        if [[ "$env_line" =~ ^([[:space:]]*export[[:space:]]+)?([A-Za-z_][A-Za-z_0-9]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
          var_name="${BASH_REMATCH[2]}"
          var_value="${BASH_REMATCH[3]}"
          # Trim trailing whitespace from the captured value (e.g., "staging    " -> "staging")
          var_value="${var_value%"${var_value##*[![:space:]]}"}"
          # Strip leading/trailing quotes if the value was wrapped in them
          var_value="${var_value#\'}"; var_value="${var_value%\'}"
          var_value="${var_value#\"}"; var_value="${var_value%\"}"
          # declare -p checks if the variable exists in the environment/shell
          if ! declare -p "${var_name}" &>/dev/null; then
            export "$var_name"="$var_value";
          fi
        fi
      done < "${env_file}";
    fi
  else
    printf "%s%03d\t%s\n" "E" "$LINENO" "${1} - path not found" >&2;
    exit 1;
  fi
else
  printf "%s%03d\t%s\n" "E" "$LINENO" "provide a path to sql file or dir with sql files" >&2;
  exit 1
fi

# is environment variable $SQLPLUSCONNECT set and not empty
if [[ -z "${SQLPLUSCONNECT}" ]]; then
  printf "%s%03d\t%s\n" "E" "$LINENO" "\$SQLPLUSCONNECT is not set, will not be able to connect" >&2;
  exit 1;
fi

# does provided path is a directory and contains SQL files
if [[ -d "${sql_path}" ]]; then
  # *.pls (PL/SQL source)
  # *.pks (Package source or package specification)
  # *.pkb (Package binary or package body)
  # *.pck (Combined package specification plus body)
  if ! find "${sql_path}" \( -type f -iname '*.sql' -or -iname '*.pls' -or -iname '*.pck' -or -iname '*.pks' -or -iname '*.pkb' \) -print -quit | grep --quiet --no-messages .; then
    printf "%s%03d\t%s\n" "E" "$LINENO" "no sql files found in provided path" >&2;
    exit 1;
  fi
fi

# TEST CONNECTION
connection_test=$( sqlplus -S -L /nolog <<EOF
WHENEVER OSERROR EXIT SUCCESS
WHENEVER SQLERROR EXIT SUCCESS
SET LINESIZE 250
SET PAGESIZE 0
CONNECT ${SQLPLUSCONNECT}
select replace(replace(BANNER_FULL,chr(13),' '),chr(10),' ') as BANNER_SINGLE_LINE from V\$VERSION;
DISCONNECT;
EXIT;
EOF
);
if [[ -z "${connection_test}" || "$connection_test" == *"ORA-"* ]]; then
  printf "%s%03d\t%s\n" "E" "$LINENO" "could not connect" >&2;
  printf "%s\n" "${connection_test}" >&2;
  exit 1;
fi

# DEFINE ENVIRONMENT VARIABLES
SQL_DEFINE="";
while IFS='=' read -r env_key env_value; do
  env_key="${env_key//[^a-zA-Z0-9_]/}";
  if [[ ${#env_key} -gt 1 ]]; then
    env_value="${env_value//\'/\'\'}";
    SQL_DEFINE=$( printf "%s\n%s" "${SQL_DEFINE}" "DEFINE I_${env_key^^} = '${env_value}';" ); # +="@@${SQLFILE};"$'\n';
  fi
done < <( env | grep --no-messages -v 'SQLPLUSCONNECT' );
# TODO: or grep '^SQL_'

# FIND FILES
SQL_FILE="";
if [[ -f "${sql_path}" ]]; then
  SQL_FILE="@@${sql_path};";
fi
if [[ -d "${sql_path}" ]]; then
  while read -r -d $'\0' SQLFILE; do
    if [[ -f "${SQLFILE}" ]]; then
      SQL_FILE=$( printf "%s\n%s" "${SQL_FILE}" "@@${SQLFILE}" ); # +="@@${SQLFILE};"$'\n';
    fi;
  done < <(find "${sql_path}" \( -type f -iname '*.sql' -or -iname '*.pls' -or -iname '*.pck' -or -iname '*.pks' -or -iname '*.pkb' \) -print0 | sort --ignore-case --numeric-sort --zero-terminated);
fi

# TODO: if $SQLPLUS_LOG_PATH variable is present, SPOOL into it instead of terminal ?

# RUN
sqlplus -S -L /nolog <<EOF

REM Performs the specified action (exits SQL*Plus by default) if an operating system error occurs (such as a file writing error).
WHENEVER OSERROR EXIT FAILURE ROLLBACK

REM Performs the specified action (exits SQL*Plus by default) if a SQL command or PL/SQL block generates an error.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

REM Controls whether SQL*Plus lists the old and new settings of a SQL*Plus system variable when you change the setting with SET.
SET SHOWMODE OFF

REM Controls whether to display output (that is, DBMS_OUTPUT.PUT_LINE) of stored procedures or PL/SQL blocks in SQL*Plus.
SET SERVEROUTPUT ON FORMAT WORD_WRAPPED

REM Controls when Oracle Database commits pending changes to the database.
REM SET AUTOCOMMIT OFF

REM Displays the number of records returned by a script when a script selects at least n records.
REM SET FEEDBACK OFF

REM Controls printing of column headings in reports.
REM SET HEADING OFF

REM Controls the display of output generated by commands in a script that is executed with @, @@ or START.
REM SET TERMOUT ON

REM Sets the total number of characters that SQL*Plus displays on one line before beginning a new line.
SET LINESIZE 100

REM Sets the number of lines on each page of output. You can set PAGESIZE to zero to suppress all headings, page breaks, titles, the initial blank line, and other formatting information.
REM SET PAGESIZE 0
SET PAGESIZE 1000

REM Determines whether SQL*Plus puts trailing blanks at the end of each spooled line.
SET TRIMSPOOL ON

REM Controls whether to list the text of a SQL statement or PL/SQL command before and after replacing substitution variables with values.
SET VERIFY OFF

REM Controls whether SQL*Plus truncates the display of a SELECTed row if it is too long for the current line width.
REM SET WRAP OFF
REM  old: wrap : lines will be wrapped
REM  new: wrap : lines will be truncated

REM Controls whether or not to echo commands in a script that is executed with @, @@ or START.
SET ECHO OFF

CONNECT ${SQLPLUSCONNECT}

ALTER SESSION DISABLE PARALLEL DML;
ALTER SESSION DISABLE PARALLEL DDL;
-- ALTER SESSION DISABLE PARALLEL query;

${SQL_DEFINE}

${SQL_FILE}

COMMIT;
DISCONNECT;
EXIT;

EOF
