# gh-api.ps1 — GitHub REST بمررير مفتاح عبر stdin فقط: لا يُكتب على قرص ولا يظهر في argv.
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/gh-api.ps1 -Method GET -Path "repos/yahya2208/elfakir"
#   ... -Method PATCH -Path "repos/.../branches/main/protection" -BodyFile protection.json
# curl لأن PowerShell 5.1 لا يصل api.github.com مباشرةً على هذا الجهاز.
param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$BodyFile = ''
)
$ErrorActionPreference = 'Stop'

# المفتاح من نفس مسار المصادقة الذي نجح به git push (GCM)، ويُستهلك في الذاكرة فقط
$raw = ("protocol=https`nhost=github.com`n`n" | & git credential fill) -join "`n"
$token = ($raw -split "`n" | Where-Object { $_ -like 'password=*' } | Select-Object -First 1) -replace '^password=', ''
$token = $token.Trim()
if ($token.Length -lt 20) { throw 'NO_TOKEN: git credential fill لم يُرجع مفتاحًا صالحًا' }

$headers = @(
    "Authorization: Bearer $token",
    'Accept: application/vnd.github+json',
    'X-GitHub-Api-Version: 2022-11-28',
    'User-Agent: ef-phase0-guard'
) -join "`n"

try {
    $cargs = @('-s', '-S', '--retry', '6', '--retry-connrefused', '--retry-delay', '3', '--connect-timeout', '10', '--max-time', '60', '-X', $Method, '-H', '@-', '-w', "`nHTTP_CODE %{http_code}")
    if ($BodyFile -ne '') { $cargs += @('--data-binary', "@$BodyFile") }
    # العناوين تمر عبر stdin وحدها، والنتيجة تُطبع مباشرةً
    $headers | & curl.exe @cargs "https://api.github.com/$Path"
    Write-Output ''
}
finally {
}
