<#
.SYNOPSIS
  Before/after benchmark for every folder in ..\problems.

.DESCRIPTION
  For each problem folder (sorted by name):
    1. unfix.sql  - put the database back in its untuned state
    2. prime.sql  - optional, e.g. compile a plan with a "typical" parameter (parameter sniffing)
    3. before.sql - 2 warm-up runs, then N measured runs
    4. fix.sql    - apply the fix (index, etc.); prime.sql again
    5. after.sql  - 2 warm-up runs, then N measured runs
    6. unfix.sql  - restore the baseline so problems stay independent
  Per run it records server CPU ms (delta of sys.dm_exec_sessions.cpu_time), logical reads (SET STATISTICS IO),
  client elapsed ms, row count and a SHA-256 of the full result set. Before and after must return the
  same hash, otherwise the fix changed the answer and the run is marked FAILED.
  The actual execution plan of one run per variant is saved to results\plans\*.sqlplan (open in SSMS).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File bench\Run-Benchmark.ps1 -Runs 10
#>
param(
    [string]$Server = "(localdb)\MSSQLLocalDB",
    [string]$Database = "GrocerySouqPerf",
    [int]$Runs = 10,
    [string]$Only = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$problemsDir = Join-Path $root "problems"
$resultsDir = Join-Path $root "results"
$plansDir = Join-Path $resultsDir "plans"
New-Item -ItemType Directory -Force $plansDir | Out-Null

$conn = New-Object System.Data.SqlClient.SqlConnection "Server=$Server;Database=$Database;Integrated Security=True;Application Name=TuningBenchmark"
# Logical reads come from SET STATISTICS IO messages (one line per table per statement, no double counting).
$script:ioMessages = New-Object System.Collections.Generic.List[string]
$conn.add_InfoMessage({ param($sender, $e) $script:ioMessages.Add($e.Message) })
$conn.FireInfoMessageEventOnUserErrors = $false
$conn.Open()

function Read-Sql([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Invoke-Batches([string]$sql) {
    if ([string]::IsNullOrWhiteSpace($sql)) { return }
    foreach ($batch in [regex]::Split($sql, '(?im)^\s*GO\s*$')) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $cmd = $conn.CreateCommand(); $cmd.CommandTimeout = 0; $cmd.CommandText = $batch
        [void]$cmd.ExecuteNonQuery()
    }
}

# Server CPU for this session (cumulative ms; updated when a batch completes).
function Get-SessionCpu {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT cpu_time FROM sys.dm_exec_sessions WHERE session_id = @@SPID"
    return [long]$cmd.ExecuteScalar()
}

function Get-LogicalReads([System.Collections.Generic.List[string]]$messages) {
    $total = 0L
    foreach ($m in $messages) {
        foreach ($match in [regex]::Matches($m, "(?<!lob )logical reads (\d+)")) { $total += [long]$match.Groups[1].Value }
    }
    return $total
}

function Invoke-Measured([string]$sql, [string]$planFile) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $sb = New-Object System.Text.StringBuilder
    $rows = 0

    $cmd = $conn.CreateCommand(); $cmd.CommandTimeout = 0
    if ($planFile) { $cmd.CommandText = "SET STATISTICS XML ON;`n" + $sql + "`nSET STATISTICS XML OFF;" }
    else { $cmd.CommandText = "SET STATISTICS IO ON;`n" + $sql + "`nSET STATISTICS IO OFF;" }

    $cpuBefore = Get-SessionCpu
    $script:ioMessages.Clear()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $reader = $cmd.ExecuteReader()
    $plans = New-Object System.Collections.Generic.List[string]
    do {
        $isPlan = ($reader.FieldCount -eq 1 -and $reader.GetName(0) -like "Microsoft SQL Server*XML Showplan")
        while ($reader.Read()) {
            if ($isPlan) { $plans.Add($reader.GetString(0)); continue }
            $rows++
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $v = $reader.GetValue($i)
                if ($v -is [datetime]) { $v = $v.ToString("yyyy-MM-ddTHH:mm:ss") }
                elseif ($v -is [decimal]) { $v = $v.ToString([System.Globalization.CultureInfo]::InvariantCulture) }
                [void]$sb.Append($v).Append('|')
            }
            [void]$sb.Append("`n")
        }
    } while ($reader.NextResult())
    $reader.Close()
    $sw.Stop()
    $reads = Get-LogicalReads $script:ioMessages
    $cpuAfter = Get-SessionCpu

    if ($planFile -and $plans.Count -gt 0) {
        # Keep the plan of the most expensive statement (the last SELECT in these batches).
        [System.IO.File]::WriteAllText($planFile, $plans[$plans.Count - 1], [System.Text.Encoding]::Unicode)
    }

    $hash = [BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))).Replace("-", "").Substring(0, 16)
    return [pscustomobject]@{
        CpuMs     = $cpuAfter - $cpuBefore
        Reads     = $reads
        ElapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
        Rows      = $rows
        Hash      = $hash
    }
}

