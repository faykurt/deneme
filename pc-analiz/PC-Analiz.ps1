<#
  PC PERFORMANS ANALIZI
  - SALT OKUNUR: hicbir ayari degistirmez, hicbir dosyayi silmez, internete veri gondermez.
  - Tek ag islemi: varsayilan agiya (gateway) 4 ping.
  - Cikti: ayni klasorde HTML rapor + JSON.
  - Windows 10/11, PowerShell 5.1 ile calisir. Yonetici olarak calistirirsan daha cok veri toplar.

  Parametreler:
    -SampleSeconds 60   Canli olcum suresi (sn). Varsayilan 60.
    -DeepScan           C:\ ve kullanici klasorlerinin boyutunu da tarar (yavas, 5-20 dk).
    -NoOpen             Bitince raporu otomatik acma.
#>
param(
  [int]$SampleSeconds = 60,
  [switch]$DeepScan,
  [switch]$NoOpen
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
$started  = Get-Date
$findings = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------- yardimcilar
function Add-Finding($sev, $cat, $title, $detail, $action) {
  [void]$script:findings.Add([pscustomobject]@{ Sev = $sev; Cat = $cat; Title = $title; Detail = $detail; Action = $action })
}
function Esc($s) { if ($null -eq $s) { return '' }; [System.Net.WebUtility]::HtmlEncode([string]$s) }
function R1($v, $d = 1) { if ($null -eq $v) { return 0 }; [math]::Round([double]$v, $d) }
function GB($b) { [math]::Round([double]$b / 1GB, 1) }
function MB($b) { [math]::Round([double]$b / 1MB, 0) }
function Avg($a) { $x = @($a | Where-Object { $null -ne $_ }); if ($x.Count -eq 0) { return 0 }; ($x | Measure-Object -Average).Average }
function Mx($a) { $x = @($a | Where-Object { $null -ne $_ }); if ($x.Count -eq 0) { return 0 }; ($x | Measure-Object -Maximum).Maximum }
function Clamp100($v) { [math]::Max(0, [math]::Min(100, [double]$v)) }

function Get-DirSize($path) {
  if (-not (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue)) { return $null }
  $sum = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  if ($null -eq $sum) { 0 } else { $sum }
}

function Bar($pct, $warnAt = 70, $critAt = 90) {
  $p = Clamp100 $pct
  $cls = 'ok'; if ($p -ge $critAt) { $cls = 'crit' } elseif ($p -ge $warnAt) { $cls = 'warn' }
  "<div class='bar'><i class='$cls' style='width:$([math]::Round($p,0))%'></i></div>"
}

function Spark($vals, $max, $color) {
  $v = @($vals)
  $n = $v.Count
  if ($n -lt 2) { return '' }
  $w = 300; $h = 50
  $pts = for ($i = 0; $i -lt $n; $i++) {
    $x = [math]::Round($i * $w / ($n - 1), 1)
    $val = [math]::Min([double]$v[$i], $max)
    $y = [math]::Round($h - ($val / $max * $h), 1)
    "$x,$y"
  }
  "<svg viewBox='0 0 $w $h' class='spark' preserveAspectRatio='none'><polyline fill='none' stroke='$color' stroke-width='1.6' vector-effect='non-scaling-stroke' points='$($pts -join ' ')'/></svg>"
}

function Table($rows, $cols) {
  $rows = @($rows | Where-Object { $null -ne $_ })
  if ($rows.Count -eq 0) { return "<p class='muted'>Veri yok.</p>" }
  $h = ($cols | ForEach-Object { "<th>$(Esc $_[0])</th>" }) -join ''
  $b = foreach ($r in $rows) {
    '<tr>' + (($cols | ForEach-Object { $c = $_; $v = & $c[1] $r; "<td>$(Esc $v)</td>" }) -join '') + '</tr>'
  }
  "<div class='tw'><table><tr>$h</tr>$($b -join '')</table></div>"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ''
Write-Host '=== PC Performans Analizi ===' -ForegroundColor Cyan
if (-not $isAdmin) { Write-Host 'UYARI: Yonetici olarak calismiyorsun. Disk sagligi, SMART ve sicaklik verileri eksik kalabilir.' -ForegroundColor Yellow }

# ---------------------------------------------------------------- statik bilgi
Write-Host '[1/7] Donanim ve sistem bilgisi...'
$cs    = Get-CimInstance Win32_ComputerSystem
$os    = Get-CimInstance Win32_OperatingSystem
$cpu   = @(Get-CimInstance Win32_Processor)
$bios  = Get-CimInstance Win32_BIOS
$gpu   = @(Get-CimInstance Win32_VideoController)
$logical = ($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum
$cores   = ($cpu | Measure-Object NumberOfCores -Sum).Sum
if (-not $logical) { $logical = 1 }
$totalRamGB = R1 ($cs.TotalPhysicalMemory / 1GB)
$totalRamMB = [double]$os.TotalVisibleMemorySize / 1024
$bootTime   = $os.LastBootUpTime
$uptimeDays = if ($bootTime) { R1 (((Get-Date) - $bootTime).TotalDays) } else { 0 }

# ---------------------------------------------------------------- canli olcum
Write-Host "[2/7] Canli olcum basliyor ($SampleSeconds sn). Bu sirada bilgisayari normal kullan, yavas acilan uygulamayi ac." -ForegroundColor Green
function Get-DiskRaw { Get-CimInstance Win32_PerfRawData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" }
function Get-Lat($a, $b, $rawName, $baseName) {
  if (-not $a -or -not $b) { return $null }
  $dr = [double]$b.$rawName - [double]$a.$rawName
  $db = [double]$b.$baseName - [double]$a.$baseName
  $fq = [double]$b.Frequency_PerfTime
  if ($db -le 0 -or $fq -le 0) { return $null }
  $ms = [math]::Round(($dr / $fq) / $db * 1000, 1)
  if ($ms -lt 0 -or $ms -gt 10000) { return $null }
  $ms
}
$raw1 = Get-DiskRaw
$samples = New-Object System.Collections.ArrayList
$procAcc = @{}
$procSamples = 0
for ($i = 0; $i -lt $SampleSeconds; $i++) {
  $t0 = Get-Date
  $p = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
  $m = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
  $d = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'"
  $s = Get-CimInstance Win32_PerfFormattedData_PerfOS_System
  [void]$samples.Add([pscustomobject]@{
    Cpu = Clamp100 $p.PercentProcessorTime
    Dpc = [double]$p.PercentDPCTime
    Int = [double]$p.PercentInterruptTime
    AvailMB = [double]$m.AvailableMBytes
    Pages = [double]$m.PagesPersec
    CommitPct = [double]$m.PercentCommittedBytesInUse
    Disk = Clamp100 $d.PercentDiskTime
    Queue = [double]$d.CurrentDiskQueueLength
    ReadBps = [double]$d.DiskReadBytesPersec
    WriteBps = [double]$d.DiskWriteBytesPersec
    ProcQ = [double]$s.ProcessorQueueLength
  })
  if ($i % 3 -eq 0) {
    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' } | ForEach-Object {
      $n = $_.Name -replace '#\d+$', ''
      if (-not $procAcc.ContainsKey($n)) { $procAcc[$n] = [pscustomobject]@{ Name = $n; Cpu = 0.0; IO = 0.0 } }
      $procAcc[$n].Cpu += [double]$_.PercentProcessorTime
      $procAcc[$n].IO  += [double]$_.IODataBytesPersec
    }
    $procSamples++
  }
  if ($i % 10 -eq 9) { Write-Host ("      {0}/{1} sn" -f ($i + 1), $SampleSeconds) }
  $left = 1000 - ((Get-Date) - $t0).TotalMilliseconds
  if ($left -gt 0) { Start-Sleep -Milliseconds ([int]$left) }
}
$cpuNow = @(Get-CimInstance Win32_Processor)
$raw2 = Get-DiskRaw
$latRead  = Get-Lat $raw1 $raw2 'AvgDisksecPerRead'  'AvgDisksecPerRead_Base'
$latWrite = Get-Lat $raw1 $raw2 'AvgDisksecPerWrite' 'AvgDisksecPerWrite_Base'

$avgCpu = R1 (Avg ($samples | ForEach-Object { $_.Cpu }))
$maxCpu = R1 (Mx  ($samples | ForEach-Object { $_.Cpu }))
$avgDisk = R1 (Avg ($samples | ForEach-Object { $_.Disk }))
$maxDisk = R1 (Mx  ($samples | ForEach-Object { $_.Disk }))
$avgQueue = R1 (Avg ($samples | ForEach-Object { $_.Queue }))
$avgAvailMB = Avg ($samples | ForEach-Object { $_.AvailMB })
$availPct = if ($totalRamMB -gt 0) { R1 ($avgAvailMB / $totalRamMB * 100) } else { 0 }
$usedPct  = R1 (100 - $availPct)
$avgPages = R1 (Avg ($samples | ForEach-Object { $_.Pages }))
$avgCommit = R1 (Avg ($samples | ForEach-Object { $_.CommitPct }))
$avgDpcInt = R1 ((Avg ($samples | ForEach-Object { $_.Dpc })) + (Avg ($samples | ForEach-Object { $_.Int })))
$avgProcQ = R1 (Avg ($samples | ForEach-Object { $_.ProcQ }))
$avgReadMBs = R1 ((Avg ($samples | ForEach-Object { $_.ReadBps })) / 1MB)
$avgWriteMBs = R1 ((Avg ($samples | ForEach-Object { $_.WriteBps })) / 1MB)

$topCpu = @()
$topIO = @()
if ($procSamples -gt 0) {
  $all = @($procAcc.Values | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; CpuPct = R1 ($_.Cpu / $procSamples / $logical); IOMBs = (R1 ($_.IO / $procSamples / 1MB) 2) }
  })
  $topCpu = @($all | Sort-Object CpuPct -Descending | Select-Object -First 10)
  $topIO  = @($all | Sort-Object IOMBs -Descending | Select-Object -First 10)
}

# ---------------------------------------------------------------- RAM
Write-Host '[3/7] Bellek analizi...'
$mods  = @(Get-CimInstance Win32_PhysicalMemory)
$slots = (Get-CimInstance Win32_PhysicalMemoryArray | Measure-Object MemoryDevices -Sum).Sum
$pf    = @(Get-CimInstance Win32_PageFileUsage)
$pfSettings = @(Get-CimInstance Win32_PageFileSetting)
$allProcs = @(Get-Process)
$totalHandles = ($allProcs | Measure-Object Handles -Sum).Sum
$procCount = $allProcs.Count
$pfRows = @($pf | ForEach-Object { [pscustomobject]@{ Dosya = $_.Name; AyrilanMB = $_.AllocatedBaseSize; SuAnMB = $_.CurrentUsage; TepeMB = $_.PeakUsage } })
$isVM = ([string]$cs.Model + ' ' + [string]$cs.Manufacturer) -match 'Virtual|VMware|KVM|QEMU|Xen|HVM'
$procMem = @(Get-Process | Group-Object Name | ForEach-Object {
  [pscustomobject]@{ Name = $_.Name; Adet = $_.Count; BellekMB = MB (($_.Group | Measure-Object WorkingSet64 -Sum).Sum) }
} | Sort-Object BellekMB -Descending | Select-Object -First 15)

# ---------------------------------------------------------------- Disk
Write-Host '[4/7] Disk analizi...'
$pd  = @(Get-PhysicalDisk)
$ld  = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')
$rel = @(Get-PhysicalDisk | Get-StorageReliabilityCounter)
$pred = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus)
$sysMedia = $null
$sysDiskNo = (Get-Partition -DriveLetter C | Get-Disk).Number
if ($null -ne $sysDiskNo) { $sysMedia = ($pd | Where-Object { $_.DeviceId -eq "$sysDiskNo" } | Select-Object -First 1).MediaType }
if (-not $sysMedia -and $pd.Count -gt 0) { $sysMedia = $pd[0].MediaType }
$cVol = $ld | Where-Object { $_.DeviceID -eq 'C:' }

