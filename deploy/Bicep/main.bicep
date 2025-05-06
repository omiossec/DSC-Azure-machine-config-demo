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
