$ErrorActionPreference = "Stop"

Write-Host "[1/4] Fix localStorage keys to match pre-split main.dart"

# myTeams key を分割前と一致
$path = "lib\data\my_teams.dart"
if (Test-Path $path) {
  $content = Get-Content $path -Raw
  $content = $content -replace "const String _kMyTeamsStorageKey = 'my_teams_v1';",
                                "const String _kMyTeamsStorageKey = 'myTeams';"
  Set-Content $path $content
}

# latest match key を分割前と一致
$targets = @(
  "lib\data\latest_match.dart",
  "lib\screens\result_screen.dart",
  "lib\screens\match_screen.dart"
)

foreach ($f in $targets) {
  if (Test-Path $f) {
    $c = Get-Content $f -Raw
    $c = $c -replace "'latest_match_result'", "'latestMatchResult'"
    Set-Content $f $c
  }
}

Write-Host "[2/4] Normalize latestMatchResult structure and sharing"

$matchScreen = "lib\screens\match_screen.dart"
if (Test-Path $matchScreen) {
  $c = Get-Content $matchScreen -Raw
  $c = $c -replace "Map<String, dynamic>\s*get\s*_match\s*=>\s*latestMatchResult!;",
                   "Map<String, dynamic> get _match => latestMatchResult ??= <String, dynamic>{};"
  Set-Content $matchScreen $c
}

Write-Host "[3/4] Restore MatchScreen construction parity"

$setupScreen = "lib\screens\setup_screen.dart"
if (Test-Path $setupScreen) {
  $c = Get-Content $setupScreen -Raw
  $c = $c -replace "const MatchScreen\(\)", "MatchScreen()"
  Set-Content $setupScreen $c
}

Write-Host "[4/4] Enforce initialization order in main.dart"

$main = "lib\main.dart"
if (Test-Path $main) {
  $c = Get-Content $main -Raw
  $c = $c -replace "void main\(\)\s*\{\s*loadMyTeamsBestEffort\(\);\s*loadLatestMatchResult\(\);\s*runApp",
                   "void main() {`n  loadMyTeamsBestEffort();`n  loadLatestMatchResult();`n  runApp"
  Set-Content $main $c
}

Write-Host "Patch applied."
Write-Host "Next:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter build web"
