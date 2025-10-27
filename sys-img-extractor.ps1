<#
ROM Extractor / Converter Utility (final recursive)
- Scans nested directories for ROM files
- Handles .dat, .dat.br, .br.dat
- Retains all previous safety and visual improvements
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir
$Tools     = Join-Path $ScriptDir 'tools'
$TempDir   = Join-Path $ScriptDir 'temp_files\rom'
$OutDir    = Join-Path $ScriptDir 'extracted_files'
$OutSystem = Join-Path $OutDir 'system'

function Pause($msg="Press Enter to continue..."){Read-Host -Prompt $msg | Out-Null}
function Ensure-Dir($p){if(-not(Test-Path $p)){New-Item -ItemType Directory -Path $p -Force | Out-Null}}
function Tool($name){Join-Path $Tools $name}

Ensure-Dir $TempDir
Ensure-Dir $OutDir
Ensure-Dir $OutSystem

function Banner($title) {
    Clear-Host
    $line = ('=' * 60)
    Write-Host ""
    Write-Host $line -ForegroundColor DarkGray
    Write-Host ("{0}" -f $title.PadLeft(($title.Length + (60 - $title.Length) / 2))) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkGray
    Write-Host ""
}

function Info($msg){Write-Host "[INFO]  $msg" -ForegroundColor White}
function Warn($msg){Write-Host "[WARN]  $msg" -ForegroundColor Yellow}
function ErrorMsg($msg){Write-Host "[ERROR] $msg" -ForegroundColor Red}
function Done($msg){Write-Host "[DONE]  $msg" -ForegroundColor Green}

# Recursive search helper
function Find-FileRecursive($basePath, $patterns) {
    $results = @()
    foreach ($pattern in $patterns) {
        $results += Get-ChildItem -Path $basePath -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue
    }
    return $results | Sort-Object LastWriteTime -Descending
}

# ---------------- Core helpers ----------------
function Safe-Output($targetPath){
    if(Test-Path $targetPath){
        Warn "$([IO.Path]::GetFileName($targetPath)) already exists."
        $ans = Read-Host "Overwrite? (y/N)"
        if($ans -ne 'y'){
            $ts = Get-Date -Format "yyyyMMdd_HHmmss"
            $new = [IO.Path]::Combine([IO.Path]::GetDirectoryName($targetPath),
                [IO.Path]::GetFileNameWithoutExtension($targetPath) + "_$ts" + [IO.Path]::GetExtension($targetPath))
            Info "Using alternate filename: $(Split-Path $new -Leaf)"
            return $new
        }
    }
    return $targetPath
}

function Extract-Zip($zipPath){
    Info "Extracting $([IO.Path]::GetFileName($zipPath)) to temp_files..."
    & (Tool '7z.exe') e $zipPath "-o$TempDir" -y | Out-Null
    Done "Extraction complete."
}

function Brotli-Convert($src,$dst){
    Info "Decompressing $([IO.Path]::GetFileName($src)) -> $([IO.Path]::GetFileName($dst))..."
    & (Tool 'brotli.exe') -d $src -o $dst
    Done "Decompressed successfully."
}

function SDAT-ToIMG($dat,$list,$out){
    $finalOut = Safe-Output $out
    Info "Converting .dat to .img ..."
    & python (Tool 'sdat2img.py') $list $dat $finalOut
    if(Test-Path $finalOut){Done "Generated: $finalOut"} else {ErrorMsg "Conversion failed!"}
}

