<persist>true</persist>
<powershell>
# Windows Client Setup Script
# This script joins a Windows machine to the domain

$ErrorActionPreference = "Stop"

# Create log directory
New-Item -Path "C:\ClientSetup" -ItemType Directory -Force
Start-Transcript -Path "C:\ClientSetup\client-setup.log" -Append

try {
    Write-Output "Starting Windows Client setup at $(Get-Date)"
    
    # Wait for domain controller to be ready
    Write-Output "Waiting for Domain Controller to be available..."
    $maxWaitTime = 30 # minutes
    $waitInterval = 60 # seconds
    $waitCount = 0
    
    do {
        Start-Sleep -Seconds $waitInterval
        $waitCount++
        $dcReachable = Test-NetConnection -ComputerName "${domain_controller_ip}" -Port 53 -ErrorAction SilentlyContinue
        Write-Output "Checking DC availability (attempt $waitCount/$($maxWaitTime))... $($dcReachable.TcpTestSucceeded)"
        
        if ($waitCount -ge $maxWaitTime) {
            throw "Domain Controller is not reachable after $maxWaitTime minutes"
        }
    } while (-not $dcReachable.TcpTestSucceeded)
    
    Write-Output "Domain Controller is reachable!"

    # Configure network route through pfSense (optional, AWS handles routing)
    Write-Output "Configuring network routing..."
    try {
	Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        New-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop "${pfsense_ip}" -InterfaceAlias "Ethernet" -ErrorAction SilentlyContinue
        Write-Output "Default route updated to use pfSense gateway: ${pfsense_ip}"
    } catch {
        Write-Warning "Could not configure custom route, using default AWS routing"
    }

    # Configure DNS to point to Domain Controller
    Write-Output "Configuring DNS settings..."
    $networkAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
    Write-Output "Setting DNS on adapter: $($networkAdapter.Name)"
    Set-DnsClientServerAddress -InterfaceIndex $networkAdapter.ifIndex -ServerAddresses "${domain_controller_ip}"
    
    # Clear DNS cache
    ipconfig /flushdns
    
    # Test DNS resolution
    Write-Output "Testing DNS resolution for domain..."
    try {
        $dnsTest = Resolve-DnsName -Name "${domain_name}" -ErrorAction SilentlyContinue
        if ($dnsTest) {
            Write-Output "DNS resolution successful"
        } else {
            Write-Warning "DNS resolution failed, but continuing with domain join"
        }
    } catch {
        Write-Warning "DNS test failed: $($_.Exception.Message)"
    }


    # Wait a bit more for AD to be fully ready
    Write-Output "Waiting additional time for Active Directory to be fully initialized..."
    Start-Sleep -Seconds 300 # 5 minutes

    # Join domain
    Write-Output "Attempting to join domain ${domain_name}..."
    $securePassword = ConvertTo-SecureString "${domain_admin_password}" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("${domain_name}\Administrator", $securePassword)
    
    # Alternative credential format
    $altCredential = New-Object System.Management.Automation.PSCredential("Administrator@${domain_name}", $securePassword)
    
    try {
        Add-Computer -DomainName "${domain_name}" -Credential $credential -Force -ErrorAction Stop
        Write-Output "Successfully joined domain with primary credential format"
    } catch {
        Write-Warning "Primary credential format failed: $($_.Exception.Message)"
        try {
            Add-Computer -DomainName "${domain_name}" -Credential $altCredential -Force -ErrorAction Stop
            Write-Output "Successfully joined domain with alternative credential format"
        } catch {
            Write-Error "Both credential formats failed. Domain join unsuccessful."
            throw $_
        }
    }

    Write-Output "Domain join completed successfully!"
    Write-Output "System will restart automatically to complete domain join process"
    
    # Schedule restart
    shutdown /r /t 60 /c "Restarting to complete domain join"
    
} catch {
    Write-Error "Error during client setup: $($_.Exception.Message)"
    Write-Output "Stack trace: $($_.Exception.StackTrace)"
    
    # Log error details
    $errorDetails = @{
        Error = $_.Exception.Message
        StackTrace = $_.Exception.StackTrace
        Timestamp = Get-Date
        DCReachable = $(Test-NetConnection -ComputerName "${domain_controller_ip}" -Port 53 -ErrorAction SilentlyContinue).TcpTestSucceeded
    }
    $errorDetails | ConvertTo-Json | Out-File "C:\ClientSetup\error.json"
    
} finally {
    Write-Output "Windows Client setup process finished at $(Get-Date)"
    Stop-Transcript
}
</powershell>