$folders = New-Object System.Collections.ArrayList
$userProf = $env:USERPROFILE
$quick = @(
  @('Kullanici TEMP', $env:TEMP),
  @('Windows TEMP', "$env:SystemRoot\Temp"),
  @('Windows Update indirmeleri', "$env:SystemRoot\SoftwareDistribution\Download"),
  @('Indirilenler', "$userProf\Downloads"),
  @('Masaustu', "$userProf\Desktop"),
  @('Belgelerim', "$userProf\Documents"),
  @('AppData\Local', "$userProf\AppData\Local"),
  @('Geri Donusum Kutusu', 'C:\$Recycle.Bin')
)
Write-Host '      Onemli klasor boyutlari olculuyor...'
foreach ($q in $quick) { $sz = Get-DirSize $q[1]; if ($null -ne $sz) { [void]$folders.Add([pscustomobject]@{ Ad = $q[0]; Yol = $q[1]; GB = (R1 ($sz / 1GB) 2) }) } }
if ($DeepScan) {
  Write-Host '      DeepScan: C:\ ust klasorleri taraniyor (uzun surebilir)...'
  Get-ChildItem 'C:\' -Directory -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | ForEach-Object {
    $sz = Get-DirSize $_.FullName
    [void]$folders.Add([pscustomobject]@{ Ad = 'C:\ ust klasor'; Yol = $_.FullName; GB = (R1 ($sz / 1GB) 2) })
  }
  Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $sz = Get-DirSize $_.FullName
    [void]$folders.Add([pscustomobject]@{ Ad = 'Kullanici profili'; Yol = $_.FullName; GB = (R1 ($sz / 1GB) 2) })
  }
}
$folders = @($folders | Sort-Object GB -Descending)
$sysFiles = @('hiberfil.sys', 'pagefile.sys', 'swapfile.sys') | ForEach-Object {
  $f = Get-Item "C:\$_" -Force -ErrorAction SilentlyContinue
  if ($f) { [pscustomobject]@{ Dosya = $_; GB = (R1 ($f.Length / 1GB) 1) } }
}

