<#
.SYNOPSIS
    Runs the Fitness clean-up scripts in db\scripts in the right order, one phase at a time.

.DESCRIPTION
    The clean-up has decision points between phases (read the test results, fix data, give the API its own identity,
    wait out the quarantine), so the scripts are grouped into phases and you run one phase per call:

      Audit        00_usage_audit.sql                          read-only report
      Test         00c_test_procedure_fixes.sql                read-only; stops if the summary has FIXED-ERROR,
                                                               UNEXPECTED-DIFF or FAIL
      Archive      00b_apply_procedure_fixes.sql               apply the procedure fixes
                   01_move_to_archive_schema.sql               move procedures to the [archive] schema
                   01b_archive_gpx_tables.sql                  move the six legacy GPX tables to [archive]
      Duration     views\*.sql                                 revised report views
                   tables\rebuild_<Table>.sql (nine tables)    preview only, unless -Apply
      Permissions  04_permissions.sql                          preview only, unless -Apply; needs -ServiceUser
      Drop         03_drop_archived_objects.sql                final removal after the quarantine period
                   03b_drop_gpx_tables.sql
      Rollback     02b_rollback_gpx_archive.sql, 02_rollback_archive.sql   undo Archive

    Every script's output is saved under db\scripts\logs. The run stops at the first error.
    Staging (an instance named ...\DEVELOPMENT) is the default target. Any other server is treated as production
    and needs -Production plus a typed confirmation.

.EXAMPLE
    .\Run-FitnessScripts.ps1 -Phase Test
.EXAMPLE
    .\Run-FitnessScripts.ps1 -Phase Duration            # preview every table rebuild
    .\Run-FitnessScripts.ps1 -Phase Duration -Apply     # rebuild the tables
.EXAMPLE
    .\Run-FitnessScripts.ps1 -Phase Permissions -ServiceUser 'IIS APPPOOL\FitnessApi' -Apply
.EXAMPLE
    .\Run-FitnessScripts.ps1 -Phase Archive -Server . -Production
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Audit', 'Test', 'Archive', 'Duration', 'Permissions', 'Drop', 'Rollback')]
    [string]$Phase,

    [string]$Server = '.\DEVELOPMENT',
    [string]$Database = 'Fitness',

    # Make changes in the phases that preview by default (Duration, Permissions).
    [switch]$Apply,

    # Database user the .NET service connects as (Permissions phase).
    [string]$ServiceUser,

    # Duration phase: rebuild even where stored durations differ from StartTime/EndTime.
    [switch]$DropEvenIfDisagree,

    # Required for any server other than ...\DEVELOPMENT.
    [switch]$Production,

    # Use a SQL login instead of Windows authentication (you are prompted for the password).
    [string]$SqlLogin
)

$ErrorActionPreference = 'Stop'
$root    = $PSScriptRoot                                   # ...\db\scripts
$archive = Join-Path $root 'archive\scripts'
$logDir  = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw 'sqlcmd was not found. Install the SQL Server command-line tools or add sqlcmd to PATH.'
}

# ---- target safety -------------------------------------------------------------------------------------------
$isStaging = $Server -match '\\DEVELOPMENT$'
if (-not $isStaging) {
    if (-not $Production) {
        throw "'$Server' is not the DEVELOPMENT (staging) instance. Add -Production to run against production."
    }
    $answer = Read-Host "This changes PRODUCTION ($Database on $Server). Type the server name '$Server' to continue"
    if ($answer -ne $Server) { throw 'Not confirmed. Nothing was run.' }
}

# ---- authentication ------------------------------------------------------------------------------------------
$auth = @('-E')
if ($SqlLogin) {
    $cred = Get-Credential -UserName $SqlLogin -Message "SQL login for $Server"
    $env:SQLCMDPASSWORD = $cred.GetNetworkCredential().Password    # read by sqlcmd; cleared at the end
    $auth = @('-U', $SqlLogin)
}