# ---------------- Extraction Modes ----------------
function FullZip-ToIMG {
    Banner "Full ZIP to IMG"
    $zips = Find-FileRecursive $ScriptDir @("*.zip")
    if(-not $zips){ErrorMsg "No zip files found."; Pause; return}

    Write-Host "Available ZIP files:`n" -ForegroundColor Cyan
    for($i=0; $i -lt $zips.Count; $i++) {
        Write-Host ("[$i] " + $zips[$i].Name) -ForegroundColor Cyan
    }

    do {
        $sel = Read-Host "Enter number of zip to extract (or Q to cancel)"
        if($sel -match '^[Qq]$'){return}
    } while ($sel -notmatch '^\d+$' -or [int]$sel -ge $zips.Count)
    $zip = $zips[[int]$sel]

    if(Test-Path $OutSystem){Remove-Item -Recurse -Force $OutSystem}
    Extract-Zip $zip.FullName

    $datBr = Find-FileRecursive $TempDir @("system.new.dat.br","system.new.br.dat")
    $dat   = Find-FileRecursive $TempDir @("system.new.dat")
    $list  = Find-FileRecursive $TempDir @("system.transfer.list")

    if($datBr){Brotli-Convert $datBr[0].FullName (Join-Path $TempDir "system.new.dat")}
    elseif(-not $dat){ErrorMsg "No system.new.dat(.br) found."; Pause; return}

    if(-not $list){ErrorMsg "No system.transfer.list found."; Pause; return}

    $img = Join-Path $OutDir "system.img"
    SDAT-ToIMG (Join-Path $TempDir "system.new.dat") $list[0].FullName $img
    Pause
}

function DatBr-ToIMG {
    Banner "DAT/BR.DAT to IMG"
    $datFiles = Find-FileRecursive $TempDir @("*.dat.br","*.br.dat","*.dat")
    $list = Find-FileRecursive $TempDir @("*.transfer.list")

    if(-not ($datFiles -and $list)) {
        ErrorMsg "Missing .dat/.dat.br and/or .transfer.list files."
        Pause; return
    }

    $input = $datFiles[0]
    $base = [IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetFileNameWithoutExtension($input.Name))
    $dat  = Join-Path $TempDir ($base + ".new.dat")
    $img  = Join-Path $OutDir  ($base + ".img")

    if($input.Extension -eq ".br" -or $input.Name -like "*.br.dat"){Brotli-Convert $input.FullName $dat}
    else {Copy-Item $input.FullName $dat -Force}

    SDAT-ToIMG $dat $list[0].FullName $img
    Pause
}

function DatBr-Manual {
    Banner "Manual .dat/.dat.br/.br.dat Selection"
    $datFiles = Find-FileRecursive $TempDir @("*.dat.br","*.br.dat","*.dat")
    if(-not $datFiles){ErrorMsg "No .dat/.br.dat/.dat.br files found under $TempDir"; Pause; return}

    Write-Host "Available input files:`n" -ForegroundColor Cyan
    for($i=0; $i -lt $datFiles.Count; $i++) {
        Write-Host ("[$i] " + $datFiles[$i].FullName) -ForegroundColor Cyan
    }

    do {
        $sel = Read-Host "Select file number (or Q to cancel)"
        if($sel -match '^[Qq]$'){return}
    } while ($sel -notmatch '^\d+$' -or [int]$sel -ge $datFiles.Count)

    $input = $datFiles[[int]$sel]
    $list  = Find-FileRecursive $TempDir @("*.transfer.list")
    if(-not $list){ErrorMsg "No transfer list found."; Pause; return}

    $base = [IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetFileNameWithoutExtension($input.Name))
    $dat  = Join-Path $TempDir ($base + ".new.dat")
    $img  = Join-Path $OutDir  ($base + ".img")

    if($input.Extension -eq ".br" -or $input.Name -like "*.br.dat"){Brotli-Convert $input.FullName $dat}
    else {Copy-Item $input.FullName $dat -Force}

    SDAT-ToIMG $dat $list[0].FullName $img
    Pause
}

function Payload-ToIMG {
    Banner "payload.bin to images"
    $payload = Find-FileRecursive $TempDir @("payload.bin")
    if(-not $payload){ErrorMsg "payload.bin not found."; Pause; return}
    Ensure-Dir (Join-Path $OutDir 'payload_output')
    Info "Dumping payload.bin (this may take time)..."
    & (Tool 'payload_dumper.exe')
    Done "Payload dumped."
    Pause
}

