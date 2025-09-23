# Tailscale RDS Certificate Automation

This repository contains a PowerShell script to automatically renew a Tailscale-issued TLS certificate and apply it to a Windows Remote Desktop Services (RDS) deployment.

## Features

-   **Automated Renewal**: Fetches the latest certificate from Tailscale.
-   **PFX Creation**: Automatically creates a PFX file required by RDS using OpenSSL.
-   **Smart Updates**: Compares the new certificate's thumbprint with the currently installed one and only applies updates when necessary.
-   **Full RDS Role Support**: Applies the certificate to the RDPublishing, RDWebAccess, RDGateway, and RDRedirector roles.
-   **Verification**: Provides "before" and "after" reporting to confirm the certificate status.
-   **Secure**: Keeps all user-specific secrets and settings in a separate `config.ps1` file, which is ignored by Git.

## Prerequisites

1.  **Windows Server**: A server with a configured Remote Desktop Services deployment.
2.  **Tailscale**: The Tailscale client must be installed and authorized, with HTTPS certificates enabled for your domain.
3.  **OpenSSL**: OpenSSL must be installed and accessible. You can get it by installing Git for Windows or from other pre-compiled sources.
4.  **PowerShell**: The script should be run with an administrative PowerShell session.

## Setup and Usage

1.  **Clone the Repository**
    ```powershell
    git clone https://github.com/YourUsername/Your-Repository-Name.git
    cd Your-Repository-Name
    ```

2.  **Create Your Configuration**
    Copy the template file to create your own private configuration.
    ```powershell
    Copy-Item -Path .\config.template.ps1 -Destination .\config.ps1
    ```

3.  **Edit `config.ps1`**
    Open `config.ps1` in an editor and fill in the variables with your specific information:
    -   `$domainName`: Your full Tailscale machine name (e.g., `my-rds-server.tailnet-name.ts.net`).
    -   `$openSslExePath`: The full path to your `openssl.exe`.
    -   `$pfxPassword`: A strong, unique password to protect the PFX file.

4.  **Run the Script Manually**
    Before automating, run the script once from an administrative PowerShell session to ensure it works correctly.
    ```powershell
    .\Update-RDSCert.ps1
    ```

5.  **Automate with Task Scheduler**
    Once you confirm the script runs successfully, create a scheduled task to run it automatically (e.g., once a week or once a month).
    -   **Action**: `Start a program`
    -   **Program/script**: `powershell.exe`
    -   **Add arguments**: `-NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\Your\Repo\Update-RDSCert.ps1"`
    -   **Run as**: `SYSTEM`
    -   **Configure for**: `Windows Server 2019`
    -   Check **"Run with highest privileges"**.
