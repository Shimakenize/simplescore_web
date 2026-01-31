param(
  [string]$RepoName = "simplescore_web",
  [string]$Message = "deploy"
)

flutter build web --release --base-href "/$RepoName/"
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

Remove-Item -Recurse -Force .\docs -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path .\docs | Out-Null
Copy-Item -Recurse -Force .\build\web\* .\docs\

git add -A
git commit -m $Message
git push