function Extract-IMG {
    Banner "Extract IMG Filesystem"
    $img = Find-FileRecursive $OutDir @("*.img")
    if(-not $img){ErrorMsg "No .img found in extracted_files."; Pause; return}
    Info "Cleaning previous extraction..."
    if(Test-Path $OutSystem){Remove-Item -Recurse -Force $OutSystem}
    Ensure-Dir $OutSystem
    Info "Extracting $($img[0].Name) into extracted_files/system"
    & (Tool 'Imgextractor.exe') $img[0].FullName $OutSystem -i
    Done "Filesystem extracted to $OutSystem"
    Start-Process explorer.exe $OutSystem
    Pause
}

# ---------------- Menu loop ----------------
:MAIN
while ($true) {
    Clear-Host

    $readyZip  = (Find-FileRecursive $ScriptDir @("*.zip")).Count -gt 0
    $readyDat  = (Find-FileRecursive $TempDir @("*.dat.br","*.br.dat","*.dat")).Count -gt 0
    $readyPayload = (Find-FileRecursive $TempDir @("payload.bin")).Count -gt 0
    $readyImg  = (Find-FileRecursive $OutDir @("*.img")).Count -gt 0

    Write-Host "=============================="
    Write-Host "   ROM Extraction Utility"
    Write-Host "==============================`n"

    function Label($found) { if ($found) { Write-Host "[FOUND]" -ForegroundColor Green -NoNewline } }
    function OptionalLabel() { Write-Host "[OPTIONAL]" -ForegroundColor Yellow -NoNewline }

    Write-Host "[" -NoNewline; Write-Host "1" -NoNewline -ForegroundColor Cyan; Write-Host "] Full ZIP to IMG " -NoNewline; if($readyZip){Label $true}; Write-Host ""
    Write-Host "[" -NoNewline; Write-Host "2" -NoNewline -ForegroundColor Cyan; Write-Host "] DAT/BR.DAT/BR to IMG " -NoNewline; if($readyDat){Label $true}; Write-Host ""
    Write-Host "[" -NoNewline; Write-Host "3" -NoNewline -ForegroundColor Cyan; Write-Host "] payload.bin to images " -NoNewline; if($readyPayload){Label $true}; Write-Host ""
    Write-Host "[" -NoNewline; Write-Host "4" -NoNewline -ForegroundColor Cyan; Write-Host "] Extract IMG filesystem " -NoNewline; if($readyImg){Label $true}; Write-Host ""
    Write-Host "[" -NoNewline; Write-Host "5" -NoNewline -ForegroundColor Cyan; Write-Host "] Manual .dat/.br.dat/.dat.br to IMG " -NoNewline; OptionalLabel; Write-Host ""
    Write-Host "`n[Q] Quit" -ForegroundColor Red

    $opt = Read-Host "`nSelect option"
    switch -Regex ($opt) {
        '^[1]$' {FullZip-ToIMG}
        '^[2]$' {DatBr-ToIMG}
        '^[3]$' {Payload-ToIMG}
        '^[4]$' {Extract-IMG}
        '^[5]$' {DatBr-Manual}
        '^[Qq]$' {break MAIN}
        default {Write-Host "Invalid selection."; Pause}
    }
}

Banner "Exiting"
if(Test-Path $TempDir){
    Write-Host "`nTemporary directory detected: $TempDir" -ForegroundColor Yellow
    $choice = Read-Host "Delete temporary files now? (y/N)"
    if($choice -eq 'y'){
        try { Remove-Item -Recurse -Force $TempDir; Done "Temporary directory deleted." }
        catch { ErrorMsg "Failed to delete temp directory: $_" }
    } else { Warn "Temporary directory retained." }
}
Write-Host "`nGoodbye." -ForegroundColor Gray
exit
