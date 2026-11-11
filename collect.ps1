# Delta Force data collector
#  - Tencent official: names, prices, images, gun base stats  -> every run
#  - dfttk game data : part stats, compatibility               -> only when its data version changes
#  - Steam           : global update signals (client build + official announcements)
# Writes everything into MySQL (database dfdb). Runs on Windows PowerShell 5.1 or later.
# Usage: run_collect.bat  (manual)  /  Task Scheduler (automatic)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# ---------------- settings ----------------
$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$MySql    = 'C:\Program Files\MySQL\MySQL Server 9.7\bin\mysql.exe'
$MyCnf    = Join-Path $Root 'mysql.cnf'          # DB account (user/password/database)
$DfttkUrl = 'https://dfttk.com/data/v3/'
$AmsUrl   = 'https://comm.ams.game.qq.com/ide/'
$SteamNewsUrl  = 'https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2507950&count=20'
$SteamCmdZip   = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip'   # Valve official SteamCMD
$SteamCmdDir   = Join-Path $Root 'steamcmd'
$KeepRunDirs = 5                                  # keep the last N download folders (dfttk versions are kept forever)
# overrides for testing
if ($env:DF_MYSQL)     { $MySql    = $env:DF_MYSQL }
if ($env:DF_DFTTK_URL) { $DfttkUrl = $env:DF_DFTTK_URL }
if ($env:DF_AMS_URL)   { $AmsUrl   = $env:DF_AMS_URL }
if ($env:DF_STEAM_NEWS_URL)  { $SteamNewsUrl  = $env:DF_STEAM_NEWS_URL }
if ($env:DF_STEAMCMD_OUTPUT) { $SteamCmdOutputForTest = $env:DF_STEAMCMD_OUTPUT }
# -----------------------------------------

$RunId  = Get-Date -Format 'yyyyMMdd-HHmmss'
$RunDir = Join-Path $Root "raw\$RunId"
New-Item -ItemType Directory -Force -Path (Join-Path $RunDir 'dfttk\weapons'), (Join-Path $RunDir 'official'), (Join-Path $RunDir 'steam') | Out-Null
$LogFile = Join-Path $Root 'collect.log'
$Utf8 = New-Object System.Text.UTF8Encoding $false
$script:Errors = 0

function Log([string]$m) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$RunId] $m"
  Write-Host $line
  [IO.File]::AppendAllText($LogFile, $line + "`r`n", $Utf8)
}

