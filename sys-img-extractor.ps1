<#
ROM Extractor / Converter Utilitys
- Handles overwrites safely
- Interactive .zip and .dat.br selection
- Cleanup prompt for temp_files directory on exit
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

# ---------------- Core helpers ----------------
function Select-Zip {
    $zips = Get-ChildItem "$ScriptDir\*.zip" -File | Sort-Object LastWriteTime -Descending
    if(-not $zips){ErrorMsg "No zip files found."; Pause; return $null}

    Write-Host "Available ZIP files:`n" -ForegroundColor Cyan
    for($i=0; $i -lt $zips.Count; $i++) {
        Write-Host ("[$i] " + $zips[$i].Name) -ForegroundColor Cyan
    }

    do {
        $sel = Read-Host "Enter number of zip to extract (or Q to cancel)"
        if($sel -match '^[Qq]$'){return $null}
    } while ($sel -notmatch '^\d+$' -or [int]$sel -ge $zips.Count)

    return $zips[[int]$sel]
}

function Select-DatBr {
    $datFiles = Get-ChildItem "$TempDir\*.dat.br" -File | Sort-Object LastWriteTime -Descending
    if(-not $datFiles){ErrorMsg "No .dat.br files found in $TempDir"; Pause; return $null}
    Write-Host "Available .dat.br files:`n" -ForegroundColor Cyan
    for($i=0; $i -lt $datFiles.Count; $i++) {
        Write-Host ("[$i] " + $datFiles[$i].Name) -ForegroundColor Cyan
    }
    do {
        $sel = Read-Host "Enter number of file to convert (or Q to cancel)"
        if($sel -match '^[Qq]$'){return $null}
    } while ($sel -notmatch '^\d+$' -or [int]$sel -ge $datFiles.Count)
    return $datFiles[[int]$sel]
}

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

function FullZip-ToIMG {
    Banner "Full ZIP to system.img"
    $zip = Select-Zip
    if(-not $zip){Warn "Cancelled."; Pause; return}

    Ensure-Dir $TempDir
    Ensure-Dir $OutDir
    if(Test-Path $OutSystem){Remove-Item -Recurse -Force $OutSystem}

    Extract-Zip $zip.FullName
    $datBr = Join-Path $TempDir 'system.new.dat.br'
    $dat   = Join-Path $TempDir 'system.new.dat'
    $list  = Join-Path $TempDir 'system.transfer.list'

    if(Test-Path $datBr){Brotli-Convert $datBr $dat}
    if(-not ((Test-Path $dat) -and (Test-Path $list))) {
        ErrorMsg "Missing .dat or transfer.list after extraction."
        Pause
        return
    }

    $img = Join-Path $OutDir 'system.img'
    SDAT-ToIMG $dat $list $img
    Pause
}

function DatBr-ToIMG {
    Banner "DAT.BR to system.img"
    $datBr = Get-ChildItem "$TempDir\system.new.dat.br" -File | Select-Object -First 1
    $list  = Get-ChildItem "$TempDir\system.transfer.list" -File | Select-Object -First 1

    if(-not ((Test-Path $datBr) -and (Test-Path $list))) {
        ErrorMsg "Need system.new.dat.br and system.transfer.list inside $TempDir"
        Pause
        return
    }

    $dat = $datBr.FullName -replace '\.br$',''
    Brotli-Convert $datBr.FullName $dat
    $img = Join-Path $OutDir 'system.img'
    SDAT-ToIMG $dat $list.FullName $img
    Pause
}

function DatBr-Manual {
    Banner "Select .dat.br manually"
    $datBr = Select-DatBr
    if(-not $datBr){Warn "Cancelled."; Pause; return}
    $list = Get-ChildItem "$TempDir\system.transfer.list" -File | Select-Object -First 1
    if(-not (Test-Path $list)){
        ErrorMsg "system.transfer.list missing in $TempDir."
        Pause
        return
    }
    $dat = $datBr.FullName -replace '\.br$',''
    Brotli-Convert $datBr.FullName $dat
    $img = Join-Path $OutDir 'system.img'
    SDAT-ToIMG $dat $list.FullName $img
    Pause
}

