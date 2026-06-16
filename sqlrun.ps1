#!/usr/bin/env pwsh

[CmdletBinding()]
Param(
    [Parameter(Mandatory, Position = 0)]
    [string] $Path
)

function Write-Diag {
    Param(
      [string]$Level,
      [string]$Message
    )
    $line = (Get-PSCallStack)[1].ScriptLineNumber
    [Console]::Error.WriteLine(("{0}{1:D3}`t{2}" -f $Level, $line, $Message))
}

$sql_path = ""

# is $ORACLE_HOME environment path set
if (-not $env:ORACLE_HOME) {
    Write-Diag "W" '$ORACLE_HOME path is not set'
}

# is sqlplus command available
if (-not (Get-Command sqlplus -ErrorAction SilentlyContinue)) {
    Write-Diag "E" 'sqlplus is NOT installed or not in $PATH'
    exit 1
}

# resolve full path
try {
    $sql_path = (Resolve-Path $Path -ErrorAction Stop).Path
} catch {
    Write-Diag "E" "$Path - path not found"
    exit 1
}

# path must be a file or directory
if (-not ((Test-Path $sql_path -PathType Container) -or (Test-Path $sql_path -PathType Leaf))) {
    Write-Diag "E" "$Path - path not found"
    exit 1
}

# load .env file if present (only meaningful when sql_path is a directory)
$env_file = Join-Path $sql_path ".env"
if (Test-Path $env_file -PathType Leaf) {
    foreach ($env_line in [System.IO.File]::ReadAllLines($env_file)) {
        # skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($env_line) -or $env_line -match '^\s*#') { continue }
        # match VAR=value or export VAR=value
        if ($env_line -match '^(\s*export\s+)?([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(.*)$') {
            $var_name  = $Matches[2]
            $var_value = $Matches[3].TrimEnd()
            # strip one leading/trailing single quote, then double quote (mirrors bash behavior)
            if ($var_value.StartsWith("'"))  { $var_value = $var_value.Substring(1) }
            if ($var_value.EndsWith("'"))    { $var_value = $var_value.Substring(0, $var_value.Length - 1) }
            if ($var_value.StartsWith('"'))  { $var_value = $var_value.Substring(1) }
            if ($var_value.EndsWith('"'))    { $var_value = $var_value.Substring(0, $var_value.Length - 1) }
            # only set if not already in environment
            if ($null -eq [System.Environment]::GetEnvironmentVariable($var_name)) {
                [System.Environment]::SetEnvironmentVariable($var_name, $var_value, "Process")
            }
        }
    }
}

# is $SQLPLUSCONNECT set and not empty
if ([string]::IsNullOrEmpty($env:SQLPLUSCONNECT)) {
    Write-Diag "E" '$SQLPLUSCONNECT is not set, will not be able to connect'
    exit 1
}

# if directory, verify it contains SQL files
if (Test-Path $sql_path -PathType Container) {
    $has_sql = Get-ChildItem -Path $sql_path -Recurse -File |
        Where-Object { $_.Extension -imatch '\.(sql|pls|pck|pks|pkb)$' } |
        Select-Object -First 1
    if (-not $has_sql) {
        Write-Diag "E" "no sql files found in provided path"
        exit 1
    }
}

# TEST CONNECTION
$connection_test = @"
WHENEVER OSERROR EXIT SUCCESS
WHENEVER SQLERROR EXIT SUCCESS
SET LINESIZE 250
SET PAGESIZE 0
CONNECT $($env:SQLPLUSCONNECT)
select replace(replace(BANNER_FULL,chr(13),chr(32)),chr(10),chr(32)) as BANNER_SINGLE_LINE from V`$VERSION;
DISCONNECT;
EXIT;
"@ | sqlplus -S -L /nolog

if ([string]::IsNullOrWhiteSpace($connection_test) -or $connection_test -match 'ORA-') {
    Write-Diag "E" "could not connect"
    [Console]::Error.WriteLine($connection_test)
    exit 1
}

# DEFINE ENVIRONMENT VARIABLES — expose all env vars as SQL*Plus substitution variables
$SQL_DEFINE = ""
Get-ChildItem Env: | Where-Object { $_.Name -ne 'SQLPLUSCONNECT' } | ForEach-Object {
    $env_key = $_.Name -replace '[^a-zA-Z0-9_]', ''
    if ($env_key.Length -gt 1) {
        $env_value = $_.Value -replace "'", "''"
        $SQL_DEFINE += "`nDEFINE I_$($env_key.ToUpper()) = '$env_value';"
    }
}

# FIND FILES
$SQL_FILE = ""
if (Test-Path $sql_path -PathType Leaf) {
    $SQL_FILE = "@@$sql_path;"
}
if (Test-Path $sql_path -PathType Container) {
    Get-ChildItem -Path $sql_path -Recurse -File |
        Where-Object { $_.Extension -imatch '\.(sql|pls|pck|pks|pkb)$' } |
        Sort-Object FullName |
        ForEach-Object { $SQL_FILE += "`n@@$($_.FullName)" }
}

# RUN
@"

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

CONNECT $($env:SQLPLUSCONNECT)

ALTER SESSION SET RECYCLEBIN = OFF;

ALTER SESSION DISABLE PARALLEL DML;
ALTER SESSION DISABLE PARALLEL DDL;
-- ALTER SESSION DISABLE PARALLEL query;

$SQL_DEFINE

$SQL_FILE

COMMIT;
DISCONNECT;
EXIT;

"@ | sqlplus -S -L /nolog
