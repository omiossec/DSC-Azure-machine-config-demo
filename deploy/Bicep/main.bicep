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







resource myVM 'Microsoft.Compute/virtualMachines@2021-03-01' existing = {
  name: '<vm_name>'
}

resource myConfiguration 'Microsoft.GuestConfiguration/guestConfigurationAssignments@2020-06-25' = {
  name: configurationName
  scope: myVM
  location: resourceGroup().location
  properties: {
    guestConfiguration: {
      name: configurationName
      contentUri: '<Url_to_Package.zip>'
      contentHash: '<SHA256_hash_of_package.zip>'
      version: '1.*'
      assignmentType: assignmentType
    }
  }
}
