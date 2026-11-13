# Gym + agent-vs-agent rows on the hidden dedicated test server (no player: PlayerStart is the anchor). Output: stdout of botrows.py srv.
$w = 'C:\re\abioticfactor\tools\steamcmd\steamapps\common\Abiotic Factor Dedicated Server\AbioticFactor\Binaries\Win64'
foreach ($n in 'FairCrew','AfPilot') { Remove-Item "$w\ue4ss\Mods\$n" -Recurse -Force -ErrorAction SilentlyContinue; Copy-Item "$PSScriptRoot\..\$n" "$w\ue4ss\Mods\$n" -Recurse -Force }
$m = Get-Content "$w\ue4ss\Mods\mods.txt"
if (-not ($m -match '^AfPilot')) { $m = $m -replace '^FairCrew : 1.*$', "FairCrew : 1`r`nAfPilot : 1"; $m | Set-Content "$w\ue4ss\Mods\mods.txt" -Encoding ascii }
Remove-Item C:\re\abioticfactor\pilot_out.txt -ErrorAction SilentlyContinue
$env:AF_FAIRSIGHT_TEST = '1'
$p = Start-Process "$w\AbioticFactorServer-Win64-Shipping.exe" -ArgumentList '-log -nosteam -MultiHome=127.0.0.1 -PORT=7779 -QueryPort=27019' -WindowStyle Hidden -PassThru
Start-Sleep 25
py -3.13 -I "$PSScriptRoot\inject.py" $p.Id "$w\ue4ss\UE4SS.dll"
Start-Sleep 30
py -3.13 "$PSScriptRoot\..\test\botrows.py" srv
if ($p.HasExited) { "SERVER EXITED early (code $($p.ExitCode))" } else { Stop-Process -Id $p.Id -Force; "server stopped" }
Select-String -Path "$w\ue4ss\UE4SS.log" -Pattern 'Fatal|AfPilot|error' | Select-Object -Last 8 | ForEach-Object { $_.Line }