# ---------------------------------------------------------------- Baslangic, servis, guc
Write-Host '[5/7] Baslangic programlari, servisler, guc plani...'
$startup = @(Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User)
$svc3p = @(Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -eq 'Running' -and $_.PathName -notmatch '(?i)\\windows\\' -and $_.PathName -notmatch '(?i)microsoft' } | Select-Object Name, DisplayName)
$planRaw = (powercfg /getactivescheme) 2>$null | Out-String
$planGuid = ''
if ($planRaw -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { $planGuid = $Matches[1].ToLower() }
$planName = $planRaw.Trim()
$pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                 (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
                 [bool](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager').PendingFileRenameOperations
$fastStartup = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled
$av = @(Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct | Select-Object -ExpandProperty displayName)
$mp = Get-MpComputerStatus
$thermal = @(Get-CimInstance -Namespace root\wmi -ClassName MSAcpi_ThermalZoneTemperature | ForEach-Object { R1 (($_.CurrentTemperature / 10) - 273.15) })

# ---------------------------------------------------------------- Olay gunlugu
Write-Host '[6/7] Olay gunlugu (son 7 gun)...'
$since = (Get-Date).AddDays(-7)
$sysEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = $since } -MaxEvents 2000)
$appEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000, 1002; StartTime = $since } -MaxEvents 2000)
$diskProviders = 'disk', 'Ntfs', 'storahci', 'stornvme', 'iaStorA', 'iaStorAV', 'iaStorAVC'
$diskEvents = @($sysEvents | Where-Object { $diskProviders -contains $_.ProviderName })
$wheaEvents = @($sysEvents | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-WHEA-Logger' })
$powerEvents = @($sysEvents | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $_.Id -eq 41 })
$gpuEvents = @($sysEvents | Where-Object { $_.ProviderName -eq 'Display' })
$resEvents = @($sysEvents | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-Resource-Exhaustion-Detector' })
$topEvents = @($sysEvents | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
  $first = $_.Group[0]
  [pscustomobject]@{ Kaynak = $first.ProviderName; OlayNo = $first.Id; Adet = $_.Count; Ornek = ($first.Message -split "`n")[0] }
})
$crashApps = @($appEvents | ForEach-Object {
  $x = $_.Properties
  if ($x.Count -gt 0) { [string]$x[0].Value }
} | Where-Object { $_ } | Group-Object | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { [pscustomobject]@{ Uygulama = $_.Name; Coktu = $_.Count } })

$bootRows = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -MaxEvents 8 | ForEach-Object {
  $x = [xml]$_.ToXml()
  $ms = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' }).'#text'
  if ($ms) { [pscustomobject]@{ Tarih = $_.TimeCreated; AcilisSn = [math]::Round([double]$ms / 1000, 0) } }
})
$slowStart = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 101 } -MaxEvents 60 | ForEach-Object {
  $x = [xml]$_.ToXml()
  $nm = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'FriendlyName' }).'#text'
  if (-not $nm) { $nm = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'Name' }).'#text' }
  $tt = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'TotalTime' }).'#text'
  if ($nm -and $tt) { [pscustomobject]@{ Ad = $nm; Sn = [double]$tt / 1000 } }
} | Group-Object Ad | ForEach-Object { [pscustomobject]@{ Program = $_.Name; Kez = $_.Count; OrtYavaslatmaSn = [math]::Round(($_.Group | Measure-Object Sn -Average).Average, 1) } } | Sort-Object OrtYavaslatmaSn -Descending | Select-Object -First 10)
$badDev = @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -gt 0 } | Select-Object Name, ConfigManagerErrorCode)

# ---------------------------------------------------------------- Ag
Write-Host '[7/7] Ag kontrolu...'
$gw = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).IPv4DefaultGateway.NextHop
$pingAvg = $null; $pingLoss = $null
if ($gw) {
  $pr = @(Test-Connection -ComputerName $gw -Count 4 -ErrorAction SilentlyContinue)
  $pingLoss = 100 - ($pr.Count * 25)
  if ($pr.Count -gt 0) {
    $vals = $pr | ForEach-Object { if ($null -ne $_.ResponseTime) { $_.ResponseTime } else { $_.Latency } }
    $pingAvg = R1 (Avg $vals)
  }
}
$netConns = @(Get-CimInstance Win32_NetworkConnection | Select-Object LocalName, RemoteName, ConnectionState)
$nics = @(Get-CimInstance Win32_NetworkAdapter -Filter 'NetEnabled=true' | Select-Object Name, Speed)

# ================================================================= BULGULAR
# --- RAM
if ($availPct -lt 10) { Add-Finding 'crit' 'RAM' "RAM kritik seviyede dolu (bos: %$availPct)" "Olcum boyunca ortalama bos bellek %$availPct, kullanim %$usedPct. Sistem sayfa dosyasina (diske) tasmaya baslar, fare takilmasi ve yavas uygulama acilisinin klasik sebebi budur." "RAM artir ve/veya en cok bellek tuketen programlari kapat/azalt (asagidaki tabloya bak)." }
elseif ($availPct -lt 20) { Add-Finding 'warn' 'RAM' "RAM baskisi var (bos: %$availPct)" "Ortalama kullanim %$usedPct. Cok sekmeli tarayici veya buyuk uygulamalarla yetersiz kalabilir." "Bellek tuketen programlari gozden gecir; surekli boyleyse RAM artir." }
else { Add-Finding 'ok' 'RAM' "RAM yeterli gorunuyor" "Ortalama bos bellek %$availPct ($totalRamGB GB toplam)." '' }
if ($totalRamGB -lt 8) { Add-Finding 'warn' 'RAM' "Toplam RAM az ($totalRamGB GB)" "Windows 10/11 ve guncel uygulamalar icin 8 GB alt sinir, 16 GB rahat kullanim icin onerilir." "RAM yukseltmesi bu makinede muhtemelen en cok fark yaratan islerden biri." }
elseif ($totalRamGB -lt 16 -and $availPct -lt 30) { Add-Finding 'info' 'RAM' "RAM 16 GB altinda ($totalRamGB GB)" "Bellek kullanimi yuksek seyrediyor." "Is yukun agirsa 16 GB'a cikmayi dusun." }
if ($avgPages -gt 200) { Add-Finding 'warn' 'RAM' "Yuksek sayfalama (ort. $avgPages sayfa/sn)" "Sistem surekli bellek-disk arasinda veri tasiyor olabilir." "RAM yetersizligi veya bellek sizdiran bir program olabilir." }
if ($avgCommit -gt 90) { Add-Finding 'warn' 'RAM' "Taahhut edilen bellek limite yakin (%$avgCommit)" "Fiziksel RAM + sayfa dosyasi dolmak uzere; uygulamalar coker veya 'bellek yetersiz' uyarisi verebilir." "Sayfa dosyasini sistem yonetimine birak, RAM artir." }
if ($mods.Count -eq 1 -and $slots -gt 1) { Add-Finding 'info' 'RAM' 'Tek RAM modulu takili (tek kanal)' "Makinede $slots yuva var, sadece 1 modul kullaniliyor. Cift kanal bellek bant genisligini ikiye katlar." "Ayni ozellikte ikinci modul ekleyerek hem kapasite hem hiz kazanilir." }
if ($pfSettings.Count -eq 0 -and $pf.Count -eq 0) { Add-Finding 'warn' 'RAM' 'Sayfa dosyasi kapali gorunuyor' 'Sayfa dosyasi olmadan bellek dolunca uygulamalar aniden kapanabilir.' 'Sistem Ozellikleri > Gelismis > Performans > Sanal bellek: sistem yonetsin.' }
if ($procMem.Count -gt 0 -and $totalRamMB -gt 0) {
  $big = $procMem[0]
  if (($big.BellekMB / $totalRamMB) -gt 0.25) { Add-Finding 'warn' 'RAM' "Tek program RAM'in %25'inden fazlasini kullaniyor: $($big.Name)" "$($big.Adet) surec, toplam $($big.BellekMB) MB." "Bu programi yeniden baslat veya ayarlarini/eklentilerini gozden gecir." }
}

