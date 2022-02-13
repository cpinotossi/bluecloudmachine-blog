targetScope='resourceGroup'

param prefix string
param objectIdSp string
param objectIdMe string
param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  name: prefix
}

resource sa 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: prefix
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    supportsHttpsTrafficOnly: true
    customDomain: {
      name: 'blog.bluecloudmachine.org'
    }
  }
}

resource sab 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: sa
  name: 'default'
}

resource sac 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  parent: sab
  name: '$web'
  properties: {
    publicAccess:'None'
  }
}

var roleStorageBlobDataContributorName = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor
var roleContributorName = 'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor

// resource racontributorSp 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: guid(resourceGroup().id,'racontributortSp')
//   scope: sa
//   properties: {
//     principalId: objectIdSp
//     principalType:'ServicePrincipal'
//     roleDefinitionId: tenantResourceId('Microsoft.Authorization/RoleDefinitions',roleContributorName)
//   }
// }

resource rablobcontributorSp 'Microsoft.Authorization/roleAssignments@2018-01-01-preview' = {
  name: guid(resourceGroup().id,'rablobcontributortSp')
  scope: sa
  properties: {
    principalId: objectIdSp
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/RoleDefinitions',roleStorageBlobDataContributorName)
  }
}

resource rablobcontributorMe 'Microsoft.Authorization/roleAssignments@2018-01-01-preview' = {
  name: guid(resourceGroup().id,'rablobcontributortMe')
  scope: sa
  properties: {
    principalId: objectIdMe
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/RoleDefinitions',roleStorageBlobDataContributorName)
  }
}