# run a .sql file through mysql.exe; returns stdout text, throws on error
function Invoke-SqlFile([string]$path, [switch]$Raw) {
  $out = Join-Path $RunDir 'mysql_out.txt'; $err = Join-Path $RunDir 'mysql_err.txt'
  $argList = @("--defaults-extra-file=`"$MyCnf`"", '--default-character-set=utf8mb4', '--batch', '--skip-column-names')
  if ($Raw) { $argList += '--raw' }
  $p = Start-Process -FilePath $MySql -NoNewWindow -Wait -PassThru `
        -ArgumentList $argList `
        -RedirectStandardInput $path -RedirectStandardOutput $out -RedirectStandardError $err
  $stdout = [IO.File]::ReadAllText($out, $Utf8)
  if ($p.ExitCode -ne 0) { throw "mysql failed ($($p.ExitCode)): $([IO.File]::ReadAllText($err, $Utf8))" }
  return $stdout
}
function Invoke-Sql([string]$sql, [switch]$Raw) {
  $f = Join-Path $RunDir 'query.sql'
  [IO.File]::WriteAllText($f, "SET NAMES utf8mb4;`n" + $sql, $Utf8)
  return (Invoke-SqlFile $f -Raw:$Raw).Trim()
}
function Q([string]$s) { return "'" + $s.Replace('\', '\\').Replace("'", "\'") + "'" }

# store one downloaded JSON file in raw_doc (sent as hex, so no escaping or encoding issues)
function Save-Raw([string]$source, [string]$kind, [string]$refId, [string]$file) {
  $bytes = [IO.File]::ReadAllBytes($file)
  $hex = [BitConverter]::ToString($bytes).Replace('-', '')
  $sql = "INSERT INTO raw_doc (run_id, source, kind, ref_id, body) VALUES ($(Q $RunId), $(Q $source), $(Q $kind), $(Q $refId), CONVERT(X'$hex' USING utf8mb4));"
  Invoke-Sql $sql | Out-Null
}

function Get-File([string]$url, [string]$path) {
  try {
    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -TimeoutSec 60
    return $true
  } catch { Log "ERR download $url :: $($_.Exception.Message)"; $script:Errors++; return $false }
}

function Test-Json([string]$path) {
  try { $null = [IO.File]::ReadAllText($path, $Utf8) | ConvertFrom-Json; return $true }
  catch { Log "ERR not valid JSON: $path"; $script:Errors++; return $false }
}

trap { Log "FATAL $($_.Exception.Message)"; exit 2 }
Log 'start'

# 0) make sure tables and procedures exist (safe to repeat)
Invoke-SqlFile (Join-Path $Root 'schema.sql') | Out-Null
Invoke-SqlFile (Join-Path $Root 'names_seed.sql') | Out-Null
Invoke-SqlFile (Join-Path $Root 'price_global_seed.sql') | Out-Null
Invoke-SqlFile (Join-Path $Root 'procedures.sql') | Out-Null
Invoke-SqlFile (Join-Path $Root 'export.sql') | Out-Null
Invoke-SqlFile (Join-Path $Root 'official_baseline_seed.sql') | Out-Null

# 1) Tencent official
$officialOk = 0
foreach ($primary in @('gun', 'acc')) {
  $file = Join-Path $RunDir "official\$primary.json"
  $param = '{"primary":"' + $primary + '","second":"","objectID":""}'
  $body = @{ iChartId = '352143'; iSubChartId = '352143'; sIdeToken = 'YWRywA'; source = '2'; method = 'dfm/object.list'; param = $param }
  try {
    Invoke-WebRequest -Uri $AmsUrl -Method Post -Body $body -Headers @{ Referer = 'https://df.qq.com/' } -OutFile $file -UseBasicParsing -TimeoutSec 60
    $j = [IO.File]::ReadAllText($file, $Utf8) | ConvertFrom-Json
    if ($j.ret -ne 0 -or -not $j.jData.data.data.list) { throw "unexpected response (ret=$($j.ret))" }
    Save-Raw 'official' $primary '' $file
    $officialOk++
    Log "official $primary : $(@($j.jData.data.data.list).Count) items"
  } catch { Log "ERR official $primary :: $($_.Exception.Message)"; $script:Errors++ }
  Start-Sleep -Milliseconds 500
}
if ($officialOk -gt 0) { Invoke-Sql "CALL sp_build_official($(Q $RunId));" | Out-Null; Log 'official built' }

# 2) dfttk - only when the data version is new
$newVersion = $false
$ver = $null
$manifestFile = Join-Path $RunDir 'dfttk\manifest.json'
if ((Get-File ($DfttkUrl + 'manifest.json') $manifestFile) -and (Test-Json $manifestFile)) {
  $m = [IO.File]::ReadAllText($manifestFile, $Utf8) | ConvertFrom-Json
  $ver = [string]$m.dataVersion
  # catalog files (weapon/ammo catalog, sol library), kept per data version for inspection
  $extraDir = Join-Path $Root "keep\dfttk_extra\$ver"
  if (-not (Test-Path $extraDir)) {
    New-Item -ItemType Directory -Force -Path $extraDir | Out-Null
    foreach ($rel in @([string]$m.entrypoints.weaponCatalog, [string]$m.entrypoints.ammoCatalog, [string]$m.entrypoints.library.sol)) {
      if (-not $rel) { continue }
      $okx = Get-File ($DfttkUrl + $rel) (Join-Path $extraDir ($rel -replace '/', '_'))
      Log "dfttk extra $rel : $okx"
    }
  }
  $known = Invoke-Sql "SELECT COUNT(*) FROM dfttk_version WHERE data_version = $(Q $ver);"
  if ($known -eq '0') {
    Log "dfttk new version $ver - downloading"
    $packs = @($m.weaponPacks.PSObject.Properties)
    $ok = $true
    $itemsFile = Join-Path $RunDir 'dfttk\items_zh-CN.json'
    $socketsFile = Join-Path $RunDir 'dfttk\sockets_zh-CN.json'
    if (-not ((Get-File ($DfttkUrl + 'locales/zh-CN/items.json') $itemsFile) -and (Test-Json $itemsFile))) { $ok = $false }
    if (-not ((Get-File ($DfttkUrl + 'locales/zh-CN/sockets.json') $socketsFile) -and (Test-Json $socketsFile))) { $ok = $false }
    foreach ($p in $packs) {
      if (-not $p.Value.build) { continue }
      $f = Join-Path $RunDir "dfttk\weapons\$($p.Name).json"
      if (-not ((Get-File ($DfttkUrl + $p.Value.build) $f) -and (Test-Json $f))) { $ok = $false }
      Start-Sleep -Milliseconds 300
    }
    if ($ok) {
      Save-Raw 'dfttk' 'manifest' '' $manifestFile
      Save-Raw 'dfttk' 'items' '' $itemsFile
      Save-Raw 'dfttk' 'sockets' '' $socketsFile
      foreach ($p in $packs) {
        $f = Join-Path $RunDir "dfttk\weapons\$($p.Name).json"
        if (Test-Path $f) { Save-Raw 'dfttk' 'weapon' $p.Name $f }
      }
      Invoke-Sql "CALL sp_build_dfttk($(Q $RunId));" | Out-Null
      $newVersion = $true
      $count = Invoke-Sql "SELECT COUNT(*) FROM weapon w JOIN dfttk_version d ON d.id = w.v WHERE d.data_version = $(Q $ver);"
      Log "dfttk $ver built: $count weapons"
      # official numbers right now = last season's: the starting point for this version's season merge
      Invoke-Sql "CALL sp_snapshot_official((SELECT id FROM dfttk_version WHERE data_version = $(Q $ver)));" | Out-Null
    } else {
      Log "dfttk $ver incomplete download - skipped, will retry next run"
    }
  } else {
    Log "dfttk $ver already stored"
  }
}

# 2b) dfttk weapon catalog: damage, armor damage, fire rate, fire modes, muzzle velocity
#     (fills a stored version once; also fills versions stored before this step existed)
if ($ver) {
  $missing = Invoke-Sql "SELECT COUNT(*) FROM weapon w JOIN dfttk_version d ON d.id = w.v WHERE d.data_version = $(Q $ver) AND w.dmg IS NULL;"
  if ($missing -and $missing -ne '0') {
    $catFile = Join-Path $RunDir 'dfttk\catalog_weapons.json'
    if ((Get-File ($DfttkUrl + [string]$m.entrypoints.weaponCatalog) $catFile) -and (Test-Json $catFile)) {
      if (-not $newVersion) { Save-Raw 'dfttk' 'manifest' '' $manifestFile }
      Save-Raw 'dfttk' 'weaponCatalog' '' $catFile
      $filled = Invoke-Sql "CALL sp_build_dfttk_catalog($(Q $RunId));"
      Log "dfttk $ver weapon catalog: $filled weapons"
    }
  }
}

# 3) Steam: official announcements + client build number
$newsFile = Join-Path $RunDir 'steam\news.json'
if ((Get-File $SteamNewsUrl $newsFile) -and (Test-Json $newsFile)) {
  Save-Raw 'steam' 'news' '' $newsFile
  Invoke-Sql "CALL sp_build_steam($(Q $RunId));" | Out-Null
}
# global client build number (public branch) via SteamCMD, anonymous login
function Get-SteamBuildId {
  $exe = Join-Path $SteamCmdDir 'steamcmd.exe'
  $outFile = Join-Path $RunDir 'steam\appinfo.txt'
  if ($SteamCmdOutputForTest) { Copy-Item $SteamCmdOutputForTest $outFile }
  else {
    if (-not (Test-Path $exe)) {
      New-Item -ItemType Directory -Force -Path $SteamCmdDir | Out-Null
      $zip = Join-Path $SteamCmdDir 'steamcmd.zip'
      Invoke-WebRequest -Uri $SteamCmdZip -OutFile $zip -UseBasicParsing -TimeoutSec 120
      Expand-Archive -Path $zip -DestinationPath $SteamCmdDir -Force
      Log 'steamcmd installed'
    }
    # SteamCMD updates itself on the first runs, so try up to 3 times
    for ($i = 1; $i -le 3; $i++) {
      $p = Start-Process -FilePath $exe -NoNewWindow -PassThru `
            -ArgumentList '+login anonymous +app_info_update 1 +app_info_print 2507950 +quit' `
            -RedirectStandardOutput $outFile -RedirectStandardError (Join-Path $RunDir 'steam\appinfo_err.txt')
      if (-not $p.WaitForExit(300000)) { $p.Kill(); Log 'steamcmd timeout' }
      $txt = [IO.File]::ReadAllText($outFile)
      if ($txt -match '"buildid"') { break }
    }
  }
  $txt = [IO.File]::ReadAllText($outFile)
  $m = [regex]::Match($txt, '"branches"\s*\{\s*"public"\s*\{[^}]*?"buildid"\s*"(\d+)"', 'Singleline')
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}
try {
  $build = Get-SteamBuildId
  if ($build) {
    # the first build ever seen is only a baseline, not an update
    $hasBuild = Invoke-Sql "SELECT COUNT(*) FROM global_signal WHERE kind = 'build';"
    $when = if ($hasBuild -eq '0') { "'2000-01-01 00:00:00'" } else { 'NOW()' }
    Invoke-Sql "INSERT IGNORE INTO global_signal (kind, value, detail, detected_at) VALUES ('build', $(Q $build), 'Steam public build', $when);" | Out-Null
    Log "steam build $build"
  } else { Log 'ERR steam build: buildid not found in SteamCMD output'; $script:Errors++ }
} catch { Log "ERR steam build :: $($_.Exception.Message)"; $script:Errors++ }

# 3b) global market prices from deltaforcetools.gg, once a day.
#     Its pages carry the market data as JSON (no official API, no game ids): items are matched to ours
#     once by name (its Traditional Chinese name -> Simplified) and the match is kept in dft_map.
$DftUrl = 'https://deltaforcetools.gg'
if ($env:DF_DFT_URL) { $DftUrl = $env:DF_DFT_URL }
function Get-DftAuction([string]$path, [string]$file) {
  Invoke-WebRequest -Uri ($DftUrl + $path) -Headers @{ 'RSC' = '1' } -OutFile $file -UseBasicParsing -TimeoutSec 90
  $t = [IO.File]::ReadAllText($file, $Utf8)
  $i = $t.IndexOf('"auctionData":')
  if ($i -lt 0) { throw "no auctionData in $path" }
  $start = $t.IndexOf('{', $i); $depth = 0; $inStr = $false; $j = $start
  $marks = [char[]]@('{', '}', '"', '\')
  while ($j -lt $t.Length) {
    $j = $t.IndexOfAny($marks, $j); if ($j -lt 0) { break }
    $ch = $t[$j]
    if ($inStr) { if ($ch -eq '\') { $j += 2; continue } elseif ($ch -eq '"') { $inStr = $false } }
    elseif ($ch -eq '"') { $inStr = $true }
    elseif ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { break } }
    $j++
  }
  $obj = $t.Substring($start, $j - $start + 1) | ConvertFrom-Json
  return @($obj.data)
}
try {
  $today = Get-Date -Format 'yyyy-MM-dd'
  $dftDir = Join-Path $Root "keep\dft\$today"
  if (-not (Test-Path (Join-Path $dftDir 'done.txt'))) {
    New-Item -ItemType Directory -Force -Path $dftDir | Out-Null
    Add-Type -AssemblyName Microsoft.VisualBasic
    $rows = New-Object System.Collections.ArrayList
    foreach ($cat in @(@('attachments', 'A'), @('firearms', 'F'))) {
      $en = Get-DftAuction "/auction-house/$($cat[0])?pageSize=1000" (Join-Path $dftDir "en_$($cat[0]).txt")
      $tw = Get-DftAuction "/tw/auction-house/$($cat[0])?pageSize=1000" (Join-Path $dftDir "tw_$($cat[0]).txt")
      # the English and Chinese lists are separate rows on the site: pair them by identical price history
      $twByHist = @{}
      foreach ($x in $tw) {
        if ($x.item_name -notmatch '[一-鿿]') { continue }   # the Chinese list also holds some Russian rows
        $h = ConvertTo-Json @($x.price_30d) -Compress
        if ($twByHist.ContainsKey($h)) { $twByHist[$h] = $null } else { $twByHist[$h] = $x }
      }
      foreach ($x in $en) {
        $h = ConvertTo-Json @($x.price_30d) -Compress
        $s = ''
        if ($twByHist.ContainsKey($h) -and $twByHist[$h]) {
          $s = [Microsoft.VisualBasic.Strings]::StrConv($twByHist[$h].item_name, [Microsoft.VisualBasic.VbStrConv]::SimplifiedChinese, 2052)
        }
        $u = [DateTime]::Parse(($x.updated_at -replace '^\$D', ''), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal)
        $u = $u.AddHours(9).ToString('yyyy-MM-dd HH:mm:ss')   # KST
        # prices it saw while the market recording was made (used to match items whose names differ)
        $seen = @($x.price_30d | Where-Object { $_.d -ge '2026-11-04 13:00' -and $_.d -le '2026-11-04 16:30' } | ForEach-Object { [long]$_.close })
        [void]$rows.Add([ordered]@{ k = $x.item_key; n = $x.item_name; s = $s; c = $cat[1]; p = [long][double]$x.current_price; u = $u; v = $seen })
      }
    }
    if ($rows.Count -lt 300) { throw "only $($rows.Count) items - site changed? prices left as they were" }
    $dftFile = Join-Path $dftDir 'rows.json'
    [IO.File]::WriteAllText($dftFile, (ConvertTo-Json @($rows) -Depth 4 -Compress), $Utf8)
    Save-Raw 'dft' 'auction' '' $dftFile
    $r = Invoke-Sql "CALL sp_load_dft($(Q $RunId));"
    [IO.File]::WriteAllText((Join-Path $dftDir 'done.txt'), $r, $Utf8)
    Log "global prices (deltaforcetools): $r"
  }
} catch { Log "ERR global prices (deltaforcetools) :: $($_.Exception.Message)"; $script:Errors++ }

# 4) decide versions for cn / global, clean up
Invoke-Sql "CALL sp_refresh_state();" | Out-Null
# global_pin.txt (optional): "<dfttk version><TAB>yyyy-MM-dd HH:mm" keeps the global server on that version until
# that local time, e.g. when the Steam pre-download and the season notice arrive days before the season starts.
$pinFile = Join-Path $Root 'global_pin.txt'
if (Test-Path $pinFile) {
  try {
    $pin = ([IO.File]::ReadAllText($pinFile, $Utf8)).Trim() -split "`t"
    $until = [datetime]::ParseExact($pin[1].Trim(), 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    if ((Get-Date) -lt $until) {
      $n = Invoke-Sql "UPDATE server_state st JOIN dfttk_version d ON d.data_version = $(Q $pin[0].Trim()) SET st.dfttk_version_id = d.id, st.updated_at = NOW(), st.note = 'pinned' WHERE st.server = 'global' AND (st.dfttk_version_id IS NULL OR st.dfttk_version_id <> d.id); SELECT ROW_COUNT();"
      if ("$n".Trim() -ne '0') { Log "global pinned to $($pin[0].Trim()) until $($pin[1].Trim())" }
    }
  } catch { Log "ERR global pin :: $($_.Exception.Message)"; $script:Errors++ }
}
Invoke-Sql "CALL sp_cleanup_raw($(Q $RunId));" | Out-Null
$state = Invoke-Sql "SELECT CONCAT(s.server, '=', IFNULL(d.data_version, '-')) FROM server_state s LEFT JOIN dfttk_version d ON d.id = s.dfttk_version_id ORDER BY s.server;"
Log ("servers: " + ($state -replace "`r?`n", ', '))

# 5) website data: web\data\{cn,global}\index.json and w\{weaponId}.json
function Write-Text([string]$path, [string]$text) {
  $tmp = $path + '.tmp'
  [IO.File]::WriteAllText($tmp, $text, $Utf8)
  Move-Item -Path $tmp -Destination $path -Force
}
foreach ($srv in @('cn', 'global')) {
  $dir = Join-Path $Root "web\data\$srv"
  New-Item -ItemType Directory -Force -Path (Join-Path $dir 'w') | Out-Null
  $idx = Invoke-Sql "CALL sp_export_index('$srv');" -Raw
  if (-not $idx) { Log "export $srv : no data yet"; continue }
  $n = 0
  foreach ($line in ((Invoke-Sql "CALL sp_export_weapons('$srv');" -Raw) -split "`r?`n")) {
    $tab = $line.IndexOf("`t")
    if ($tab -lt 1) { continue }
    Write-Text (Join-Path $dir ("w\" + $line.Substring(0, $tab) + '.json')) $line.Substring($tab + 1)
    $n++
  }
  Write-Text (Join-Path $dir 'index.json') $idx
  Log "export $srv : $n weapons"
}

# 6) pictures kept on this computer: the official ones (1200x600 PNG, ~200KB each, China CDN) are slow here.
#    web\img\w\{id}.png = gun picture as published, web\img\t\{id}.png = small gun picture for the weapon list,
#    web\img\p\{id}.png = small attachment picture (picker cards, slot boxes).
#    Downloaded when an item is new or its picture address changes. Once a day every picture's "Last-Modified" date
#    is asked (no download) and only pictures that changed are downloaded again, so pictures redrawn in a patch
#    follow. Pictures not published yet are tried again the next day. The website falls back to the official
#    address when a file is missing.
try {
  Add-Type -AssemblyName System.Drawing
  $imgDir = Join-Path $Root 'web\img'
  New-Item -ItemType Directory -Force -Path (Join-Path $imgDir 'w'), (Join-Path $imgDir 't'), (Join-Path $imgDir 'p') | Out-Null
  $srcFile = Join-Path $imgDir 'sources.txt'           # lines: kind:id<TAB>address<TAB>Last-Modified<TAB>checked yyyyMMdd
  $known = @{}
  if (Test-Path $srcFile) {
    foreach ($l in [IO.File]::ReadAllLines($srcFile, $Utf8)) {
      $p = $l.Split("`t"); if ($p.Count -eq 4) { $known[$p[0]] = @{ url = $p[1]; lm = $p[2]; day = $p[3] } }
    }
  }
  $today = Get-Date -Format 'yyyyMMdd'
  # 400 px wide copy of a downloaded picture
  function Save-Small([string]$from, [string]$to) {
    $im = $null; $bmp = $null; $g = $null
    try {
      $im = [Drawing.Image]::FromFile($from)
      $tw = 400; $th = [int][Math]::Round($im.Height * $tw / $im.Width)
      $bmp = New-Object Drawing.Bitmap $tw, $th, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
      $g = [Drawing.Graphics]::FromImage($bmp)
      $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $g.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
      $g.DrawImage($im, 0, 0, $tw, $th)
      $bmp.Save($to + '.tmp', [Drawing.Imaging.ImageFormat]::Png)
    } finally { if ($g) { $g.Dispose() }; if ($bmp) { $bmp.Dispose() }; if ($im) { $im.Dispose() } }
    Move-Item -Path ($to + '.tmp') -Destination $to -Force
  }
  # Last-Modified of a picture without downloading it ($null = not available)
  function Get-LastModified([string]$url) {
    $res = $null
    try {
      $req = [Net.HttpWebRequest]::Create($url); $req.Method = 'HEAD'; $req.Timeout = 30000
      $res = $req.GetResponse(); return [string]$res.Headers['Last-Modified']
    } catch { return $null } finally { if ($res) { $res.Close() } }
  }
  $guns = Invoke-Sql "SELECT w.weapon_id, w.image FROM weapon w JOIN (SELECT weapon_id, MAX(v) AS v FROM weapon GROUP BY weapon_id) m ON m.weapon_id = w.weapon_id AND m.v = w.v WHERE w.image LIKE 'http%';"
  # attachments a player can pick (the same rule as the website)
  $parts = Invoke-Sql "SELECT p.item_id, p.image FROM part p JOIN (SELECT item_id, MAX(v) AS v FROM part GROUP BY item_id) m ON m.item_id = p.item_id AND m.v = p.v WHERE p.image LIKE 'http%' AND (p.player_selectable = 1 OR EXISTS (SELECT 1 FROM official_item oi WHERE oi.object_id = p.item_id));"
  $new = 0; $changed = 0; $missing = 0
  foreach ($job in @(@('w', $guns), @('p', $parts))) {
    $kind = $job[0]
    foreach ($line in ($job[1] -split "`r?`n")) {
      $p = $line.Split("`t"); if ($p.Count -ne 2) { continue }
      $id = $p[0]; $url = $p[1]; $key = "$kind`:$id"
      if ($kind -eq 'w') { $files = @((Join-Path $imgDir "w\$id.png"), (Join-Path $imgDir "t\$id.png")) }
      else { $files = @((Join-Path $imgDir "p\$id.png")) }
      $have = -not ($files | Where-Object { -not (Test-Path $_) })
      $e = $known[$key]
      $same = $e -and $e.url -eq $url -and $have
      if ($same -and $e.day -eq $today) { continue }               # already checked today
      if (-not $have -and $e -and $e.url -eq $url -and $e.day -eq $today) { continue }   # not published: tomorrow
      if ($same) {
        # daily check: download again only when the picture changed
        $lm = Get-LastModified $url
        if (-not $lm -or $lm -eq $e.lm) { $e.day = $today; continue }
      }
      $tmp = Join-Path $RunDir "pic_$id.png"
      try {
        $res = Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 60 -PassThru
        Save-Small $tmp $files[-1]
        if ($kind -eq 'w') { Move-Item -Path $tmp -Destination $files[0] -Force } else { Remove-Item $tmp -ErrorAction SilentlyContinue }
        $known[$key] = @{ url = $url; lm = [string]$res.Headers['Last-Modified']; day = $today }
        if ($same) { $changed++ } else { $new++ }
      } catch {
        if (-not $have) { $missing++ }
        $known[$key] = @{ url = $url; lm = $(if ($e) { $e.lm } else { '' }); day = $today }
      }
    }
  }
  [IO.File]::WriteAllLines($srcFile, [string[]]($known.Keys | Sort-Object | ForEach-Object {
    $k = $known[$_]; "$_`t$($k.url)`t$($k.lm)`t$($k.day)" }), $Utf8)
  if ($new -or $changed -or $missing) { Log "pictures: $new new, $changed redrawn, $missing not available yet" }
} catch { Log "ERR pictures :: $($_.Exception.Message)"; $script:Errors++ }

# 6b) WebP copies of the pictures (several times smaller than PNG), made with Node.js + sharp (tools\webp.js).
#     Skipped when Node.js is not installed; the website then uses the PNG copies.
$nodeExe = Join-Path $env:ProgramFiles 'nodejs\node.exe'
$webpJs = Join-Path $Root 'tools\webp.js'
if ((Test-Path $nodeExe) -and (Test-Path $webpJs)) {
  try {
    $env:PATH = (Split-Path $nodeExe) + ';' + $env:PATH
    $toolDir = Join-Path $Root 'tools'
    if (-not (Test-Path (Join-Path $toolDir 'node_modules\sharp'))) {
      $o = Join-Path $RunDir 'npm_out.txt'; $e = Join-Path $RunDir 'npm_err.txt'
      $p = Start-Process -FilePath (Join-Path (Split-Path $nodeExe) 'npm.cmd') -ArgumentList "install --prefix `"$toolDir`" sharp@0.34 --no-fund --no-audit --loglevel=error" `
            -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
      $null = $p.Handle
      if (-not $p.WaitForExit(900000)) { $p.Kill(); throw 'sharp install timeout' }
      if (-not (Test-Path (Join-Path $toolDir 'node_modules\sharp'))) { throw ('sharp install: ' + (([IO.File]::ReadAllText($e) -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 3) -join ' / ')) }
      Log 'sharp installed'
    }
    $o = Join-Path $RunDir 'webp_out.txt'; $e = Join-Path $RunDir 'webp_err.txt'
    $p = Start-Process -FilePath $nodeExe -ArgumentList "`"$webpJs`"" -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
    $null = $p.Handle
    if (-not $p.WaitForExit(1800000)) { $p.Kill(); throw 'webp timeout' }
    $msg = ([IO.File]::ReadAllText($o)).Trim()
    if ($p.ExitCode -ne 0) { throw ($msg + ' ' + (([IO.File]::ReadAllText($e) -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 2) -join ' / ')) }
    if ($msg -notmatch 'webp: 0 made') { Log $msg }
  } catch { Log "ERR webp :: $($_.Exception.Message)"; $script:Errors++ }
}

# 6c) index.html loads app.js and style.css with a version taken from their content (app.js?v=1a2b3c4d5e), so a
#     browser that kept an older copy (Cloudflare tells browsers to keep them for hours) loads the new one at once.
try {
  $web = Join-Path $Root 'web'; $ix = Join-Path $web 'index.html'
  $html = [IO.File]::ReadAllText($ix, $Utf8); $orig = $html
  foreach ($f in @('app.js', 'style.css')) {
    $h = (Get-FileHash (Join-Path $web $f) -Algorithm SHA256).Hash.Substring(0, 10).ToLower()
    $html = [regex]::Replace($html, [regex]::Escape($f) + '(\?v=[0-9a-f]+)?"', "$f`?v=$h`"")
  }
  if ($html -ne $orig) { [IO.File]::WriteAllText($ix, $html, $Utf8) }
} catch { Log "ERR page version :: $($_.Exception.Message)"; $script:Errors++ }

# 6d) one page per weapon (web\w\<id>\index.html) and sitemap.xml, made from index.html by tools\pages.js.
#     Opening a weapon is then a real page view, and search engines can list each weapon.
if ((Test-Path $nodeExe) -and (Test-Path (Join-Path $Root 'tools\pages.js'))) {
  try {
    $o = Join-Path $RunDir 'pages_out.txt'; $e = Join-Path $RunDir 'pages_err.txt'
    $p = Start-Process -FilePath $nodeExe -ArgumentList "`"$(Join-Path $Root 'tools\pages.js')`"" -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
    $null = $p.Handle
    if (-not $p.WaitForExit(120000)) { $p.Kill(); throw 'pages timeout' }
    $msg = ([IO.File]::ReadAllText($o)).Trim()
    if ($p.ExitCode -ne 0) { throw ($msg + ' ' + (([IO.File]::ReadAllText($e) -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 2) -join ' / ')) }
    if ($msg -notmatch ', 0 written') { Log $msg }
  } catch { Log "ERR pages :: $($_.Exception.Message)"; $script:Errors++ }
}

# 7) publish the website on Cloudflare Pages. Runs only when cloudflare.txt exists next to this script (never inside
#    web\, which is published) with the lines  CLOUDFLARE_API_TOKEN=...  CLOUDFLARE_ACCOUNT_ID=...  and optionally
#    PROJECT=...  The token needs only the permission "Cloudflare Pages: Edit". Only changed files are uploaded.
$cfFile = Join-Path $Root 'cloudflare.txt'
if (Test-Path $cfFile) {
  try {
    $npm = Join-Path $env:ProgramFiles 'nodejs\npm.cmd'
    if (-not (Test-Path $npm)) { throw 'Node.js is not installed (https://nodejs.org, LTS)' }
    # npm and wrangler start "node": make sure it is found even when this window started before Node.js was installed
    $env:PATH = (Split-Path $npm) + ';' + $env:PATH
    # the upload tool (wrangler) is installed once into tools\ next to this script
    $toolDir = Join-Path $Root 'tools'
    $wrangler = Join-Path $toolDir 'node_modules\.bin\wrangler.cmd'
    if (-not (Test-Path $wrangler)) {
      New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
      $o = Join-Path $RunDir 'npm_out.txt'; $e = Join-Path $RunDir 'npm_err.txt'
      $p = Start-Process -FilePath $npm -ArgumentList "install --prefix `"$toolDir`" wrangler@4 --no-fund --no-audit --loglevel=error" `
            -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
      if (-not $p.WaitForExit(900000)) { $p.Kill(); throw 'wrangler install timeout' }
      if (-not (Test-Path $wrangler)) { throw ('wrangler install: ' + (([IO.File]::ReadAllText($e) -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 3) -join ' / ')) }
      Log 'wrangler installed'
    }
    # last meaningful lines of a tool's output (npm notices left out)
    function Last-Lines([string]$t) { ($t -split "`r?`n" | Where-Object { $_ -match '\S' -and $_ -notmatch '^npm (notice|warn)' } | Select-Object -Last 3) -join ' / ' }
    $cf = @{}
    foreach ($l in [IO.File]::ReadAllLines($cfFile)) { if ($l -match '^\s*([A-Z_]+)\s*=\s*(\S+)\s*$') { $cf[$Matches[1]] = $Matches[2] } }
    if (-not $cf['CLOUDFLARE_API_TOKEN'] -or -not $cf['CLOUDFLARE_ACCOUNT_ID']) { throw 'cloudflare.txt needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID' }
    $project = if ($cf['PROJECT']) { $cf['PROJECT'] } else { 'df-gunsmith' }
    $env:CLOUDFLARE_API_TOKEN = $cf['CLOUDFLARE_API_TOKEN']; $env:CLOUDFLARE_ACCOUNT_ID = $cf['CLOUDFLARE_ACCOUNT_ID']
    $env:WRANGLER_SEND_METRICS = 'false'
    function Invoke-Wrangler([string]$arguments) {
      $o = Join-Path $RunDir 'wrangler_out.txt'; $e = Join-Path $RunDir 'wrangler_err.txt'
      $p = Start-Process -FilePath $wrangler -ArgumentList $arguments -NoNewWindow -PassThru `
            -RedirectStandardOutput $o -RedirectStandardError $e
      $null = $p.Handle      # keeps the process handle so ExitCode is filled in (PowerShell Start-Process quirk)
      if (-not $p.WaitForExit(900000)) { $p.Kill(); throw 'wrangler timeout' }
      return @{ code = $p.ExitCode; text = ([IO.File]::ReadAllText($o) + "`n" + [IO.File]::ReadAllText($e)) }
    }
    # first time: create the project (production branch main)
    $mark = Join-Path $Root "keep\cf_project_$project.txt"
    if (-not (Test-Path $mark)) {
      $r = Invoke-Wrangler "pages project create $project --production-branch main"
      if ($r.code -ne 0 -and $r.text -notmatch 'Successfully created|already exists') { throw ('project create: ' + (Last-Lines $r.text)) }
      [IO.File]::WriteAllText($mark, (Get-Date -Format 's'), $Utf8)
      Log "cloudflare pages project $project ready"
    }
    $r = Invoke-Wrangler ("pages deploy `"" + (Join-Path $Root 'web') + "`" --project-name $project --branch main --commit-dirty=true")
    if ($r.code -ne 0 -or $r.text -notmatch 'Deployment complete|Success') { throw (Last-Lines $r.text) }
    Log ("published " + ([regex]::Match($r.text, 'https://\S+\.pages\.dev')).Value)
  } catch { Log "ERR publish :: $($_.Exception.Message)"; $script:Errors++ }
  finally { Remove-Item Env:CLOUDFLARE_API_TOKEN, Env:CLOUDFLARE_ACCOUNT_ID -ErrorAction SilentlyContinue }
}

# keep only the last few download folders, plus the folders of the two newest dfttk versions
# (every version stays in the database; the folders are only for looking at the files)
$keep = @((Invoke-Sql "SELECT run_id FROM dfttk_version ORDER BY id DESC LIMIT 2;") -split "`r?`n" | Where-Object { $_ })
Get-ChildItem (Join-Path $Root 'raw') -Directory | Sort-Object Name -Descending | Select-Object -Skip $KeepRunDirs |
  Where-Object { $keep -notcontains $_.Name } | Remove-Item -Recurse -Force
# daily deltaforcetools downloads: 14 days
Get-ChildItem (Join-Path $Root 'keep\dft') -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' -and $_.Name -lt (Get-Date).AddDays(-14).ToString('yyyy-MM-dd') } |
  Remove-Item -Recurse -Force
# log: when it passes 5 MB it becomes collect.old.log (the previous old log is dropped)
if ((Get-Item $LogFile).Length -gt 5MB) { Move-Item -Path $LogFile -Destination (Join-Path $Root 'collect.old.log') -Force }
Remove-Item (Join-Path $RunDir 'query.sql'), (Join-Path $RunDir 'mysql_out.txt'), (Join-Path $RunDir 'mysql_err.txt') -ErrorAction SilentlyContinue

Log "done ($script:Errors errors)"
if ($script:Errors -gt 0) { exit 1 }