if ($null -ne $latRead -or $null -ne $latWrite) {
  $lr = if ($null -ne $latRead) { $latRead } else { 0 }
  $lw = if ($null -ne $latWrite) { $latWrite } else { 0 }
  $lm = [math]::Max($lr, $lw)
  if ($lm -gt 50) { Add-Finding 'crit' 'DISK' "Disk gecikmesi cok yuksek (okuma $latRead ms, yazma $latWrite ms)" 'Her disk isleminin beklemesi bu kadar uzunsa uygulamalar acilirken ve fare hareket ederken takilir. Saglikli SSD 1-5 ms, HDD 10-20 ms civarindadir.' 'Disk sagligi/tipi, antivirus taramasi ve disk hatalarini kontrol et.' }
  elseif ($lm -gt 20) { Add-Finding 'warn' 'DISK' "Disk gecikmesi yuksek (okuma $latRead ms, yazma $latWrite ms)" 'SSD icin bu degerler yuksektir; HDD icin siniri zorlar.' 'Disk tipi ve arka plan disk yukunu incele.' }
  else { Add-Finding 'ok' 'DISK' "Disk gecikmesi normal (okuma $latRead ms, yazma $latWrite ms)" '' '' }
}
if ($isVM) { Add-Finding 'info' 'SISTEM' 'Sanal makine gibi gorunuyor' 'Sanal makinede performans ana sunucunun (host) yukune de bagli; bu rapor sadece konugu gorur.' 'Host kaynaklarini ve VM''e ayrilan CPU/RAM miktarini kontrol et.' }
if ($totalHandles -gt 150000) { Add-Finding 'warn' 'RAM' "Cok fazla acik tanimlayici (handle): $totalHandles" "Surec sayisi $procCount. Bir program kaynak sizdiriyor olabilir." 'Yeniden baslat; tekrar olursa surec bazinda handle sayisina bak.' }
if ($bootRows.Count -gt 0) {
  $lastBoot = $bootRows[0].AcilisSn
  if ($lastBoot -gt 120) { Add-Finding 'warn' 'SISTEM' "Son acilis cok yavas ($lastBoot sn)" 'Windows acilisi 2 dakikayi gecmis. Asagidaki yavaslatan programlar tablosuna bak.' 'Gereksiz baslangic programlarini kapat; HDD ise SSD gecisi.' }
  elseif ($lastBoot -gt 60) { Add-Finding 'info' 'SISTEM' "Acilis suresi uzun ($lastBoot sn)" '' 'Baslangic programlarini azalt.' }
}
if ($badDev.Count -gt 0) { $badNames = (@($badDev | ForEach-Object { $_.Name } | Select-Object -First 5)) -join ', '; Add-Finding 'warn' 'SISTEM' "$($badDev.Count) aygit surucu hatasi veriyor" $badNames 'Aygit Yoneticisi''nde sari unlemli aygitlari incele, suruculerini guncelle.' }

# --- CPU
if ($avgCpu -gt 85) { $t = if ($topCpu.Count) { $topCpu[0].Name } else { '?' }; Add-Finding 'crit' 'CPU' "Islemci surekli dolu (ort. %$avgCpu)" "Olcum boyunca ortalama %$avgCpu, tepe %$maxCpu. En cok yuk: $t." "Yuku olusturan sureci incele (asagidaki tablo); arka plan tarama/guncelleme olabilir." }
elseif ($avgCpu -gt 60) { $t = if ($topCpu.Count) { $topCpu[0].Name } else { '?' }; Add-Finding 'warn' 'CPU' "Islemci yuksek yukte (ort. %$avgCpu)" "Tepe %$maxCpu. En cok yuk: $t." "Gereksiz arka plan programlarini azalt." }
else { Add-Finding 'ok' 'CPU' "Islemci yuku normal" "Ortalama %$avgCpu, tepe %$maxCpu." '' }
if ($avgProcQ -gt (2 * $logical)) { Add-Finding 'warn' 'CPU' "Islemci kuyrugu uzun (ort. $avgProcQ)" "Calismak icin sirada bekleyen is parcacigi sayisi mantiksal cekirdek sayisinin ($logical) iki katindan fazla." "CPU yetersiz veya bir program asiri is parcacigi uretiyor." }
if ($avgDpcInt -gt 15) { Add-Finding 'warn' 'CPU' "Surucu/kesme yuku yuksek (%$avgDpcInt)" "DPC+Interrupt suresi yuksekse fare/ses takilmalari genelde surucu kaynaklidir (ag karti, ses, GPU, depolama)." "Ag karti, ses ve ekran karti suruculerini guncelle; LatencyMon ile suruculu sorunlu aygiti bul." }
$cpuMaxClk = ($cpu | Measure-Object MaxClockSpeed -Maximum).Maximum
$cpuCurClk = ($cpuNow | Measure-Object CurrentClockSpeed -Average).Average
if ($cpuMaxClk -and $avgCpu -gt 50 -and $cpuCurClk -lt (0.55 * $cpuMaxClk)) { Add-Finding 'warn' 'CPU' "Islemci dusuk hizda calisiyor ($([int]$cpuCurClk) / $cpuMaxClk MHz)" "Yuk altindayken saat hizi dusuk: isi kaynakli kisitlama veya guc plani sebebi olabilir." "Fan/toz/macun temizligi ve guc planini kontrol et." }
if ($planGuid -eq 'a1841308-3541-4fab-bc81-f71556f20b4a') { Add-Finding 'warn' 'CPU' 'Guc plani: Tasarruf' 'Tasarruf modu islemciyi kasitli olarak yavaslatir.' 'Denetim Masasi > Guc Secenekleri > Dengeli veya Yuksek performans.' }
if ($thermal.Count -gt 0 -and (Mx $thermal) -gt 85) { Add-Finding 'warn' 'CPU' "Sicaklik yuksek ($(Mx $thermal) C)" 'ACPI termal bolge sicakligi 85 C uzerinde (bu olcum her makinede guvenilir degildir).' 'Fan, toz ve sogutucu kontrolu yap.' }

