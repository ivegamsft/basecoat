# Windows Server to Azure Guidance

This document provides best practices for migrating Windows Server workloads to Azure, including image selection, Desired State Configuration (DSC) provisioning, and operational patterns.

## Windows Server Image Selection

### Azure Marketplace Images

Choose the appropriate base image for your workload:

| Image | Version | Support End | Use Case |
|---|---|---|---|
| **Windows Server 2016** | RTM | 01/13/2027 | Legacy applications requiring .NET Framework 4.x |
| **Windows Server 2019** | LTSC | 01/09/2029 | Standard production workloads |
| **Windows Server 2022** | LTSC | 10/13/2031 | Modern applications, latest security patches |
| **Azure Stack HCI** | 21H2 | 12/13/2026 | Hybrid and edge scenarios |

### VM Size Recommendations

Select compute based on workload profile:

```
General Purpose (Dsv3, Esv3):
- Web servers, small databases, development/test
- 1-4 vCPUs, 4-16 GB RAM
- Burstable for unpredictable workloads

Memory Optimized (Esv5, Msv2):
- SQL Server, enterprise apps, in-memory caching
- 4-64 vCPUs, 32-1024 GB RAM
- Consistent high memory demand

Compute Optimized (Fsv2):
- Batch processing, scientific simulations
- High CPU-to-memory ratio
- Sustained compute workloads
```

## Desired State Configuration (DSC) Provisioning

### DSC Overview

DSC enables infrastructure-as-code for Windows configuration management:

```powershell
# Define desired state for a web server
Configuration WebServerConfig {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    
    Node 'localhost' {
        # Install Windows features
        WindowsFeature IIS {
            Name = 'Web-Server'
            Ensure = 'Present'
        }
        
        WindowsFeature ASP {
            Name = 'Web-Asp-Net45'
            Ensure = 'Present'
            DependsOn = '[WindowsFeature]IIS'
        }
        
        # Create website
        Website DefaultSite {
            Ensure = 'Present'
            Name = 'Default Web Site'
            State = 'Started'
            DependsOn = '[WindowsFeature]IIS'
        }
    }
}

# Compile configuration to MOF file
WebServerConfig -OutputPath C:\DSC
```

### DSC Extension in Azure

Deploy DSC configurations via Azure VMs:

```powershell
# Create VM and apply DSC
$vm = New-AzVm `
  -ResourceGroupName 'prod-rg' `
  -Name 'web-vm-01' `
  -Image 'MicrosoftWindowsServer:WindowsServer:2022-Datacenter:latest'

# Upload DSC configuration to storage
Publish-AzVMDscConfiguration `
  -ConfigurationPath 'C:\DSC\WebServerConfig.ps1' `
  -ResourceGroupName 'prod-rg' `
  -StorageAccountName 'dscstgacct' `
  -Force

# Apply DSC to VM
Set-AzVMDscExtension `
  -ResourceGroupName 'prod-rg' `
  -VMName 'web-vm-01' `
  -ArchiveBlobName 'WebServerConfig.ps1.zip' `
  -ArchiveStorageAccountName 'dscstgacct' `
  -ConfigurationName 'WebServerConfig' `
  -Version '2.9' `
  -AutoUpdate $true
```

### DSC Patterns for Enterprise

#### Role-Based Configuration

Define configurations by role (web, database, cache):

```powershell
Configuration RoleBasedConfig {
    param([string[]]$NodeName, [hashtable]$ConfigData)
    
    foreach ($node in $NodeName) {
        $role = $ConfigData.Nodes | Where-Object { $_.NodeName -eq $node } | 
                Select-Object -ExpandProperty Role
        
        if ($role -contains 'WebServer') {
            WebServerRole $node
        }
        if ($role -contains 'Database') {
            DatabaseRole $node
        }
    }
}

# Configuration data
$configData = @{
    AllNodes = @(
        @{
            NodeName = 'web-01'
            Role = @('WebServer')
            PsdAllowPlainTextPassword = $true
        },
        @{
            NodeName = 'db-01'
            Role = @('Database')
            PsdAllowPlainTextPassword = $true
        }
    )
}
```

#### Parity with On-Premises

Ensure Azure VMs match on-premises configuration:

```powershell
# Extract current configuration
Get-DscLocalConfigurationManager
Get-DscConfiguration
Get-WindowsFeature | Where-Object { $_.Installed }
Get-Service | Where-Object { $_.Status -eq 'Running' }

# Export to DSC for Azure deployment
Configuration CurrentState {
    node 'localhost' {
        # Mirror every installed role, feature, and setting
    }
}
```

## Image Provisioning Workflow

### Custom Image Creation

Build custom images with pre-installed software:

```powershell
# Create generalized image for reuse
$resourceGroupName = 'image-rg'
$imageName = 'web-server-2022'
$vmName = 'image-builder'

# Deploy builder VM
$vm = New-AzVm `
  -ResourceGroupName $resourceGroupName `
  -Name $vmName `
  -Image 'MicrosoftWindowsServer:WindowsServer:2022-Datacenter:latest'

# Connect and install software (IIS, .NET, etc.)
# Then generalize
Invoke-AzVMRunCommand `
  -ResourceGroupName $resourceGroupName `
  -Name $vmName `
  -CommandId 'RunPowerShellScript' `
  -ScriptPath 'C:\prepare-image.ps1'

# Generalize VM
Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force
Set-AzVm -ResourceGroupName $resourceGroupName -Name $vmName -Generalized