# ---- helpers -------------------------------------------------------------------------------------------------
function Get-Script([string]$path) {
    if (-not (Test-Path $path)) { throw "Script not found: $path" }
    return (Resolve-Path $path).Path
}

# Writes a temporary copy of a script with DECLARE values replaced (e.g. @Apply = 1).
function New-ScriptCopy([string]$path, [hashtable]$replace) {
    $text = [IO.File]::ReadAllText($path)
    foreach ($pattern in $replace.Keys) {
        $new = [regex]::Replace($text, $pattern, $replace[$pattern])
        if ($new -eq $text) { throw "Could not set '$pattern' in $(Split-Path $path -Leaf)." }
        $text = $new
    }
    $tmp = Join-Path $env:TEMP ("fitness-" + [IO.Path]::GetFileName($path))
    [IO.File]::WriteAllText($tmp, $text, (New-Object Text.UTF8Encoding $true))
    return $tmp
}

# Runs one script with sqlcmd and saves its output to logs.
# Returns the log path on success. On failure: throws, or with -Continue warns and returns $null.
function Invoke-Script([string]$path, [string]$label, [switch]$NoStopOnSqlError, [switch]$Continue) {
    $name = ($label -replace '\.sql$', '') -replace '[\\/:]', '_'
    $log  = Join-Path $logDir "$stamp-$name.log"
    Write-Host ""
    Write-Host "=== $label  ->  $Database on $Server" -ForegroundColor Cyan
    $sqlArgs = @('-S', $Server, '-d', $Database) + $auth + @('-I', '-f', '65001', '-i', $path)
    if (-not $NoStopOnSqlError) { $sqlArgs += '-b' }
    & sqlcmd @sqlArgs 2>&1 | Tee-Object -FilePath $log | Out-Host
    $code = $LASTEXITCODE
    Write-Host "    log: $log"
    if ($code -ne 0) {
        $msg = "$label failed (sqlcmd exit code $code). See $log."
        if ($Continue) { Write-Warning $msg; return $null }
        throw "$msg Later scripts were not run."
    }
    return $log
}

