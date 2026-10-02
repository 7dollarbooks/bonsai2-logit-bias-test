# 50-question MATH-500 pass against the local Bonsai server.
# Run ON the Nitro, with llama-server already listening on 127.0.0.1:8080.
#   powershell -ExecutionPolicy Bypass -File C:\Qu_models\bonsai\experiments\logit-bias-2026-10-02\run_math500.ps1 -Run A
param(
    [ValidateSet("A", "B")]
    [string]$Run = "A"
)

$ErrorActionPreference = "Stop"
$root = "C:\Qu_models\bonsai\experiments\logit-bias-2026-10-02"
$jsonl = Join-Path $root "math500-test.jsonl"
$picked = Join-Path $root "questions-50.json"
$rawDir = Join-Path $root "raw-$Run"
New-Item -ItemType Directory -Force -Path $root, $rawDir | Out-Null

if (-not (Test-Path $jsonl)) {
    Write-Host "Downloading MATH-500 test split"
    & curl.exe -L --fail --retry 5 -o $jsonl "https://huggingface.co/datasets/HuggingFaceH4/MATH-500/resolve/main/test.jsonl"
    if ($LASTEXITCODE -ne 0) { throw "MATH-500 download failed" }
}

function Get-Boxed([string]$text) {
    if (-not $text) { return "" }
    $key = "\boxed{"
    $i = $text.LastIndexOf($key)
    if ($i -lt 0) { return "" }
    $start = $i + $key.Length
    $depth = 1
    for ($j = $start; $j -lt $text.Length; $j++) {
        $c = $text[$j]
        if ($c -eq "{") { $depth++ }
        elseif ($c -eq "}") {
            $depth--
            if ($depth -eq 0) { return $text.Substring($start, $j - $start) }
        }
    }
    return ""
}

function Norm([string]$s) {
    if (-not $s) { return "" }
    $s = $s.Trim()
    $s = $s -replace "\\left", "" -replace "\\right", ""
    $s = $s -replace "[`$]", ""
    $s = $s -replace "\s+", ""
    return $s
}

if (-not (Test-Path $picked)) {
    $all = Get-Content $jsonl -Encoding UTF8 | ForEach-Object { $_ | ConvertFrom-Json }
    $rng = [System.Random]::new(42)
    $order = $all | ForEach-Object { [pscustomobject]@{ item = $_; k = $rng.Next() } } |
        Sort-Object k, { $_.item.unique_id }
    $chosen = @($order | Select-Object -First 50 | ForEach-Object { $_.item })
    $chosen | ConvertTo-Json -Depth 6 | Set-Content $picked -Encoding UTF8
    Write-Host "Saved 50 question ids to $picked"
}

function Write-Utf8([string]$Path, [string]$Text) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

$parsed = Get-Content $picked -Encoding UTF8 -Raw | ConvertFrom-Json
if ($parsed.unique_id -is [System.Array]) {
    $questions = for ($i = 0; $i -lt @($parsed.unique_id).Count; $i++) {
        [pscustomobject]@{
            problem   = @($parsed.problem)[$i]
            solution  = @($parsed.solution)[$i]
            answer    = @($parsed.answer)[$i]
            subject   = @($parsed.subject)[$i]
            level     = @($parsed.level)[$i]
            unique_id = @($parsed.unique_id)[$i]
        }
    }
} else {
    $questions = @($parsed)
}
Write-Host ("Loaded {0} questions" -f @($questions).Count)
if (@($questions).Count -ne 50) { throw "Expected 50 questions, got $(@($questions).Count)" }
$csv = Join-Path $root "results-$Run.csv"
$rows = @()
$n = 0
foreach ($q in $questions) {
    $n++
    $rawPath = Join-Path $rawDir ("{0:D2}.json" -f $n)
    $qid = [string]$q.unique_id
    if (Test-Path $rawPath) {
    Write-Host "$n/50 skip $qid"
    $rawText = [IO.File]::ReadAllText($rawPath)
    $depth = 0
    $started = $false
    $end = 0
    for ($c = 0; $c -lt $rawText.Length; $c++) {
        $ch = $rawText[$c]
        if ($ch -eq '{') { $depth++; $started = $true }
        elseif ($ch -eq '}') {
            $depth--
            if ($started -and $depth -eq 0) { $end = $c; break }
        }
    }
    $prev = $rawText.Substring(0, $end + 1) | ConvertFrom-Json
    if ($prev.row) { $rows += [pscustomobject]$prev.row } else { $rows += $prev }
    continue
}
    $prompt = "Solve this problem. Put the final answer in \boxed{}." + "`n`n" + [string]$q.problem
    # Windows PowerShell turns a one-item array into an object. The server requires a list.
    $msg = @{ role = "user"; content = $prompt } | ConvertTo-Json -Compress -Depth 5
    $body = '{"temperature":0,"top_p":0.95,"max_tokens":3072,"seed":42,"messages":[' + $msg + ']}'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod "http://127.0.0.1:8080/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 900
        $sw.Stop()
        $text = [string]$resp.choices[0].message.content
        $boxed = Get-Boxed $text
        $ok = $(if ((Norm $boxed) -ne "" -and (Norm $boxed) -eq (Norm ([string]$q.answer))) { 1 } else { 0 })
        $comp = 0
        if ($resp.usage.completion_tokens) { $comp = [int]$resp.usage.completion_tokens }
        $sec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        $tps = $(if ($sec -gt 0) { [math]::Round($comp / $sec, 2) } else { 0 })
        $trunc = $(if ($resp.choices[0].finish_reason -eq "length" -or $comp -ge 3072) { 1 } else { 0 })
        $row = [ordered]@{
            n                 = $n
            unique_id         = $qid
            answer            = [string]$q.answer
            boxed             = $boxed
            correct           = $ok
            completion_tokens = $comp
            wall_sec          = $sec
            tokens_per_sec    = $tps
            truncated         = $trunc
            error             = ""
        }
        Write-Utf8 $rawPath (($row | ConvertTo-Json -Depth 6) + "`n" + ($resp | ConvertTo-Json -Depth 12))
        $rows += [pscustomobject]$row
        Write-Host ("{0}/50 correct={1} tokens={2} t/s={3} trunc={4} {5}" -f $n, $ok, $comp, $tps, $trunc, $qid)
    } catch {
        $sw.Stop()
        $err = "$_"
        Write-Host "$n/50 ERROR $qid $err"
        $row = [ordered]@{
            n                 = $n
            unique_id         = $qid
            answer            = [string]$q.answer
            boxed             = ""
            correct           = 0
            completion_tokens = 0
            wall_sec          = [math]::Round($sw.Elapsed.TotalSeconds, 2)
            tokens_per_sec    = 0
            truncated         = 0
            error             = $err
        }
        Write-Utf8 $rawPath ($row | ConvertTo-Json -Depth 6)
        $rows += [pscustomobject]$row
    }
}

$rows | Export-Csv $csv -NoTypeInformation -Encoding UTF8
$sumCorrect = ($rows | Measure-Object correct -Sum).Sum
$avgTok = ($rows | Measure-Object completion_tokens -Average).Average
$avgTps = ($rows | Measure-Object tokens_per_sec -Average).Average
$sumTrunc = ($rows | Measure-Object truncated -Sum).Sum
$summary = "run=$Run n=$($rows.Count) correct=$sumCorrect avg_tokens=$([math]::Round($avgTok,1)) avg_tps=$([math]::Round($avgTps,2)) truncations=$sumTrunc"
$summary | Tee-Object (Join-Path $root "summary-$Run.txt")