# Create image
$vm = Get-AzVM -Name $vmName -ResourceGroupName $resourceGroupName
$image = New-AzImageConfig `
  -SourceVirtualMachineId $vm.ID

New-AzImage `
  -Image $image `
  -ImageName $imageName `
  -ResourceGroupName $resourceGroupName
```

### Scaling from Image

Deploy multiple VMs from custom image:

```powershell
$imageId = "/subscriptions/.../resourceGroups/image-rg/providers/Microsoft.Compute/images/web-server-2022"

for ($i = 1; $i -le 3; $i++) {
    New-AzVm `
      -ResourceGroupName 'prod-rg' `
      -Name "web-vm-$i" `
      -ImageId $imageId `
      -Size 'Standard_D2s_v3' `
      -PublicIpAddressName "pip-web-$i" `
      -VirtualNetworkName 'prod-vnet' `
      -SubnetName 'web-subnet'
}
```

## Migration Strategies

### Lift & Shift

Move servers with minimal changes:

1. Assess dependencies and network requirements
2. Create network infrastructure (vNet, subnets, NSGs)
3. Deploy VM from Azure Marketplace image
4. Apply DSC configuration to match on-premises state
5. Migrate data (SQL Server, files via Azure Backup)
6. Update DNS and routing
7. Decommission on-premises server

### Hybrid Continuity

Use Azure Site Recovery for minimal downtime:

```powershell
# Enable replication for on-premises VM
Enable-AzRecoveryServicesAsrReplication `
  -VirtualMachine $vm `
  -ReplicationPolicy $replicationPolicy
```

## Network Configuration

### Network Security Groups (NSGs)

Restrict inbound traffic to required ports:

```powershell
$nsgRules = @(
    @{
        Name = 'AllowHTTP'
        Priority = 100
        Direction = 'Inbound'
        Access = 'Allow'
        Protocol = 'TCP'
        SourcePort = '*'
        DestinationPort = 80
        SourceAddress = '*'
        DestinationAddress = '*'
    },
    @{
        Name = 'AllowHTTPS'
        Priority = 101
        Direction = 'Inbound'
        Access = 'Allow'
        Protocol = 'TCP'
        SourcePort = '*'
        DestinationPort = 443
        SourceAddress = '*'
        DestinationAddress = '*'
    },
    @{
        Name = 'DenyRDP'
        Priority = 4096
        Direction = 'Inbound'
        Access = 'Deny'
        Protocol = 'TCP'
        SourcePort = '*'
        DestinationPort = 3389
        SourceAddress = '*'
        DestinationAddress = '*'
    }
)

foreach ($rule in $nsgRules) {
    Add-AzNetworkSecurityRuleConfig @rule `
      -NetworkSecurityGroup $nsg
}
```

### Bastion Host for Secure Access

Remove public IP addresses and use Azure Bastion:

```powershell
# Create Bastion subnet and host
$bastionSubnet = Add-AzVirtualNetworkSubnetConfig `
  -VirtualNetwork $vnet `
  -Name 'AzureBastionSubnet' `
  -AddressPrefix '10.0.254.0/27'

$publicIp = New-AzPublicIpAddress `
  -ResourceGroupName 'prod-rg' `
  -Name 'bastion-pip' `
  -Sku 'Standard' `
  -AllocationMethod 'Static'

$bastion = New-AzBastion `
  -ResourceGroupName 'prod-rg' `
  -Name 'prod-bastion' `
  -PublicIpAddressId $publicIp.Id `
  -VirtualNetworkId $vnet.Id
```

## Monitoring and Compliance

### Azure Monitoring

Enable guest-level monitoring:

```powershell
# Deploy Azure Monitor agent
Set-AzVMExtension `
  -ResourceGroupName 'prod-rg' `
  -VMName 'web-vm-01' `
  -Name 'AzureMonitorWindowsAgent' `
  -Publisher 'Microsoft.Azure.Monitor' `
  -ExtensionType 'AzureMonitorWindowsAgent' `
  -TypeHandlerVersion '1.0'
```

### Compliance: Windows Hardening

Enforce Windows security baselines:

```powershell
# Apply Windows security baseline via DSC
Configuration SecurityBaseline {
    Import-DscResource -ModuleName SecurityPolicyDsc
    
    Node 'localhost' {
        # Disable SMBv1
        Registry SMBv1 {
            Ensure = 'Present'
            Key = 'HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters'
            ValueName = 'SMB1'
            ValueData = '0'
            ValueType = 'DWORD'
        }
        
        # Enforce TLS 1.2
        Registry TLS12 {
            Ensure = 'Present'
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'Enabled'
            ValueData = '1'
            ValueType = 'DWORD'
        }
    }
}
```

## Base Coat Assets

- Agent: `agents/containerization-planner.agent.md`
- Skill: `skills/azure-compute/`
- Instruction: `instructions/dsc-provisioning.instructions.md`

## References

- [Azure Windows VM Documentation](https://docs.microsoft.com/azure/virtual-machines/windows/)
- [Windows Server on Azure Marketplace](https://azuremarketplace.microsoft.com/marketplace/apps?filters=windows-server)
- [PowerShell Desired State Configuration](https://docs.microsoft.com/powershell/dsc/overview)
- [Azure Bastion Documentation](https://docs.microsoft.com/azure/bastion/)
- [Windows Security Baselines](https://docs.microsoft.com/windows/security/threat-protection/windows-security-baselines)
