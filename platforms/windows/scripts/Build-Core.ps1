[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('win-x64', 'win-arm64')][string]$RuntimeIdentifier,
    [string]$RepositoryRoot = (Resolve-Path "$PSScriptRoot\../../..").Path
)

$goArch = if ($RuntimeIdentifier -eq 'win-x64') { 'amd64' } else { 'arm64' }
$destination = Join-Path $RepositoryRoot 'platforms\windows\src\Bren.App\Helpers\bren-core.exe'
New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
Push-Location (Join-Path $RepositoryRoot 'core')
try {
    $env:GOOS = 'windows'
    $env:GOARCH = $goArch
    $env:CGO_ENABLED = '0'
    go build -trimpath -ldflags='-s -w' -o $destination ./cmd/bren-core
    if ($LASTEXITCODE -ne 0) { throw "go build failed with exit code $LASTEXITCODE" }
}
finally { Pop-Location }