function Get-Median($values) {
    $s = @($values | Sort-Object); $n = $s.Count
    if ($n -eq 0) { return 0 }
    if ($n % 2 -eq 1) { return $s[[int](($n - 1) / 2)] }
    return [math]::Round(($s[$n / 2 - 1] + $s[$n / 2]) / 2, 1)
}

function Measure-Variant($folder, [string]$name) {
    $sql = Read-Sql (Join-Path $folder.FullName "$name.sql")
    $prime = Read-Sql (Join-Path $folder.FullName "prime.sql")
    Invoke-Batches $prime
    1..2 | ForEach-Object { [void](Invoke-Measured $sql $null) }
    $planFile = Join-Path $plansDir ("{0}-{1}.sqlplan" -f $folder.Name, $name)
    $first = Invoke-Measured $sql $planFile
    # (PowerShell names are case-insensitive: don't call this $runs, it would overwrite the -Runs parameter.)
    $samples = @(); for ($i = 0; $i -lt $Runs; $i++) { $samples += Invoke-Measured $sql $null }
    $hashes = @($samples + $first | Select-Object -ExpandProperty Hash -Unique)
    return [pscustomobject]@{
        CpuMs     = Get-Median ($samples | ForEach-Object { $_.CpuMs })
        Reads     = Get-Median ($samples | ForEach-Object { $_.Reads })
        ElapsedMs = Get-Median ($samples | ForEach-Object { $_.ElapsedMs })
        Rows      = $first.Rows
        Hash      = ($hashes -join ",")
    }
}

$folders = Get-ChildItem $problemsDir -Directory | Sort-Object Name
if ($Only) { $folders = $folders | Where-Object { $_.Name -like "*$Only*" } }

Write-Host "Resetting every problem to its untuned state..."
foreach ($f in $folders) { Invoke-Batches (Read-Sql (Join-Path $f.FullName "unfix.sql")) }

$results = @()
foreach ($f in $folders) {
    Write-Host ("== {0}" -f $f.Name)
    $b = Measure-Variant $f "before"
    Invoke-Batches (Read-Sql (Join-Path $f.FullName "fix.sql"))
    $a = Measure-Variant $f "after"
    Invoke-Batches (Read-Sql (Join-Path $f.FullName "unfix.sql"))

    $same = ($b.Hash -eq $a.Hash) -and ($b.Hash -notmatch ",")
    $results += [pscustomobject]@{
        Problem        = $f.Name
        Rows           = $b.Rows
        ReadsBefore    = $b.Reads
        ReadsAfter     = $a.Reads
        CpuMsBefore    = $b.CpuMs
        CpuMsAfter     = $a.CpuMs
        ElapsedBefore  = $b.ElapsedMs
        ElapsedAfter   = $a.ElapsedMs
        SameResult     = $(if ($same) { "yes" } else { "FAILED" })
        Hash           = $b.Hash
    }
    $results[-1] | Format-List | Out-String | Write-Host
}
$conn.Close()

$stamp = Get-Date -Format "yyyy-MM-dd"
$results | Export-Csv (Join-Path $resultsDir "benchmark-$stamp.csv") -NoTypeInformation -Encoding UTF8

function Ratio($b, $a) { if ($a -le 0) { return "n/a" } ; return ("{0:N0}x" -f ($b / $a)) }
$md = @("# Benchmark results ($stamp)", "",
        "Median of $Runs warm runs per variant. Reads = logical reads; CPU = server CPU; Elapsed = client time incl. result transfer.", "",
        "| Problem | Rows | Reads before | Reads after | CPU ms before | CPU ms after | Elapsed ms before | Elapsed ms after | Same result |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---|")
foreach ($r in $results) {
    $md += "| {0} | {1:N0} | {2:N0} | {3:N0} ({4}) | {5:N0} | {6:N0} | {7:N1} | {8:N1} | {9} |" -f `
        $r.Problem, $r.Rows, $r.ReadsBefore, $r.ReadsAfter, (Ratio $r.ReadsBefore $r.ReadsAfter), $r.CpuMsBefore, $r.CpuMsAfter, $r.ElapsedBefore, $r.ElapsedAfter, $r.SameResult
}
[System.IO.File]::WriteAllLines((Join-Path $resultsDir "benchmark-$stamp.md"), $md, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("Saved results\benchmark-{0}.md / .csv and results\plans\" -f $stamp)
if ($results | Where-Object { $_.SameResult -ne "yes" }) { Write-Host "Some fixes changed the result!" -ForegroundColor Red; exit 1 }
