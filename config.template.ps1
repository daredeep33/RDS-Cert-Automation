# ------------------------------------------------------------------------------------
# CONFIGURATION FOR Update-RDSCert.ps1
#
# INSTRUCTIONS:
# 1. Copy this file and rename it to 'config.ps1'.
# 2. Fill in the variables below with your specific information.
# 3. IMPORTANT: Do NOT commit your 'config.ps1' file to a public repository.
#    The '.gitignore' file should prevent this, but always be careful.
# ------------------------------------------------------------------------------------

# 1. The full Tailscale domain name you are requesting the certificate for.
$domainName = "your-machine-name.your-tailnet.ts.net"

# 2. The FQDN of your RD Connection Broker server. In a single-server setup, this is
#    usually the local computer name.
$rdConnectionBroker = $env:COMPUTERNAME

# 3. The full path to the 'tailscale.exe' command-line tool.
$tailscaleExePath = "C:\Program Files\Tailscale\tailscale.exe"

# 4. The full path to the 'openssl.exe' command-line tool.
$openSslExePath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

# 5. A secure password that will be used to protect the PFX certificate file.
#    This should be a complex, unique password.
$pfxPassword = "Your-Super-Secure-Password-Here!"

# 6. The RDS roles you want to manage.
$allRoles = @("RDPublishing", "RDWebAccess", "RDGateway", "RDRedirector")