# ---- phases --------------------------------------------------------------------------------------------------
try {
    switch ($Phase) {

        'Audit' {
            Invoke-Script (Get-Script "$archive\00_usage_audit.sql") '00_usage_audit.sql' | Out-Null
        }

        'Test' {
            # 00c catches its own errors and reports them in its summary, so sqlcmd -b is not used here.
            $log = Invoke-Script (Get-Script "$archive\00c_test_procedure_fixes.sql") '00c_test_procedure_fixes.sql' -NoStopOnSqlError
            $bad = Select-String -Path $log -Pattern 'FIXED-ERROR|UNEXPECTED-DIFF|\bFAIL\b|^Msg \d+, Level (1[1-9]|2\d)' -CaseSensitive
            if ($bad) {
                $bad | ForEach-Object { Write-Host "    $($_.Line)" -ForegroundColor Yellow }
                throw "00c found $($bad.Count) problem line(s). Do not run -Phase Archive until they are understood."
            }
            Write-Host "`n00c: no FIXED-ERROR, UNEXPECTED-DIFF or FAIL lines. Next: -Phase Archive" -ForegroundColor Green
        }

        'Archive' {
            $testLogs = Get-ChildItem $logDir -Filter '*-00c_test_procedure_fixes.log' -ErrorAction SilentlyContinue
            if (-not $testLogs) { Write-Warning 'No 00c log found in db\scripts\logs. Run -Phase Test first unless you already have.' }
            Invoke-Script (Get-Script "$archive\00b_apply_procedure_fixes.sql") '00b_apply_procedure_fixes.sql' | Out-Null
            Invoke-Script (Get-Script "$archive\01_move_to_archive_schema.sql") '01_move_to_archive_schema.sql' | Out-Null
            Invoke-Script (Get-Script "$archive\01b_archive_gpx_tables.sql")    '01b_archive_gpx_tables.sql'    | Out-Null
            Write-Host "`nArchive done. Re-import the project, delete db\Fitness\src\archive, build, commit." -ForegroundColor Green
        }

        'Duration' {
            $views = Get-ChildItem (Join-Path $root 'views') -Filter '*.sql' | Sort-Object Name
            if ($views.Count -lt 8) {
                Write-Warning "Only $($views.Count) revised view(s) in db\scripts\views. Tables whose views are not revised yet will be refused by their rebuild script."
            }
            foreach ($v in $views) { Invoke-Script $v.FullName "views\$($v.Name)" | Out-Null }

            $failed = @()
            $tables = 'TrainingRide', 'TrainingRun', 'TrainingWalk', 'TreadmillRun', 'StationaryRide', 'Stairs',
                      'RecreationalRide', 'RecreationalRun', 'RecreationalWalk'
            foreach ($t in $tables) {
                $src = Get-Script (Join-Path $root "tables\rebuild_$t.sql")
                $set = @{}
                if ($Apply)              { $set['DECLARE @Apply\s+bit\s*=\s*0;']              = 'DECLARE @Apply bit = 1;' }
                if ($DropEvenIfDisagree) { $set['DECLARE @DropEvenIfDisagree\s+bit\s*=\s*0;'] = 'DECLARE @DropEvenIfDisagree bit = 1;' }
                $run = if ($set.Count) { New-ScriptCopy $src $set } else { $src }
                # Preview: check every table and report all problems. Apply: stop at the first failure
                # (each table is rebuilt in its own transaction; finished tables are skipped on a re-run).
                if ($Apply) { Invoke-Script $run "tables\rebuild_$t.sql" | Out-Null }
                elseif (-not (Invoke-Script $run "tables\rebuild_$t.sql" -Continue)) { $failed += $t }
            }
            if ($Apply) { Write-Host "`nTables rebuilt. Deploy the API, re-import the project, build, commit." -ForegroundColor Green }
            elseif ($failed.Count) { throw "Preview found problems in: $($failed -join ', '). Fix them (see the logs) before -Apply." }
            else { Write-Host "`nPreview passed for all nine tables. Run again with -Apply to rebuild." -ForegroundColor Green }
        }

        'Permissions' {
            if (-not $ServiceUser) { throw '-ServiceUser is required: the database user the .NET service connects as.' }
            $set = @{ "DECLARE @ServiceUser sysname = N'[^']*';" = "DECLARE @ServiceUser sysname = N'$($ServiceUser.Replace("'", "''"))';" }
            if ($Apply) { $set['DECLARE @Apply\s+bit\s*=\s*0;'] = 'DECLARE @Apply       bit     = 1;' }
            Invoke-Script (New-ScriptCopy (Get-Script "$archive\04_permissions.sql") $set) '04_permissions.sql' | Out-Null
            if (-not $Apply) { Write-Host "`nPreview only. Review the statements in the log, then run again with -Apply." -ForegroundColor Green }
        }

        'Drop' {
            $answer = Read-Host 'This permanently drops the archived procedures, functions and GPX tables. Type DROP to continue'
            if ($answer -ne 'DROP') { throw 'Not confirmed. Nothing was run.' }
            Invoke-Script (Get-Script "$archive\03_drop_archived_objects.sql") '03_drop_archived_objects.sql' | Out-Null
            Invoke-Script (Get-Script "$archive\03b_drop_gpx_tables.sql")      '03b_drop_gpx_tables.sql'      | Out-Null
        }

        'Rollback' {
            Invoke-Script (Get-Script "$archive\02b_rollback_gpx_archive.sql") '02b_rollback_gpx_archive.sql' | Out-Null
            Invoke-Script (Get-Script "$archive\02_rollback_archive.sql")      '02_rollback_archive.sql'      | Out-Null
        }
    }
}
finally {
    if ($SqlLogin) { Remove-Item Env:\SQLCMDPASSWORD -ErrorAction SilentlyContinue }
    Get-ChildItem $env:TEMP -Filter 'fitness-*.sql' -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
}