# --- Disk
if ($avgDisk -gt 80) { Add-Finding 'crit' 'DISK' "Disk surekli mesgul (ort. %$avgDisk)" "Disk %$avgDisk dolulukla calisiyor, ortalama kuyruk $avgQueue. Uygulama acilisi ve fare takilmasinin en yaygin sebebi." "Asagidaki 'disk G/C yapan programlar' tablosuna bak; diskin sagligini ve HDD olup olmadigini kontrol et." }
elseif ($avgDisk -gt 50) { Add-Finding 'warn' 'DISK' "Disk yuku yuksek (ort. %$avgDisk)" "Tepe %$maxDisk, ortalama kuyruk $avgQueue." "Arka plan tarama, indexleme veya guncelleme olabilir." }
else { Add-Finding 'ok' 'DISK' 'Disk yuku normal' "Ortalama %$avgDisk, tepe %$maxDisk." '' }
if ($avgQueue -gt 5) { Add-Finding 'crit' 'DISK' "Disk kuyrugu cok uzun (ort. $avgQueue)" 'Istekler diskin yetisebileceginden hizli geliyor.' 'HDD ise SSD gecisi en buyuk iyilestirmedir.' }
elseif ($avgQueue -gt 2) { Add-Finding 'warn' 'DISK' "Disk kuyrugu yuksek (ort. $avgQueue)" 'Disk istekleri birikmeye basliyor.' 'Disk tipini ve sagligini kontrol et.' }
if ($sysMedia -eq 'HDD') { Add-Finding 'crit' 'DISK' 'Sistem diski HDD (mekanik)' 'Mekanik disk, SSD''ye gore uygulama acilisinda ve genel akicilikta cok yavastir. Eski bilgisayarlarda yavaslamanin 1 numarali sebebi.' 'SSD''ye gecis (klonlama ile) en yuksek etkili tek yukseltmedir.' }
elseif ($sysMedia -eq 'Unspecified' -or -not $sysMedia) { Add-Finding 'info' 'DISK' 'Disk tipi belirlenemedi' 'Sanal makine veya ozel surucu olabilir.' '' }
foreach ($d in $pd) {
  if ($d.HealthStatus -and $d.HealthStatus -ne 'Healthy') { Add-Finding 'crit' 'DISK' "Disk sagligi sorunlu: $($d.FriendlyName)" "Durum: $($d.HealthStatus) / $($d.OperationalStatus)." 'Hemen yedek al ve diski degistirmeyi planla.' }
}
foreach ($p in $pred) { if ($p.PredictFailure) { Add-Finding 'crit' 'DISK' 'SMART: Disk arizasi ongoruluyor' "$($p.InstanceName) icin SMART PredictFailure=True." 'Verini hemen yedekle, diski degistir.' } }
foreach ($r in $rel) {
  if ($null -ne $r.Wear -and $r.Wear -gt 80) { Add-Finding 'warn' 'DISK' "SSD asinmasi yuksek (%$($r.Wear))" 'SSD omrunun sonuna yaklasiyor.' 'Yedek al, degistirmeyi planla.' }
  if ($null -ne $r.ReadErrorsUncorrected -and $r.ReadErrorsUncorrected -gt 0) { Add-Finding 'crit' 'DISK' "Duzeltilemeyen disk okuma hatasi ($($r.ReadErrorsUncorrected))" 'Disk yuzeyi/flash sorunu belirtisi.' 'Yedek al, diski kontrol et/degistir.' }
}
if ($cVol -and $cVol.Size) {
  $freePct = R1 ($cVol.FreeSpace / $cVol.Size * 100)
  $freeGB = GB $cVol.FreeSpace
  if ($freePct -lt 5 -or $freeGB -lt 5) { Add-Finding 'crit' 'DISK' "C: neredeyse dolu (bos: $freeGB GB, %$freePct)" 'Bos alan bu kadar azken Windows gecici dosya, guncelleme ve sayfa dosyasi icin yer bulamaz; her sey yavaslar.' 'Disk Temizleme (cleanmgr), Depolama Algilama ve buyuk klasorleri (asagidaki tablo) temizle.' }
  elseif ($freePct -lt 10 -or $freeGB -lt 15) { Add-Finding 'warn' 'DISK' "C: bos alani az ($freeGB GB, %$freePct)" 'Windows icin en az %10-15 bos alan onerilir.' 'Gereksiz buyuk dosyalari temizle.' }
  else { Add-Finding 'ok' 'DISK' "C: bos alani yeterli ($freeGB GB, %$freePct)" '' '' }
}
$tmpSize = ($folders | Where-Object { $_.Ad -in 'Kullanici TEMP', 'Windows TEMP' } | Measure-Object GB -Sum).Sum
if ($tmpSize -gt 5) { Add-Finding 'warn' 'DISK' "Gecici dosyalar buyuk ($(R1 $tmpSize) GB)" 'TEMP klasorleri sismis.' 'Disk Temizleme veya %temp% icerigini sil (kullanimdaki dosyalar silinmez).' }
$hib = $sysFiles | Where-Object { $_.Dosya -eq 'hiberfil.sys' }
if ($hib -and $hib.GB -gt 4) { Add-Finding 'info' 'DISK' "Hazirda bekletme dosyasi $($hib.GB) GB" 'Hazirda bekletme kullanilmiyorsa kapatilip yer acilabilir.' 'Yonetici cmd: powercfg /h off (istersen).' }

