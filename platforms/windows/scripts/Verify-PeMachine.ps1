[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet('win-x64', 'win-arm64')][string]$RuntimeIdentifier
)

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw "$Path is not a PE executable." }
$offset = [BitConverter]::ToInt32($bytes, 0x3c)
$machine = [BitConverter]::ToUInt16($bytes, $offset + 4)
$expected = if ($RuntimeIdentifier -eq 'win-x64') { 0x8664 } else { 0xAA64 }
if ($machine -ne $expected) { throw "$Path machine type 0x$('{0:X4}' -f $machine) does not match $RuntimeIdentifier." }
Write-Host "$Path is $RuntimeIdentifier (0x$('{0:X4}' -f $machine))."
