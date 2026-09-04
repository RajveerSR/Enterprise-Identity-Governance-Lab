[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\tests\Run-Tests.ps1')
if (-not $?) { exit 1 }