# --- Sistem
if ($uptimeDays -gt 14) { Add-Finding 'warn' 'SISTEM' "Bilgisayar $uptimeDays gundur yeniden baslatilmadi" 'Uzun sure acik kalan Windows''ta bellek sizintilari birikir. Hizli Baslat acik ise kapat-ac gercek yeniden baslatma sayilmaz.' 'Baslat > Yeniden baslat (Kapat degil).' }
if ($pendingReboot) { Add-Finding 'warn' 'SISTEM' 'Bekleyen yeniden baslatma var' 'Guncelleme/kurulum sonrasi yeniden baslatma bekliyor; arka planda islemler takilabilir.' 'Yeniden baslat.' }
if ($fastStartup -eq 1 -and $uptimeDays -gt 7) { Add-Finding 'info' 'SISTEM' 'Hizli Baslat acik' 'Kapat/ac yapsan bile cekirdek oturumu korunur; gercek temizlik icin Yeniden Baslat kullan.' '' }
if ($startup.Count -gt 12) { Add-Finding 'warn' 'SISTEM' "Cok sayida baslangic programi ($($startup.Count))" 'Acilista otomatik baslayan her program RAM, CPU ve disk tuketir.' 'Gorev Yoneticisi > Baslangic sekmesinden gereksizleri devre disi birak.' }
if ($svc3p.Count -gt 25) { Add-Finding 'info' 'SISTEM' "Cok sayida ucuncu parti servis ($($svc3p.Count))" 'Arka planda calisan Microsoft disi servisler fazla.' 'Listeyi incele, gereksiz yazilimlari kaldir.' }
if ($av.Count -gt 1) { Add-Finding 'warn' 'SISTEM' "Birden fazla antivirus gorunuyor ($($av -join ', '))" 'Cakisan antivirusler disk ve CPU''yu ciddi sekilde yavaslatir.' 'Kurumsal politikaya uygun olani birak, digerini kaldir (IT ile gorus).' }
if ($mp -and $mp.AntivirusSignatureAge -gt 7) { Add-Finding 'info' 'SISTEM' "Defender imzalari $($mp.AntivirusSignatureAge) gunluk" '' 'Windows Update / Defender guncellemesini calistir.' }

# --- Olaylar
if ($diskEvents.Count -gt 0) { Add-Finding 'crit' 'OLAY' "Son 7 gunde $($diskEvents.Count) disk/dosya sistemi hatasi" 'Disk, NTFS veya depolama surucusu hata kaydetmis. Bu, bozuk sektor/kablo/ariza belirtisi olabilir.' 'Yedek al, chkdsk ve uretici disk aracini calistir.' }
if ($wheaEvents.Count -gt 0) { Add-Finding 'crit' 'OLAY' "Son 7 gunde $($wheaEvents.Count) donanim hatasi (WHEA)" 'CPU/RAM/PCIe donanim hata raporu. Bellek veya islemci sorunu belirtisi olabilir.' 'Windows Bellek Tanilama (mdsched) ve donanim kontrolu.' }
if ($powerEvents.Count -gt 0) { Add-Finding 'warn' 'OLAY' "Beklenmedik kapanma/yeniden baslama: $($powerEvents.Count)x (Kernel-Power 41)" 'Elektrik, PSU, asiri isi veya surucu cokmesi olabilir.' 'Guc kaynagi, sicaklik ve minidump kayitlarini kontrol et.' }
if ($gpuEvents.Count -gt 3) { Add-Finding 'warn' 'OLAY' "Ekran karti surucusu $($gpuEvents.Count) kez sorun bildirmis" 'Takilma/donma sebebi olabilir.' 'Ekran karti suruculerini temiz kur.' }
if ($resEvents.Count -gt 0) { Add-Finding 'warn' 'OLAY' "Windows bellek tukenmesi uyarisi verdi: $($resEvents.Count)x" 'Sistem bellek yetersizligini kaydetmis.' 'RAM artir veya sizinti yapan programi bul.' }
if ($appEvents.Count -gt 20) { Add-Finding 'warn' 'OLAY' "Son 7 gunde $($appEvents.Count) uygulama coktu/dondu" 'Surekli cokme, bozuk kurulum veya bellek/disk sorunu isareti olabilir.' 'En cok cokenleri (asagidaki tablo) yeniden kur/guncelle.' }

# --- Ag
if ($null -ne $pingAvg -and $pingAvg -gt 20) { Add-Finding 'warn' 'AG' "Agiya (gateway) gecikmesi yuksek ($pingAvg ms)" 'Ag gecikmesi aglardan acilan uygulamalari ve paylasimlari yavaslatir.' 'Kablo, switch portu ve ag karti kontrolu; IT ile gorus.' }
if ($null -ne $pingLoss -and $pingLoss -gt 0) { Add-Finding 'warn' 'AG' "Agiya ping kaybi: %$pingLoss" 'Paket kaybi var.' 'Kablo/port/ag karti kontrolu.' }
$deadMaps = @($netConns | Where-Object { $_.ConnectionState -ne 'Connected' })
if ($deadMaps.Count -gt 0) { Add-Finding 'warn' 'AG' "$($deadMaps.Count) agdaki surucu baglantisi kopuk/ulasilamaz" 'Kopuk paylasim suruculeri Explorer ve dosya-ac pencerelerinde saniyelerce takilmaya yol acar.' 'Kullanilmayan surucu eslemelerini kaldir (net use X: /delete).' }

# ================================================================= TESHIS
$pressure = @(
  [pscustomobject]@{ Ad = 'RAM'; Deger = $usedPct },
  [pscustomobject]@{ Ad = 'CPU'; Deger = $avgCpu },
  [pscustomobject]@{ Ad = 'DISK'; Deger = $avgDisk }
) | Sort-Object Deger -Descending
$critCount = @($findings | Where-Object Sev -eq 'crit').Count
$warnCount = @($findings | Where-Object Sev -eq 'warn').Count
$diag = ''
if ($critCount -eq 0 -and $warnCount -eq 0) { $diag = 'Olcum aninda belirgin bir darbogaz bulunmadi. Sorun aralikli olabilir: sorun yasadigin an raporu tekrar calistir.' }
else {
  $worst = $pressure[0]
  $diag = "Olcum sirasinda en yuklu kaynak: $($worst.Ad) (%$([math]::Round($worst.Deger,0))). $critCount kritik, $warnCount uyari bulgu var. Kirmizi bulgulardan basla."
}

# ================================================================= HTML
Write-Host 'Rapor olusturuluyor...'
$sb = New-Object System.Text.StringBuilder
function W($s) { [void]$script:sb.AppendLine($s) }
$host_ = $env:COMPUTERNAME
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'

