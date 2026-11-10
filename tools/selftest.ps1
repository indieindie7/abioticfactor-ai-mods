param([int]$TimeoutS = 300, [int]$InjectAfterS = 25)
# FairCrew self-test: hidden dedicated server + UE4SS inject, scripted mock player. Result: C:\re\abioticfactor\faircrew_selftest.md
$w = 'C:\re\abioticfactor\tools\steamcmd\steamapps\common\Abiotic Factor Dedicated Server\AbioticFactor\Binaries\Win64'
$out = 'C:\re\abioticfactor\faircrew_selftest.md'
Remove-Item "$w\ue4ss\Mods\FairCrew" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$PSScriptRoot\..\FairCrew" "$w\ue4ss\Mods\FairCrew" -Recurse -Force
Remove-Item $out -ErrorAction SilentlyContinue
$env:AF_FAIRCREW_SELFTEST = '1'
$p = Start-Process "$w\AbioticFactorServer-Win64-Shipping.exe" -ArgumentList '-log -nosteam -MultiHome=127.0.0.1 -PORT=7779 -QueryPort=27019' -WindowStyle Hidden -PassThru
Start-Sleep $InjectAfterS
py -3.13 -I "$PSScriptRoot\inject.py" $p.Id "$w\ue4ss\UE4SS.dll"
$t = 0
while ($t -lt $TimeoutS -and -not $p.HasExited) {
  Start-Sleep 3; $t += 3
  if ((Test-Path $out) -and (Select-String -Path $out -Pattern '^DONE' -Quiet)) { break }
}
if ($p.HasExited) { "SERVER EXITED early (code $($p.ExitCode)) after $t s" } else { Stop-Process -Id $p.Id -Force }
if (Test-Path $out) { Get-Content $out } else { "no result file after $t s" }
Get-Content 'C:\re\abioticfactor\faircrew_srv_log.txt' -Tail 30
