# DSC-Azure-machine-config-demo
Demo Azure Machine configuration with DSC and PowerShell

there are some requirement 

- a windows machine with PowerShell 7
- an Azure tenant
- VS Code
- GuestConfiguration PwSh module
- an azure Storage Account

## DSC

First we need to configure the local machine

instal THE PSDesiredStateConfiguration
But besure to not install the 3.0 version

```powershell
install-module -name PSDesiredStateConfiguration -Repository PSGallery -MaximumVersion 2.99 -force
```

and the PsdResources module

```powershell
  install-module -name PsdscResources -Repository PSGallery -force
```

Finally the GuestConfiguration module is also needed

```powershell
Install-Module -Name GuestConfiguration -Repository PSGallery
```

now we can load the config file in the DSC folder and compile the DSC configuration

```powershell 
. .\demo.dsc.ps1
demoDevTo
```

As a result we have a loacalhost.mof file in the demoDecTo folder

The next step is to create a configuration package that will be consume by Azure Machine configuration
First we need to rename the localhost.mof file to demodevto.mof

```powershell
rename-item -path .\demoDevTo\localhost.mof -NewName "demodevto.mof" -passThru
```

Then we can create the package we can use audit or enforce here we use enforce

```powershell
New-GuestConfigurationPackage -name "demodevto" -type "AuditAndSet" -Configuration ".\demoDevTo\demodevto.mof" -force $true 
```

The zip file, demodevto.zip, generated by the new-GuestConfiguration can be send to the container in a storage account

```powershell
$storageAccount = get-azStorageAccount -name "demodscomc001" -resourcegroup "demo-dsc"


set-azStorageBlobContent -container "packages" -file ".\demodevto.zip" -blob "demodevto.zip" -context $storageAccount.context -force 
```

## VM requierement

The Guest Configuration package can be only apply to a VM if it had a managed identity and the Microsoft.Guestconfiguration extension.
The managed identity and the extension can be enabled via Azure Policy

The 2 policies install the extension and configure the VM to use a system

## Delivering the package

There are two way to deliver the package to a VM. You can deploy on each VM with IaC like Bicep, ARM Template or Terraform, or at scale by using Azure Policy.

For both we need to have the SAS URI for the package 

```powershell
$today = Get-Date
$expirationDate = $today.AddYears(1)



$strPackageURI = New-AzStorageBlobSASToken -Context $storageAccount.context -Container "packages" -Blob "demodevto.zip" -Permission r -ExpiryTime $expirationDate -FullUri
```

### Bicep

The first to do is to get the SHA256 hash of the package file created by the gest configuration command

```powershell
$packageHash = Get-FileHash -Path ./demodevto.zip -Algorithm SHA256
```

We also need to get the SAS uri of the package in the storage account 

The bicep template to deploy the configuration 

```bicep
@description('Name of the Configuration')
param configurationName string

@description('type of assignment')
@allowed([
  'ApplyAndAutoCorrect'
  'ApplyAndMonitor'
  'Audit'
  'DeployAndAutoCorrect'
])
param assignmentType string = 'ApplyAndAutoCorrect'

@description('The SAS URI of the package')
param packageSasUri string

@description('package SHA256 hash')
param packageHash string


@description('Target VM name')
param vmName string


resource targetVM 'Microsoft.Compute/virtualMachines@2021-03-01' existing = {
  name: vmName
}

resource myConfiguration 'Microsoft.GuestConfiguration/guestConfigurationAssignments@2020-06-25' = {
  name: configurationName
  scope: targetVM
  location: resourceGroup().location
  properties: {
    guestConfiguration: {
      name: configurationName
      contentUri: packageSasUri
      contentHash: packageHash
      version: '1.*'
      assignmentType: assignmentType
    }
  }
}

```

to deploy the configuration 

```powershell
New-AzResourceGroupDeployment -Name ParamDeployment -ResourceGroupName demo-dsc -TemplateFile ./deploy/bicep/main.bicep -configurationName "demodevto" -packageSasUri $strPackageURI -packageHash $packageHash.Hash -vmName "vm01"

```

### Azure Policy

To deploy a configuration at sscale, you will have to use Azure Policy. To help you create the policy you will have to use the New-GuestConfigurationPolicy


```powershell

$guid = new-guid

New-GuestConfigurationPolicy -policyId $guid.Guid -ContentUri $strPackageURI -DisplayName "demoDevTo" -Description "Demo Policy for Dev.to" -path "./deploy/policy/" -platform "windows" -policyVersion "1.0.0" -Mode "ApplyAndAutoCorrect"
```

You need to have a Guid for the policy name, it takke a the blob URI, a display Name and a description, the path to the folder to store the policy, the plateform, the version of the configuration and the mode (ApplyAndMonitor, ApplyAndAutoCorrect, or Audit).

You don't have to provide the SHA256 hash, the command will do it for you. 

The command generate a deploy if not exist policy, you can edit the policy but you need to ensure that  the guestConfiguration metadata match the deployment.

```json
        "metadata": {
            "category": "Guest Configuration",
            "version": "1.0.0",
            "requiredProviders": [
                "Microsoft.GuestConfiguration"
            ],
            "guestConfiguration": {
                "name": "demodevto",
                "version": "True",
                "contentType": "Custom",
                "contentUri": "https://demodscomc001.blob.core.windows.net/packages/demodevto.zip?sv=2023-08-03&se=2026-05-06T05%3A03%3A10Z&sr=b&sp=r&sig=6wKnMoLQ2hR4OD5cgUXBdHWOjBBDz95%2BfAT8BHOMk60%3D",
                "contentHash": "8A7AEFF27A8BA4F9806E757AA9927A2A41C45F5C6ACB25024A55BA37ED17908D"
            }
        }        "metadata": {
            "category": "Guest Configuration",
            "version": "1.0.0",
            "requiredProviders": [
                "Microsoft.GuestConfiguration"
            ],
            "guestConfiguration": {
                "name": "demodevto",
                "version": "True",
                "contentType": "Custom",
                "contentUri": "https://demodscomc001.blob.core.windows.net/packages/demodevto.zip?sv=2023-08-03&se=2026-05-06T05%3A03%3A10Z&sr=b&sp=r&sig=6wKnMoLQ2hR4OD5cgUXBdHWOjBBDz95%2BfAT8BHOMk60%3D",
                "contentHash": "8A7AEFF27A8BA4F9806E757AA9927A2A41C45F5C6ACB25024A55BA37ED17908D"
            }
        }
```


```json
                                            "guestConfiguration": {
                                                "name": "demodevto",
                                                "version": "True",
                                                "contentType": "Custom",
                                                "contentUri": "https://demodscomc001.blob.core.windows.net/packages/demodevto.zip?sv=2023-08-03&se=2026-05-06T05%3A03%3A10Z&sr=b&sp=r&sig=6wKnMoLQ2hR4OD5cgUXBdHWOjBBDz95%2BfAT8BHOMk60%3D",
                                                "contentHash": "8A7AEFF27A8BA4F9806E757AA9927A2A41C45F5C6ACB25024A55BA37ED17908D",
                                                "assignmentType": "ApplyAndAutoCorrect"
                                            }
```

Also pay attention to the "version" property in the Guest configuration, the command set the value to "True" while it should be "1.0.0".

The deploy if not exist deployment section target Azure Virtual Machines, Azure ARC machines and Azure Scale Set. You can remove this deployment if not needed.

The policy can be added in Azure and assigned to a VM, the deployment can be made when a new VM is created or when a remediation task is created. 