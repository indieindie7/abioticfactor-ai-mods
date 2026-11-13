# test route (no focus): restart client, open Facility, spawn player, give item. Usage: run_route.ps1 [item] [count]
param([string]$Item = "bandage", [int]$Count = 3)
$w = "C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64"
Get-Process AbioticFactor-Win64-Shipping -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 4
foreach ($n in 'FairCrew','AfPilot') { Copy-Item "C:\re\abioticfactor\mod\$n" "$w\ue4ss\Mods" -Recurse -Force }
Remove-Item C:\re\abioticfactor\faircrew_log.txt, C:\re\abioticfactor\pilot_out.txt -ErrorAction SilentlyContinue
Start-Process "$w\AbioticFactor-Win64-Shipping.exe" -ArgumentList ("-graphicsadapter=" + $(if ($env:AF_ADAPTER) { $env:AF_ADAPTER } else { '0' })) -WindowStyle Minimized
$c = "C:\re\abioticfactor\pilot_cmd.txt"
Start-Sleep 55; Set-Content $c "exec open Facility" -Encoding ascii
Start-Sleep 45; Set-Content $c "call W_Character_Trait_Selection_C CompleteTraitSelection" -Encoding ascii
Start-Sleep 8;  Set-Content $c "give $Item $Count" -Encoding ascii
Start-Sleep 3;  Get-Content C:\re\abioticfactor\pilot_out.txt
