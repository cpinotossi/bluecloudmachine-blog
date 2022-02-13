param storageAccounts_cptdjamstack_name string = 'cptdjamstack'

resource storageAccounts_cptdjamstack_name_resource 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccounts_cptdjamstack_name
  location: 'eastus'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: false
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      resourceAccessRules: []
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
    customDomain: {
      name: 'blog.bluecloudmachine.org'
    }
  }
}

resource storageAccounts_cptdjamstack_name_default 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccounts_cptdjamstack_name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    changeFeed: {
      enabled: false
    }
    restorePolicy: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: false
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
    isVersioningEnabled: false
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_storageAccounts_cptdjamstack_name_default 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' = {
  parent: storageAccounts_cptdjamstack_name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: false
      days: 0
    }
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_storageAccounts_cptdjamstack_name_default 'Microsoft.Storage/storageAccounts/queueServices@2021-06-01' = {
  parent: storageAccounts_cptdjamstack_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_storageAccounts_cptdjamstack_name_default 'Microsoft.Storage/storageAccounts/tableServices@2021-06-01' = {
  parent: storageAccounts_cptdjamstack_name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource storageAccounts_cptdjamstack_name_default_web 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  parent: storageAccounts_cptdjamstack_name_default
  name: '$web'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccounts_cptdjamstack_name_resource
  ]
}