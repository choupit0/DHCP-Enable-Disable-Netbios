# Script Name    : DHCP-Enable-Disable-Netbios.ps1
# Description    : Script to enable or disable Netbios on DHCP servers ("Advanced" scopes options)
# Author         : https://github.com/choupit0
# Site           : https://hack2know.how/
# Date           : 20220318
# Version        : 1.0.0
# Usage          : .\DHCP-Enable-Disable-Netbios.ps1
# Prerequisites  : N/A
#
# Example change with ScopeId 192.168.160.0 (OptionId "1" added x2):
#
# OptionId Name                              Type        Value                      VendorClass                    UserClass PolicyName
# -------- ----                              ----        -----                      -----------                    --------- ----------
# 66       Boot Server Host Name             String      {192.168.4.50}                                                                  
# 67       Bootfile Name                     String      {smsboot\x64\wdsnbp.com}                                                      
# 3        Router                            IPv4Address {192.168.160.1}                                                                 
# 6        DNS Servers                       IPv4Address {192.168.8.13, 192.168.8.14}                                                      
# 15       DNS Domain Name                   String      {acme.corp}                                                                
# 51       Lease                             DWord       {691200}                                                                      
# 150      Cisco TFTP Server                 IPv4Address {192.168.4.193, 192.168.4.194}                                                    
# 1        Microsoft Disable Netbios Option  DWord       {2}                        Microsoft Windows 2000 Options  <---- Netbios feature disabled                   
# 1        Microsoft Disable Netbios Option  DWord       {2}                        Microsoft Options               <---- Netbios feature disabled
#                                               

# Get the complete list of DHCP servers in the domain
$DHCPServersList = Get-DhcpServerInDC

# View list of DHCP servers
Write-Host -ForegroundColor Green "`nDHCP Servers list:"
$DHCPServersList

# DHCP Server Selection
$DHCPServer = Read-Host -Prompt "`nOn which DHCP server you want to proceed?`nPlease, specify the hostname (preferred) or IPv4 address"

# We check that the server is reachable as well as the associated IPv4 address
if ($DHCPServer -eq "") {
    Write-Warning -Message "`nBad input: please, specify the hostname (preferred) or IPv4 address."
    Break
    } else {
        Write-Host -ForegroundColor Yellow "We are testing the network connectivity and retrieve the IPv4 address...`nSometimes, the DNS name does not corresponding to the IPv4 address."
        Test-Connection -ComputerName $DHCPServer -Count 4 | ft -AutoSize        
}

# Choice to enable or disable Netbios
$NetbiosStatus = Read-Host -Prompt "`nDo you want Enable or Disable Netbios?`nPlease, answer by ENABLE or DISABLE"
if ($NetbiosStatus -eq "ENABLE") {
    Write-Host -ForegroundColor Red "`nOK, we will (re-)enable Netbios on the DHCP scopes (not secure)."
    } elseif ($NetbiosStatus -eq "DISABLE") {
        Write-Host -ForegroundColor Green "`nOK, we will disable Netbios on the DHCP scopes (secure)."
    } else {
        Write-Warning -Message "`nBad input: please, ENABLE or DISABLE."
        Break
    }

# Confirmation that you want to run the script
$Agreement = Read-Host -Prompt "`nWARNING: Do you want to proceed on the DHCP server ($DHCPServer)?`nPlease, answer by YES or NO"
if ($Agreement -eq "YES") {
    Write-Host -ForegroundColor Green "`nOK, we continue.`n"
    } elseif ($Agreement -eq "NO") {
        Write-Host -ForegroundColor Red "`nWe are stopping now."
        Break
    } else {
        Write-Warning -Message "`nBad input: please, YES or NO."
        Break
    }

# Execution time of the script on the DHCP server and log the changes
$Date = Get-Date -Format h-m-s_dd-MM-yyyy
Start-Transcript "$env:TEMP\$DHCPServer-$NetbiosStatus-netbios-$Date.txt"
$Duration = [Diagnostics.Stopwatch]::StartNew()

# List of scopes of the selected DHCP server
$ScopesList = Get-DhcpServerv4Scope -ComputerName $DHCPServer

# We loop on the scopes to make the change
foreach ($Scope in $ScopesList) {
    if ($NetbiosStatus -eq "DISABLE") {
        # Disable Netbios
        Set-DhcpServerv4OptionValue -ComputerName $DHCPServer -ScopeId "$($Scope.ScopeId)" -OptionId 001 -VendorClass "Microsoft Options" -Value 0x2
        Set-DhcpServerv4OptionValue -ComputerName $DHCPServer -ScopeId "$($Scope.ScopeId)" -OptionId 001 -VendorClass "Microsoft Windows 2000 Options" -Value 0x2
        Write-Host -ForegroundColor Gray "Netbios disabled on the scope: $($Scope.ScopeId)"
        Write-Host -ForegroundColor Yellow "Verification after the changes on the scope $($Scope.ScopeId):"
        Get-DhcpServerv4OptionValue -ComputerName $DHCPServer -ScopeId "$($Scope.ScopeId)" -All | ft -AutoSize
        } elseif ($NetbiosStatus -eq "ENABLE") {
            # Enable Netbios
            Remove-DhcpServerv4OptionValue -ComputerName $DHCPServer -ScopeId "$($Scope.ScopeId)" -OptionId 001 -VendorClass "Microsoft Options"
            Remove-DhcpServerv4OptionValue -ComputerName $DHCPServer -ScopeId "$($Scope.ScopeId)" -OptionId 001 -VendorClass "Microsoft Windows 2000 Options"
            Write-Host -ForegroundColor Gray "Netbios (re)-enabled on the scope: $($Scope.ScopeId)"
            Write-Host -ForegroundColor Yellow "Verification after the changes on the scope $($Scope.ScopeId):"
            Get-DhcpServerv4OptionValue -ComputerName $DHCPServer -ScopeId "$($Scope.ScopeId)" -All | ft -AutoSize
        } else {
            Write-Warning -Message "Problem! we are stopping now."
            Break
        }
    }
    
$Duration.Stop()
$Duration.Elapsed
Stop-Transcript

Exit
