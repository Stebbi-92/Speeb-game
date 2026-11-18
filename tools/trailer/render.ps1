# Films the trailer shots on a Windows PC with a graphics card. Run from PowerShell:
#   powershell -ExecutionPolicy Bypass -File render.ps1 -Root D:\BrelmTrailer [-Only s01_dawn_ash,s08_fp_shotgun] [-Res 2560x1440]
# Downloads Godot 4.3 and ffmpeg into Root (once), films every shot in shots.json with Godot's Movie
# Maker, then cuts each shot to its own high-quality MP4 plus a contact sheet in Root\clips.
param(
    [string]$Root = "D:\BrelmTrailer",
    [string]$Game = "",
    [string]$Only = "",
    [string]$Res = "2560x1440",
    [string]$Shots = "res://tools/trailer/shots.json"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$ProgressPreference = "SilentlyContinue"
if ($Game -eq "") { $Game = Join-Path $Root "game" }
New-Item -ItemType Directory -Force -Path $Root, "$Root\out", "$Root\clips" | Out-Null

# Godot 4.3 (the game's engine version)
$godot = Join-Path $Root "godot\Godot_v4.3-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
    Write-Host "Downloading Godot 4.3..."
    Invoke-WebRequest "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip" -OutFile "$Root\godot.zip"
    Expand-Archive "$Root\godot.zip" -DestinationPath "$Root\godot" -Force
    Remove-Item "$Root\godot.zip"
}
# ffmpeg, for cutting
$ff = Get-ChildItem -Path "$Root\ffmpeg" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $ff) {
    Write-Host "Downloading ffmpeg..."
    Invoke-WebRequest "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile "$Root\ffmpeg.zip"
    Expand-Archive "$Root\ffmpeg.zip" -DestinationPath "$Root\ffmpeg" -Force
    Remove-Item "$Root\ffmpeg.zip"
    $ff = Get-ChildItem -Path "$Root\ffmpeg" -Recurse -Filter ffmpeg.exe | Select-Object -First 1
}
$ffmpeg = $ff.FullName

if (-not (Test-Path "$Game\project.godot")) { throw "No game at $Game (unzip the branch there first)" }
Copy-Item "$Game\tools\trailer\override.cfg" "$Game\override.cfg" -Force

if (-not (Test-Path "$Game\.godot\imported")) {
    Write-Host "Importing the game's files (first time only, a few minutes)..."
    $ErrorActionPreference = "Continue"
    & $godot --headless --path $Game --import 2>&1 | Out-File "$Root\out\import.log"
    $ErrorActionPreference = "Stop"
}

$raw = "$Root\out\raw.avi"
Remove-Item $raw -ErrorAction SilentlyContinue
$userDir = Join-Path $env:APPDATA "BrelmTrailer"
Remove-Item "$userDir\trailer_cuts.json" -ErrorAction SilentlyContinue
$gargs = @("--path", $Game, "--resolution", $Res, "--fixed-fps", "60", "--write-movie", $raw, "--", "level=12", "trailer=$Shots")
if ($Only -ne "") { $gargs += "only=$Only" }
Write-Host "Filming... (the game window shows each shot slowly; leave it be)"
$ErrorActionPreference = "Continue"   # Godot writes warnings to stderr
$t0 = Get-Date
& $godot @gargs 2>&1 | Tee-Object -FilePath "$Root\out\film.log" | Select-String "TRAILER|SCRIPT ERROR"
Write-Host ("Filmed in {0:N1} minutes" -f ((Get-Date) - $t0).TotalMinutes)

$cutsPath = "$userDir\trailer_cuts.json"
if (-not (Test-Path $cutsPath)) { throw "No cuts.json at $cutsPath; see $Root\out\film.log" }
$cuts = Get-Content $cutsPath -Raw | ConvertFrom-Json
$fps = [double]$cuts.fps
foreach ($c in $cuts.cuts) {
    $ss = [string]([double]$c.start / $fps)
    $len = [string](([double]$c.end - [double]$c.start) / $fps)
    $out = "$Root\clips\$($c.name).mp4"
    Write-Host "Cutting $($c.name) ($len s)"
    & $ffmpeg -v error -y -ss $ss -i $raw -t $len -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -c:a aac -b:a 256k -movflags +faststart $out
    & $ffmpeg -v error -y -i $out -vf "fps=1.5,scale=640:-1,tile=3x3" -frames:v 1 "$Root\clips\$($c.name)_sheet.jpg"
}
Copy-Item $cutsPath "$Root\clips\cuts.json" -Force
Write-Host "Done. Clips in $Root\clips"
