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
                   01_move_to_archive_schema.sql               move procedures to the [archive] schema (not GetLastEntries)
                   01c_restore_GetLastEntries.sql              move GetLastEntries back to dbo if it was archived
                   01b_archive_gpx_tables.sql                  move the six legacy GPX tables to [archive]
      DataFix      tables\00_fix_duration_data.sql             preview only, unless -Apply; data corrections before Duration
      Duration     views\*.sql                                 revised report views
                   tables\rebuild_<Table>.sql (nine tables)    preview only, unless -Apply
      Permissions  04_permissions.sql                          preview only, unless -Apply; needs -ServiceUser
      Fix          fixes\<Script>.sql                          one script from db\scripts\fixes; preview unless -Apply
      ArchiveDb    05_copy_archive_to_database.sql             copy the [archive] schema to the FitnessArchive database
                                                               and compare; preview unless -Apply
      Drop         06_drop_archive_schema.sql                  drop [archive] from Fitness once FitnessArchive matches;
                                                               preview unless -Apply (replaces 03 and 03b)
      Rollback     02b_rollback_gpx_archive.sql, 02_rollback_archive.sql   undo Archive (not possible after Drop)

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
    .\Run-FitnessScripts.ps1 -Phase Fix -Script S8_indexes            # preview
    .\Run-FitnessScripts.ps1 -Phase Fix -Script S8_indexes -Apply
.EXAMPLE
    .\Run-FitnessScripts.ps1 -Phase ArchiveDb -Apply   # create FitnessArchive and copy [archive] into it
    .\Run-FitnessScripts.ps1 -Phase Drop               # check the copy
    .\Run-FitnessScripts.ps1 -Phase Drop -Apply        # drop [archive] from Fitness
.EXAMPLE
    .\Run-FitnessScripts.ps1 -Phase Archive -Server . -Production
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Audit', 'Test', 'Archive', 'DataFix', 'Duration', 'Permissions', 'Fix', 'ArchiveDb', 'Drop', 'Rollback')]
    [string]$Phase,

    [string]$Server = '.\DEVELOPMENT',
    [string]$Database = 'Fitness',

    # Make changes in the phases that preview by default (DataFix, Duration, Permissions, Fix, ArchiveDb, Drop).
    [switch]$Apply,

    # Database user the .NET service connects as (Permissions phase).
    [string]$ServiceUser,

    # Fix phase: the script in db\scripts\fixes to run, without .sql (e.g. S8_indexes).
    [string]$Script,

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
        # Fail only when the setting isn't in the script; replacing a value with the same value is fine.
        if (-not [regex]::IsMatch($text, $pattern)) { throw "Could not find '$pattern' in $(Split-Path $path -Leaf)." }
        $text = [regex]::Replace($text, $pattern, $replace[$pattern].Replace('$', '$$'))
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
            Invoke-Script (Get-Script "$archive\01c_restore_GetLastEntries.sql") '01c_restore_GetLastEntries.sql' | Out-Null
            Invoke-Script (Get-Script "$archive\01b_archive_gpx_tables.sql")    '01b_archive_gpx_tables.sql'    | Out-Null
            Write-Host "`nArchive done. Re-import the project, delete db\Fitness\src\archive, build, commit." -ForegroundColor Green
        }

        'DataFix' {
            $src = Get-Script (Join-Path $root 'tables\00_fix_duration_data.sql')
            $run = if ($Apply) { New-ScriptCopy $src @{ 'DECLARE @Apply\s+bit\s*=\s*0;' = 'DECLARE @Apply bit = 1;' } } else { $src }
            Invoke-Script $run 'tables\00_fix_duration_data.sql' | Out-Null
            if ($Apply) { Write-Host "`nData corrected. Next: -Phase Duration (preview)." -ForegroundColor Green }
            else { Write-Host "`nPreview only. Review the rows in the log, then run again with -Apply." -ForegroundColor Green }
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
            $set = @{ "DECLARE @ServiceUser\s+sysname\s*=\s*N'[^']*';" = "DECLARE @ServiceUser sysname = N'$($ServiceUser.Replace("'", "''"))';" }
            if ($Apply) { $set['DECLARE @Apply\s+bit\s*=\s*0;'] = 'DECLARE @Apply       bit     = 1;' }
            Invoke-Script (New-ScriptCopy (Get-Script "$archive\04_permissions.sql") $set) '04_permissions.sql' | Out-Null
            if (-not $Apply) { Write-Host "`nPreview only. Review the statements in the log, then run again with -Apply." -ForegroundColor Green }
        }

        'Fix' {
            if (-not $Script) { throw '-Script is required: the name of a script in db\scripts\fixes, e.g. -Script S8_indexes.' }
            $src = Get-Script (Join-Path $root "fixes\$($Script -replace '\.sql$', '').sql")
            $hasApply = [regex]::IsMatch([IO.File]::ReadAllText($src), 'DECLARE @Apply\s+bit\s*=\s*0;')
            if ($Apply -and -not $hasApply) { throw "$Script has no @Apply setting; run it without -Apply." }
            $run = if ($Apply) { New-ScriptCopy $src @{ 'DECLARE @Apply\s+bit\s*=\s*0;' = 'DECLARE @Apply bit = 1;' } } else { $src }
            Invoke-Script $run "fixes\$(Split-Path $src -Leaf)" | Out-Null
            if ($hasApply -and -not $Apply) { Write-Host "`nPreview only. Review the output, then run again with -Apply." -ForegroundColor Green }
        }

        'ArchiveDb' {
            $src = Get-Script "$archive\05_copy_archive_to_database.sql"
            $run = if ($Apply) { New-ScriptCopy $src @{ 'DECLARE @Apply\s+bit\s*=\s*0;' = 'DECLARE @Apply  bit     = 1;' } } else { $src }
            Invoke-Script $run '05_copy_archive_to_database.sql' | Out-Null
            if ($Apply) { Write-Host "`nFitnessArchive matches [archive]. Next: extract and build the FitnessArchive project, then -Phase Drop (preview)." -ForegroundColor Green }
            else { Write-Host "`nPreview only. Review the list, then run again with -Apply." -ForegroundColor Green }
        }

        'Drop' {
            $src = Get-Script "$archive\06_drop_archive_schema.sql"
            if ($Apply) {
                $answer = Read-Host 'This drops the [archive] schema and everything in it from Fitness (FitnessArchive keeps the copy). Back up both databases first. Type DROP to continue'
                if ($answer -ne 'DROP') { throw 'Not confirmed. Nothing was run.' }
                $run = New-ScriptCopy $src @{ 'DECLARE @Apply\s+bit\s*=\s*0;' = 'DECLARE @Apply  bit     = 1;' }
            } else { $run = $src }
            Invoke-Script $run '06_drop_archive_schema.sql' | Out-Null
            if (-not $Apply) { Write-Host "`nCheck only. If every object says 'copy OK', back up both databases and run again with -Apply." -ForegroundColor Green }
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
