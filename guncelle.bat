@echo off
chcp 65001 >nul
title Create: Blood, Sweat ^& Oil - Guncelleme
set "BAT_YOLU=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:BAT_YOLU,[Text.Encoding]::UTF8); iex $s.Substring($s.IndexOf('#PS'+'BASLA#'))"
echo.
pause
exit /b
#PSBASLA#
# ---------------------------------------------------------------------------
#  Create: Blood, Sweat & Oil guncelleyici
#  Bu dosyayi CurseForge profil klasorune koy (profil > sag tik > Open Folder)
#  ve oyunu acmadan once cift tikla. Kendi ayarlarina (tuslar, gorus mesafesi,
#  harita, dunyalar) dokunmaz. Her guncellemeden once kubejs ve config yedeklenir.
# ---------------------------------------------------------------------------
$DEPO = 'TeomanOzbakir/guncelleme_yayin'   # GitHub: kullanici-adi/depo-adi

$ErrorActionPreference = 'Stop'
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  # raw.githubusercontent.com 'main' adresini ~5 dk onbellekte tutuyor (?t= ise yaramiyor).
  # Bu yuzden once en son commit'in kimligi alinir ve dosyalar o commit'in sabit adresinden indirilir.
  $REF = 'main'
  try {
    $c = Invoke-RestMethod -Uri "https://api.github.com/repos/$DEPO/commits/main" -Headers @{ 'User-Agent' = 'modpack-guncelleyici' } -UseBasicParsing
    if ($c.sha -match '^[0-9a-f]{40}$') { $REF = $c.sha }
  } catch { Write-Host '(GitHub API yanit vermedi, onbellekli adres kullaniliyor)' -ForegroundColor DarkGray }
  $SURUM_URL = "https://raw.githubusercontent.com/$DEPO/$REF/surum.txt"
  $PAKET_URL = "https://raw.githubusercontent.com/$DEPO/$REF/guncelleme.zip"
  $kok = Split-Path -Parent $env:BAT_YOLU
  Write-Host '=== Create: Blood, Sweat & Oil guncelleyici ===' -ForegroundColor Cyan
  if (-not (Test-Path -LiteralPath (Join-Path $kok 'mods')) -or -not (Test-Path -LiteralPath (Join-Path $kok 'config'))) {
    throw 'Bu dosyayi CurseForge profil klasorune koy (icinde mods ve config olan klasor). CurseForge: profil > sag tik > Open Folder.'
  }
  if ($DEPO -like 'BURAYA*') { throw 'Indirme baglantilari henuz ayarlanmamis.' }
  $acik = @()
  try { $acik = @(Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($kok) }) } catch { }
  if ($acik.Count -gt 0) {
    Write-Host 'Bu profilin oyunu acik. Once oyunu tamamen kapat, sonra tekrar calistir.' -ForegroundColor Yellow
    return
  }
  $yerelDosya = Join-Path $kok '.guncelleme_surum'
  $yerel = 0
  if (Test-Path -LiteralPath $yerelDosya) { $yerel = [int]((Get-Content -LiteralPath $yerelDosya -Raw).Trim()) }

  $tmp = Join-Path $env:TEMP 'silah_guncelleme'
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  Invoke-WebRequest -Uri $SURUM_URL -OutFile "$tmp\surum.txt" -UseBasicParsing
  $metin = (Get-Content -LiteralPath "$tmp\surum.txt" -Raw).Trim()
  if ($metin -notmatch '^\d+$') { throw 'Surum bilgisi okunamadi (baglanti calismiyor olabilir).' }
  $uzak = [int]$metin
  if ($uzak -le $yerel) { Write-Host "Guncelsin (surum $yerel). Oyunu acabilirsin." -ForegroundColor Green; return }

  Write-Host "Yeni surum $uzak indiriliyor (sendeki: $yerel)..."
  Invoke-WebRequest -Uri $PAKET_URL -OutFile "$tmp\paket.zip" -UseBasicParsing
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $ac = "$tmp\paket"
  try { [IO.Compression.ZipFile]::ExtractToDirectory("$tmp\paket.zip", $ac) } catch { throw 'Indirilen paket acilamadi (baglanti calismiyor olabilir).' }
  if (-not (Test-Path -LiteralPath "$ac\kubejs_liste.txt")) { throw 'Indirilen paket eksik.' }

  # Yedek (son 3 yedek tutulur)
  $yedekKok = Join-Path $kok 'guncelleme_yedek'
  $yedek = Join-Path $yedekKok (Get-Date -Format 'yyyyMMdd_HHmmss')
  New-Item -ItemType Directory -Force -Path $yedek | Out-Null
  foreach ($d in 'kubejs','config','defaultconfigs') { $p = Join-Path $kok $d; if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $yedek $d) -Recurse } }
  Get-ChildItem -LiteralPath $yedekKok -Directory | Sort-Object Name -Descending | Select-Object -Skip 3 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
  Write-Host "Yedek alindi: $yedek"

  # kubejs: pakette olmayan dosyalari sil (kubejs/config haric)
  $liste = @{}
  Get-Content -LiteralPath "$ac\kubejs_liste.txt" -Encoding UTF8 | ForEach-Object { if ($_.Trim()) { $liste[$_.Trim()] = 1 } }
  $kjs = Join-Path $kok 'kubejs'
  if (Test-Path -LiteralPath $kjs) {
    Get-ChildItem -LiteralPath $kjs -Recurse -File | ForEach-Object {
      $rel = 'kubejs/' + ($_.FullName.Substring($kjs.Length + 1) -replace '\\', '/')
      if ($rel -notlike 'kubejs/config/*' -and -not $liste.ContainsKey($rel)) { Remove-Item -LiteralPath $_.FullName -Force }
    }
  }
  # Yeni dosyalari kopyala
  $adet = 0
  foreach ($d in 'kubejs','config','defaultconfigs','mods') {
    $s = Join-Path $ac $d
    if (-not (Test-Path -LiteralPath $s)) { continue }
    Get-ChildItem -LiteralPath $s -Recurse -File | ForEach-Object {
      $dst = Join-Path (Join-Path $kok $d) $_.FullName.Substring($s.Length + 1)
      $klasor = Split-Path -Parent $dst
      if (-not (Test-Path -LiteralPath $klasor)) { New-Item -ItemType Directory -Force -Path $klasor | Out-Null }
      Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
      $adet++
    }
  }
  # Kaldirilan modlar
  if (Test-Path -LiteralPath "$ac\mods_sil.txt") {
    Get-Content -LiteralPath "$ac\mods_sil.txt" -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object {
      $desen = $_.Trim()
      Get-ChildItem -LiteralPath (Join-Path $kok 'mods') -File | Where-Object { $_.Name -like $desen -and -not (Test-Path -LiteralPath (Join-Path "$ac\mods" $_.Name)) } | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force; Write-Host "  mod silindi: $($_.Name)" }
    }
  }
  Set-Content -LiteralPath $yerelDosya -Value "$uzak"
  Write-Host "Guncelleme tamam! ($adet dosya)" -ForegroundColor Green
  Get-Content -LiteralPath "$ac\degisiklikler.txt" -Encoding UTF8 | ForEach-Object { Write-Host "  $_" }
  # Guncelleyicinin kendisi: paketteki yeni guncelle.bat eskisinin yerine gecer.
  # (Ilk 8 satir hep ayni kalmali: cmd dosyayi kaldigi yerden okumaya devam eder.)
  $yeniBat = "$ac\guncelle.bat"
  if ((Test-Path -LiteralPath $yeniBat) -and ((Get-FileHash -LiteralPath $yeniBat).Hash -ne (Get-FileHash -LiteralPath $env:BAT_YOLU).Hash)) {
    Copy-Item -LiteralPath $yeniBat -Destination $env:BAT_YOLU -Force
    Write-Host '  guncelleyici de yenilendi.'
  }
  Remove-Item -LiteralPath $tmp -Recurse -Force
} catch {
  Write-Host ('HATA: ' + $_.Exception.Message) -ForegroundColor Red
  Write-Host 'Hicbir dosya bozulmadi ise oyunu acabilirsin; sorun devam ederse bu ekranin goruntusunu gonder.'
}