W '<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
W "<title>Performans Raporu - $(Esc $host_)</title><style>"
W @'
:root{--bg:#f6f7f9;--card:#fff;--tx:#1b1f24;--mu:#6a737d;--bd:#e1e4e8;--ok:#2da44e;--warn:#d4a017;--crit:#d1242f;--info:#3b82f6;--ac:#2563eb}
@media (prefers-color-scheme:dark){:root{--bg:#0f1318;--card:#171c23;--tx:#e6e9ee;--mu:#97a1ad;--bd:#2a313a;--ok:#3fb950;--warn:#e3b341;--crit:#f85149;--info:#58a6ff;--ac:#58a6ff}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.5 system-ui,Segoe UI,Arial,sans-serif;padding:0 16px 48px}
.wrap{max-width:1000px;margin:0 auto}h1{font-size:24px;margin:28px 0 4px}h2{font-size:18px;margin:32px 0 10px;padding-top:8px;border-top:1px solid var(--bd)}
.muted{color:var(--mu);font-size:13px}.card{background:var(--card);border:1px solid var(--bd);border-radius:10px;padding:14px 16px;margin:10px 0}
.diag{border-left:5px solid var(--ac);font-size:16px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}
.big{font-size:28px;font-weight:700}.lbl{font-size:12px;color:var(--mu);text-transform:uppercase;letter-spacing:.04em}
.bar{height:8px;background:var(--bd);border-radius:4px;overflow:hidden;margin-top:6px}.bar i{display:block;height:100%}
.bar i.ok{background:var(--ok)}.bar i.warn{background:var(--warn)}.bar i.crit{background:var(--crit)}
.f{border-left:5px solid var(--bd)}.f.crit{border-left-color:var(--crit)}.f.warn{border-left-color:var(--warn)}.f.info{border-left-color:var(--info)}.f.ok{border-left-color:var(--ok)}
.f b{display:block}.tag{display:inline-block;font-size:11px;padding:1px 7px;border-radius:9px;background:var(--bd);color:var(--mu);margin-right:6px}
.f.crit .tag{background:var(--crit);color:#fff}.f.warn .tag{background:var(--warn);color:#000}
.act{margin-top:4px;color:var(--ac);font-size:14px}.tw{overflow-x:auto}
table{border-collapse:collapse;width:100%;font-size:13px}th,td{text-align:left;padding:6px 10px;border-bottom:1px solid var(--bd);white-space:nowrap}
th{color:var(--mu);font-weight:600}td{max-width:420px;overflow:hidden;text-overflow:ellipsis}
.spark{width:100%;height:50px;display:block;margin-top:6px;background:linear-gradient(var(--bd) 1px,transparent 1px) 0 0/100% 25%}
.pill{display:inline-block;padding:2px 10px;border-radius:12px;font-weight:600;font-size:13px;margin-right:6px}
.pill.crit{background:var(--crit);color:#fff}.pill.warn{background:var(--warn);color:#000}.pill.ok{background:var(--ok);color:#fff}
@media print{body{background:#fff}}
'@
W '</style></head><body><div class="wrap">'
W "<h1>Bilgisayar Performans Raporu</h1>"
W "<div class='muted'>$(Esc $host_) &middot; $stamp &middot; $SampleSeconds sn canli olcum &middot; Yonetici: $(if($isAdmin){'evet'}else{'hayir (bazi veriler eksik)'})</div>"
W "<div class='card diag'><span class='pill crit'>$critCount kritik</span><span class='pill warn'>$warnCount uyari</span><br><br>$(Esc $diag)</div>"

# ozet kutulari
W "<div class='grid'>"
W "<div class='card'><div class='lbl'>RAM kullanimi</div><div class='big'>%$usedPct</div>$(Bar $usedPct 80 92)<div class='muted'>$totalRamGB GB toplam</div></div>"
W "<div class='card'><div class='lbl'>CPU ortalama</div><div class='big'>%$avgCpu</div>$(Bar $avgCpu 60 85)<div class='muted'>tepe %$maxCpu &middot; $cores cekirdek / $logical thread</div></div>"
W "<div class='card'><div class='lbl'>Disk mesguliyeti</div><div class='big'>%$avgDisk</div>$(Bar $avgDisk 50 80)<div class='muted'>tepe %$maxDisk &middot; kuyruk $avgQueue</div></div>"
W "<div class='card'><div class='lbl'>Disk gecikmesi</div><div class='big'>$(if($null -ne $latRead){"$latRead ms"}else{'-'})</div><div class='muted'>okuma &middot; yazma: $(if($null -ne $latWrite){"$latWrite ms"}else{'-'}) &middot; tip: $(Esc $sysMedia)</div></div>"
if ($cVol -and $cVol.Size) { $usedC = R1 (100 - ($cVol.FreeSpace / $cVol.Size * 100)); W "<div class='card'><div class='lbl'>C: doluluk</div><div class='big'>%$usedC</div>$(Bar $usedC 85 93)<div class='muted'>$(GB $cVol.FreeSpace) GB bos / $(GB $cVol.Size) GB</div></div>" }
W '</div>'

# bulgular
W '<h2>Bulgular</h2>'
$order = @{ crit = 0; warn = 1; info = 2; ok = 3 }
$label = @{ crit = 'KRITIK'; warn = 'UYARI'; info = 'BILGI'; ok = 'IYI' }
foreach ($f in ($findings | Sort-Object { $order[$_.Sev] })) {
  $act = ''; if ($f.Action) { $act = "<div class='act'>&rarr; $(Esc $f.Action)</div>" }
  W "<div class='card f $($f.Sev)'><span class='tag'>$($label[$f.Sev])</span><span class='tag'>$(Esc $f.Cat)</span><b>$(Esc $f.Title)</b><span class='muted'>$(Esc $f.Detail)</span>$act</div>"
}

# zaman cizgisi
W '<h2>Olcum sirasindaki gidisat</h2><div class="grid">'
W "<div class='card'><div class='lbl'>CPU %</div>$(Spark ($samples | ForEach-Object { $_.Cpu }) 100 '#2563eb')</div>"
W "<div class='card'><div class='lbl'>Disk mesguliyeti %</div>$(Spark ($samples | ForEach-Object { $_.Disk }) 100 '#d4a017')</div>"
W "<div class='card'><div class='lbl'>Bos RAM (MB)</div>$(Spark ($samples | ForEach-Object { $_.AvailMB }) ([math]::Max(1, $totalRamMB)) '#2da44e')</div>"
W '</div>'
W "<div class='muted'>Disk okuma ort. $avgReadMBs MB/sn, yazma ort. $avgWriteMBs MB/sn.</div>"

# surecler
W '<h2>En cok CPU kullanan programlar</h2>'
W (Table $topCpu @(@('Program', { param($x) $x.Name }), @('CPU % (ort.)', { param($x) $x.CpuPct })))
W '<h2>En cok disk G/C yapan programlar</h2>'
W (Table $topIO @(@('Program', { param($x) $x.Name }), @('MB/sn (ort.)', { param($x) $x.IOMBs })))
W '<h2>En cok RAM kullanan programlar</h2>'
W (Table $procMem @(@('Program', { param($x) $x.Name }), @('Surec', { param($x) $x.Adet }), @('Bellek (MB)', { param($x) $x.BellekMB })))

# donanim
W '<h2>Donanim</h2>'
W "<div class='card'><b>Sistem:</b> $(Esc $cs.Manufacturer) $(Esc $cs.Model) &middot; BIOS: $(Esc $bios.SMBIOSBIOSVersion)<br><b>Isletim sistemi:</b> $(Esc $os.Caption) $(Esc $os.Version) &middot; Son acilis: $(Esc $bootTime) ($uptimeDays gun once)<br><b>Guc plani:</b> $(Esc $planName)</div>"
W (Table $cpu @(@('Islemci', { param($x) $x.Name }), @('Cekirdek', { param($x) $x.NumberOfCores }), @('Thread', { param($x) $x.NumberOfLogicalProcessors }), @('Maks MHz', { param($x) $x.MaxClockSpeed }), @('Anlik MHz', { param($x) $x.CurrentClockSpeed })))
W '<h2>Sayfa dosyasi</h2>'
W (Table $pfRows @(@('Dosya', { param($x) $x.Dosya }), @('Ayrilan MB', { param($x) $x.AyrilanMB }), @('Su an MB', { param($x) $x.SuAnMB }), @('Tepe MB', { param($x) $x.TepeMB })))
W "<h2>Bellek modulleri ($($mods.Count) / $slots yuva dolu)</h2>"
W (Table $mods @(@('Yuva', { param($x) $x.DeviceLocator }), @('GB', { param($x) GB $x.Capacity }), @('MHz', { param($x) $x.Speed }), @('Ayarli MHz', { param($x) $x.ConfiguredClockSpeed }), @('Uretici', { param($x) $x.Manufacturer })))
W '<h2>Fiziksel diskler</h2>'
W (Table $pd @(@('Disk', { param($x) $x.FriendlyName }), @('Tip', { param($x) $x.MediaType }), @('Bus', { param($x) $x.BusType }), @('GB', { param($x) GB $x.Size }), @('Saglik', { param($x) $x.HealthStatus })))
W '<h2>Surucu bolumleri</h2>'
W (Table $ld @(@('Surucu', { param($x) $x.DeviceID }), @('Etiket', { param($x) $x.VolumeName }), @('Toplam GB', { param($x) GB $x.Size }), @('Bos GB', { param($x) GB $x.FreeSpace }), @('Bos %', { param($x) if ($x.Size) { R1 ($x.FreeSpace / $x.Size * 100) } })))
W '<h2>Ekran karti</h2>'
W (Table $gpu @(@('Ad', { param($x) $x.Name }), @('Surucu surumu', { param($x) $x.DriverVersion }), @('Surucu tarihi', { param($x) $x.DriverDate })))

# disk kullanimi
W "<h2>Klasor boyutlari$(if(-not $DeepScan){' (hizli mod; ayrintili tarama icin -DeepScan)'})</h2>"
W (Table ($folders | Select-Object -First 25) @(@('Ad', { param($x) $x.Ad }), @('Yol', { param($x) $x.Yol }), @('GB', { param($x) $x.GB })))
W '<h2>Buyuk sistem dosyalari</h2>'
W (Table $sysFiles @(@('Dosya', { param($x) $x.Dosya }), @('GB', { param($x) $x.GB })))

# sistem
W "<h2>Baslangic programlari ($($startup.Count))</h2>"
W (Table $startup @(@('Ad', { param($x) $x.Name }), @('Komut', { param($x) $x.Command }), @('Konum', { param($x) $x.Location }), @('Kullanici', { param($x) $x.User })))
W "<h2>Ucuncu parti otomatik servisler ($($svc3p.Count))</h2>"
W (Table $svc3p @(@('Servis', { param($x) $x.Name }), @('Gorunen ad', { param($x) $x.DisplayName })))
W '<h2>Windows acilis sureleri (son kayitlar)</h2>'
W (Table $bootRows @(@('Tarih', { param($x) $x.Tarih }), @('Acilis (sn)', { param($x) $x.AcilisSn })))
W '<h2>Acilisi en cok yavaslatan programlar</h2>'
W (Table $slowStart @(@('Program', { param($x) $x.Program }), @('Kez', { param($x) $x.Kez }), @('Ort. yavaslatma (sn)', { param($x) $x.OrtYavaslatmaSn })))
W '<h2>Surucu hatasi olan aygitlar</h2>'
W (Table $badDev @(@('Aygit', { param($x) $x.Name }), @('Hata kodu', { param($x) $x.ConfigManagerErrorCode })))
W '<h2>Olay gunlugu: en sik hatalar (7 gun)</h2>'
W (Table $topEvents @(@('Kaynak', { param($x) $x.Kaynak }), @('Olay No', { param($x) $x.OlayNo }), @('Adet', { param($x) $x.Adet }), @('Ornek mesaj', { param($x) $x.Ornek })))
W '<h2>En cok coken uygulamalar (7 gun)</h2>'
W (Table $crashApps @(@('Uygulama', { param($x) $x.Uygulama }), @('Coktu/Dondu', { param($x) $x.Coktu })))
W '<h2>Ag</h2>'
W "<div class='card'>Varsayilan ag gecidi: $(Esc $gw) &middot; Ping ort.: $(if($null -ne $pingAvg){"$pingAvg ms"}else{'olculemedi'}) &middot; Kayip: $(if($null -ne $pingLoss){"%$pingLoss"}else{'-'})<br>Antivirus: $(Esc ($av -join ', '))$(if($mp){" &middot; Defender imza yasi: $($mp.AntivirusSignatureAge) gun"})</div>"
W (Table $nics @(@('Ag karti', { param($x) $x.Name }), @('Hiz (Mbit)', { param($x) if ($x.Speed) { [math]::Round($x.Speed / 1e6) } })))
W (Table $netConns @(@('Yerel', { param($x) $x.LocalName }), @('Uzak', { param($x) $x.RemoteName }), @('Durum', { param($x) $x.ConnectionState })))

W "<p class='muted' style='margin-top:32px'>Bu rapor salt okunur olcumlerle uretildi; sistemde hicbir ayar degistirilmedi. Sonuclar olcum aninin goruntusudur: sorun aralikliysa sorun yasarken tekrar calistirin.</p>"
W '</div></body></html>'

# ---------------------------------------------------------------- yaz
$outDir = $PSScriptRoot
if (-not $outDir) { $outDir = (Get-Location).Path }
$base = "Performans-Raporu_${host_}_$(Get-Date -Format 'yyyyMMdd-HHmm')"
$htmlPath = Join-Path $outDir "$base.html"
try { [IO.File]::WriteAllText($htmlPath, $sb.ToString(), (New-Object Text.UTF8Encoding($true))) }
catch { $outDir = [Environment]::GetFolderPath('Desktop'); $htmlPath = Join-Path $outDir "$base.html"; [IO.File]::WriteAllText($htmlPath, $sb.ToString(), (New-Object Text.UTF8Encoding($true))) }

$json = [pscustomobject]@{
  Computer = $host_; Time = $stamp; Admin = $isAdmin; Diagnosis = $diag
  Metrics = [pscustomobject]@{ DiskLatReadMs = $latRead; DiskLatWriteMs = $latWrite; Handles = $totalHandles; AvgCpu = $avgCpu; MaxCpu = $maxCpu; AvgDisk = $avgDisk; AvgQueue = $avgQueue; RamUsedPct = $usedPct; TotalRamGB = $totalRamGB; UptimeDays = $uptimeDays }
  Findings = $findings; TopCpu = $topCpu; TopDiskIO = $topIO; TopMemory = $procMem; Folders = $folders
}
$jsonPath = Join-Path $outDir "$base.json"
[IO.File]::WriteAllText($jsonPath, ($json | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($true)))

$secs = [int]((Get-Date) - $started).TotalSeconds
Write-Host ''
Write-Host "Bitti ($secs sn). Rapor: $htmlPath" -ForegroundColor Green
Write-Host "Ozet: $diag"
if (-not $NoOpen) { Start-Process $htmlPath }