function Payload-ToIMG {
    Banner "payload.bin to images"
    $payload = Join-Path $TempDir 'payload.bin'
    if(-not (Test-Path $payload)){ErrorMsg "payload.bin missing"; Pause; return}
    Ensure-Dir (Join-Path $OutDir 'payload_output')
    Info "Dumping payload.bin (this may take time)..."
    & (Tool 'payload_dumper.exe')
    Done "Payload dumped."
    Pause
}

function Extract-IMG {
    Banner "Extract system.img"
    $img = Join-Path $OutDir 'system.img'
    if(-not (Test-Path $img)){ErrorMsg "system.img not found."; Pause; return}
    Info "Cleaning previous extraction..."
    if(Test-Path $OutSystem){Remove-Item -Recurse -Force $OutSystem}
    Ensure-Dir $OutSystem
    Info "Extracting system.img into extracted_files/system"
    & (Tool 'Imgextractor.exe') $img $OutSystem -i
    Done "Filesystem extracted to $OutSystem"
    Start-Process explorer.exe $OutSystem
    Pause
}

# ---------------- Menu loop ----------------
:MAIN
while ($true) {
    Clear-Host

    # --- Ready indicators ---
    $readyZip      = [bool](Get-ChildItem "$ScriptDir\*.zip" -ErrorAction SilentlyContinue)
    $readyDat      = (Test-Path "$TempDir\system.new.dat.br") -and (Test-Path "$TempDir\system.transfer.list")
    $readyPayload  = Test-Path "$TempDir\payload.bin"
    $readyImg      = Test-Path "$OutDir\system.img"

    Write-Host "=============================="
    Write-Host "   ROM Extraction Utility"
    Write-Host "==============================`n"

    # helper to colorize labels
    function Label($found) {
        if ($found) { Write-Host "[FOUND]" -ForegroundColor Green -NoNewline }
    }

    function OptionalLabel() {
        Write-Host "[OPTIONAL]" -ForegroundColor Yellow -NoNewline
    }

    # Menu items
    Write-Host "[" -NoNewline; Write-Host "1" -NoNewline -ForegroundColor Cyan; Write-Host "] Full ZIP to system.img " -NoNewline
    if ($readyZip) { Label $true } else { Write-Host "" }
    Write-Host ""

    Write-Host "[" -NoNewline; Write-Host "2" -NoNewline -ForegroundColor Cyan; Write-Host "] system.new.dat.br to system.img " -NoNewline
    if ($readyDat) { Label $true } else { Write-Host "" }
    Write-Host ""

    Write-Host "[" -NoNewline; Write-Host "3" -NoNewline -ForegroundColor Cyan; Write-Host "] payload.bin to images " -NoNewline
    if ($readyPayload) { Label $true } else { Write-Host "" }
    Write-Host ""

    Write-Host "[" -NoNewline; Write-Host "4" -NoNewline -ForegroundColor Cyan; Write-Host "] Extract system.img to filesystem " -NoNewline
    if ($readyImg) { Label $true } else { Write-Host "" }
    Write-Host ""

    Write-Host "[" -NoNewline; Write-Host "5" -NoNewline -ForegroundColor Cyan; Write-Host "] Manually select .dat.br to system.img " -NoNewline
    OptionalLabel
    Write-Host "`n"
    Write-Host "[Q] Quit" -ForegroundColor Red

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

# ---------------- Exit cleanup prompt ----------------
Banner "Exiting"

if(Test-Path $TempDir){
    Write-Host "`nTemporary directory detected: $TempDir" -ForegroundColor Yellow
    $choice = Read-Host "Delete temporary files now? (y/N)"
    if($choice -eq 'y'){
        try {
            Remove-Item -Recurse -Force $TempDir
            Done "Temporary directory deleted."
        } catch {
            ErrorMsg "Failed to delete temp directory: $_"
        }
    } else {
        Warn "Temporary directory retained."
    }
}

Write-Host "`nGoodbye." -ForegroundColor Gray
exit
