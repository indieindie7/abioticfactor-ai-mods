param([string[]]$Mods = @("AFDump"))
# Copy repo mods into the game's ue4ss\Mods and enable them in mods.txt
$m = "C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64\ue4ss\Mods"
foreach ($n in $Mods) {
  Remove-Item "$m\$n" -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item "$PSScriptRoot\$n" "$m\$n" -Recurse -Force
  $t = Get-Content "$m\mods.txt" | Where-Object { $_ -notmatch "^$n\s*:" }
  $i = [array]::IndexOf($t, ($t | Where-Object { $_ -match '^; Built-in keybinds' } | Select -First 1))
  if ($i -lt 0) { $i = $t.Count }
  $t = @($t[0..($i-1)]) + "$n : 1" + @($t[$i..($t.Count-1)])
  $t | Set-Content -Encoding ascii "$m\mods.txt"
}
