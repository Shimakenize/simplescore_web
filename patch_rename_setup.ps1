$ErrorActionPreference = "Stop"

$target = "lib\main.dart"
if (-not (Test-Path $target)) {
  Write-Error "lib/main.dart not found"
  exit 1
}

$content = Get-Content $target -Raw

# 画面タイトル・見出しの "Setup" 表示を日本語に置換
# ※ 識別可能な表示文字列のみを対象（ロジック不変）
$content = $content `
  -replace 'Match Setup', '設定画面' `
  -replace '\bSetup\b', '設定画面'

Set-Content $target $content

Write-Host "Patch applied: Setup -> 設定画面"
