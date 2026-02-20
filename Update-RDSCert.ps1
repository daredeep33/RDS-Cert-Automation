<#
.SYNOPSIS
    Automates the renewal and application of a Tailscale-issued certificate for a Windows Server 2019
    Remote Desktop Services deployment, with robust verification and error handling.

.DESCRIPTION
    This script is designed to be run as a scheduled task. It verifies all RDS roles,
    fetches the latest certificate from Tailscale, handles errors gracefully, and provides
    clear before-and-after reporting. All user-specific settings are loaded from a
    separate 'config.ps1' file.

.NOTES
    - Must be run as an Administrator.
    - Requires OpenSSL to be installed and accessible.
    - Do not enter personal information here. Create a 'config.ps1' file for your settings.
#>

# --- SCRIPT LOGIC ---

# Get the directory where this script is located.
$scriptPath = $PSScriptRoot

# Load user configuration from a separate file.
$configFile = Join-Path $scriptPath "config.ps1"
if (-not (Test-Path $configFile)) {
    Write-Error "Configuration file not found. Please copy 'config.template.ps1' to 'config.ps1' and fill in your details."
    exit 1
}
. $configFile

# --- HELPER FUNCTION ---
function Get-RDSCertificateDetails {
    param([string]$Role)
    try {
        $certInfo = Get-RDCertificate -Role $Role -ConnectionBroker $rdConnectionBroker -ErrorAction Stop
        if ($certInfo) {
            Write-Host "  - Role: '$($Role)' | Expires: $($certInfo.ExpiresOn) | Thumbprint: $($certInfo.Thumbprint)"
            return $certInfo.Thumbprint
        }
    } catch {
        Write-Warning "  - Could not retrieve certificate info for role '$Role'. The role may not be configured on this server."
    }
    return $null
}

# 1. Initial Checks
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator."; exit 1
}
if (-not (Test-Path $tailscaleExePath)) { Write-Error "Tailscale executable not found. Update the path in config.ps1."; exit 1 }
if (-not (Test-Path $openSslExePath)) { Write-Error "OpenSSL executable not found. Update the path in config.ps1."; exit 1 }

Write-Host "Starting RDS Certificate Renewal Process..."
Import-Module RemoteDesktop -ErrorAction Stop

# 2. Verification Step (BEFORE)
Write-Host "`n--- Verifying Certificates BEFORE update ---"
$existingThumbprints = @{}
foreach ($role in $allRoles) {
    $existingThumbprints[$role] = Get-RDSCertificateDetails -Role $role
}

# 3. Get New Certificate from Tailscale
$certFile = Join-Path $scriptPath "$($domainName).crt"
$keyFile = Join-Path $scriptPath "$($domainName).key"
$pfxFile = Join-Path $scriptPath "$($domainName).pfx"
Remove-Item $certFile, $keyFile, $pfxFile -ErrorAction SilentlyContinue

Write-Host "`nRequesting new certificate from Tailscale for '$domainName'..."
try {
    Set-Location $scriptPath
    & $tailscaleExePath cert $domainName
    if (-not (Test-Path $certFile) -or -not (Test-Path $keyFile)) {
        throw "Tailscale command ran but did not create the certificate/key files."
    }
    Write-Host "Successfully received certificate and key files."
} catch {
    Write-Error "Failed to get certificate from Tailscale. Error: $_"; exit 1
}

# 4. Create and Import PFX
Write-Host "Creating and importing PFX file..."
$pfxPasswordSecure = ConvertTo-SecureString -String $pfxPassword -AsPlainText -Force
$opensslArgs = @("pkcs12", "-export", "-out", $pfxFile, "-inkey", $keyFile, "-in", $certFile, "-password", "pass:$pfxPassword")
try {
    & $openSslExePath $opensslArgs
    if (-not (Test-Path $pfxFile)) {
        throw "OpenSSL command ran but did not create the PFX file."
    }
    $newCert = Import-PfxCertificate -FilePath $pfxFile -CertStoreLocation "Cert:\LocalMachine\My" -Password $pfxPasswordSecure -ErrorAction Stop
    $newCertThumbprint = $newCert.Thumbprint
    Write-Host "Successfully created and imported PFX. New thumbprint: $newCertThumbprint"
} catch {
    Write-Error "Failed to create or import PFX file. Error: $_"; exit 1
}

# 5. Compare and Apply Certificate
if ($existingThumbprints.Values -contains $newCertThumbprint) {
    Write-Host "`nCertificate is already up to date and in use by one or more RDS roles. No action needed."
} else {
    Write-Host "`nNew certificate detected. Applying to configured RDS roles..."
    foreach ($role in $allRoles) {
        if ($existingThumbprints[$role]) {
            Write-Host "Applying certificate to '$role' role..."
            try {
                if ($role -eq "RDGateway") {
                    Write-Host "  - Stopping TSGateway service..."
                    Stop-Service -Name "TSGateway" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 5
                }
                Set-RDCertificate -Role $role -ImportPath $pfxFile -Password $pfxPasswordSecure -ConnectionBroker $rdConnectionBroker -Force -ErrorAction Stop
                Write-Host "  - Successfully applied certificate to '$role'."
            } catch {
                Write-Error "  - FAILED to apply certificate to '$role'. Error: $_"
            } finally {
                if ($role -eq "RDGateway") {
                    Write-Host "  - Starting TSGateway service..."
                    Start-Service -Name "TSGateway"
                }
            }
        } else {
            Write-Host "Skipping role '$role' as it does not appear to be configured."
        }
    }
}

# 6. Verification Step (AFTER)
Write-Host "`n--- Verifying Certificates AFTER update ---"
foreach ($role in $allRoles) {
    Get-RDSCertificateDetails -Role $role
}

Write-Host "`nScript finished."
