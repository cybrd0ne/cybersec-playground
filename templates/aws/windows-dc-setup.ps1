<persist>true</persist>
<powershell>
# Domain Controller Setup Script
# This script promotes a Windows Server to Domain Controller

$ErrorActionPreference = "Stop"

# Create log directory
New-Item -Path "C:\DCSetup" -ItemType Directory -Force
Start-Transcript -Path "C:\DCSetup\dc-setup.log" -Append

try {
    Write-Output "Starting Domain Controller setup at $(Get-Date)"
    
    # Configure network route through pfSense (optional, AWS handles routing)
    Write-Output "Configuring network routing..."
    try {
	Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        New-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop "${pfsense_ip}" -InterfaceAlias "Ethernet" -ErrorAction SilentlyContinue
        Write-Output "Default route updated to use pfSense gateway: ${pfsense_ip}"
    } catch {
        Write-Warning "Could not configure custom route, using default AWS routing"
    }

    # Set DNS to self (will be updated after promotion)
    $networkAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
    Write-Output "Configuring DNS on adapter: $($networkAdapter.Name)"
    Set-DnsClientServerAddress -InterfaceIndex $networkAdapter.ifIndex -ServerAddresses "127.0.0.1"

    # Install AD DS role
    Write-Output "Installing Active Directory Domain Services role..."
    $installResult = Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    if ($installResult.Success) {
        Write-Output "AD-Domain-Services installed successfully"
    } else {
        throw "Failed to install AD-Domain-Services: $($installResult.ExitCode)"
    }

    # Create a post-reboot script
    $postRebootScript = @'
# Your post-reboot commands here
Import-Module ActiveDirectory
New-ADUser -Name "Merk Vand" -SamAccountName "${username}" -AccountPassword (ConvertTo-SecureString "${password}" -AsPlainText -Force) -Enabled $true

# Remove this scheduled task after running
Unregister-ScheduledTask -TaskName "PostDCPromotionScript" -Confirm:$false
'@

    Set-Content -Path "C:\DCSetup\post-reboot.ps1" -Value $postRebootScript

    # Create scheduled task to run at startup
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-ExecutionPolicy Bypass -File C:\DCSetup\post-reboot.ps1'
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName "PostDCPromotionScript" -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    # Prepare for domain promotion
    # Set local Administrator password (will become domain Administrator password)
    net user Administrator "${domain_admin_password}"
    Write-Output "Promoting server to Domain Controller..."
    # Prepare safe mode password (DSRM password)
    $securePassword = ConvertTo-SecureString "${domain_admin_password}" -AsPlainText -Force
    
    # Import the ADDSDeployment module
    Import-Module ADDSDeployment -Force
    
    # Install new forest
    Install-ADDSForest `
        -DomainName "${domain_name}" `
        -DomainNetbiosName "CYBERSEC" `
        -DomainMode "WinThreshold" `
        -ForestMode "WinThreshold" `
        -DatabasePath "C:\Windows\NTDS" `
        -LogPath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -SafeModeAdministratorPassword $securePassword `
        -InstallDns:$true `
        -NoRebootOnCompletion:$false `
        -Force:$true

    Write-Output "Domain Controller promotion completed successfully!"
    
} catch {
    Write-Error "Error during DC setup: $($_.Exception.Message)"
    Write-Output "Stack trace: $($_.Exception.StackTrace)"
    
    # Log error details
    $errorDetails = @{
        Error = $_.Exception.Message
        StackTrace = $_.Exception.StackTrace
        Timestamp = Get-Date
    }
    $errorDetails | ConvertTo-Json | Out-File "C:\DCSetup\error.json"
    
} finally {
    Write-Output "Domain Controller setup process finished at $(Get-Date)"
    Stop-Transcript
}

# The system will automatically reboot after domain promotion
</powershell>
