param(
    [Parameter(Mandatory=$true)]
    [string]$BastionHost,

    [Parameter(Mandatory=$true)]
    [string]$KeyPath,

    [Parameter(Mandatory=$false)]
    [int]$LocalPort = 8443,

    [Parameter(Mandatory=$false)]
    [string]$DomainHost = "vpc-malawi-pg-elk-cluster-s5fqgvti5w3popzer6dv5ziz5m.eu-central-1.es.amazonaws.com",

    [Parameter(Mandatory=$false)]
    [string]$BastionUser = "ubuntu"
)

# Simple pre-flight checks
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Error "OpenSSH client (ssh) not found in PATH. Install 'OpenSSH Client' Optional Feature on Windows."
    exit 1
}

if (-not (Test-Path -Path $KeyPath)) {
    Write-Error "KeyPath not found: $KeyPath"
    exit 1
}

Write-Host "Opening SSH tunnel: localhost:$LocalPort -> $DomainHost:443 via $BastionUser@$BastionHost" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to close the tunnel." -ForegroundColor Yellow

# Start a foreground SSH session so the user can close it with Ctrl+C
# -N: Do not execute commands, just forward ports
# -L: Local port forward
# -i: Identity file
ssh -i "$KeyPath" -L $LocalPort:$DomainHost:443 "$BastionUser@$BastionHost" -N