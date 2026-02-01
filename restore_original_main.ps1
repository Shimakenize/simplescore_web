$ErrorActionPreference = "Stop"

Write-Host "Restoring original single-file main.dart (parity guaranteed)"

# lib/main.dart のサイズ取得
$libMain = "lib\main.dart"
if (-not (Test-Path $libMain)) {
  Write-Error "lib/main.dart not found"
  exit 1
}
$libSize = (Get-Item $libMain).Length

# 候補: プロジェクト直下の .dart ファイルで
# lib/main.dart よりサイズが大きいものを探す
$candidates = Get-ChildItem -Path . -Filter *.dart -File |
  Where-Object { $_.FullName -notmatch '\\lib\\' -and $_.Length -gt $libSize }

if ($candidates.Count -eq 0) {
  Write-Error "Original main.dart candidate not found"
  exit 1
}

# 一番サイズが大きいものを「元の main.dart」とみなす
$original = $candidates | Sort-Object Length -Descending | Select-Object -First 1

Write-Host "Using original file: $($original.Name)"

# 上書き
Copy-Item $original.FullName $libMain -Force

Write-Host "Restore completed."
Write-Host "Next:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter run / flutter build web"
