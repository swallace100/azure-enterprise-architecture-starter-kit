targetScope = 'resourceGroup'

@allowed([ 'TLS1_2' 'TLS1_3' ])
param minTlsVersion string
param name string
param location string
param tags object
param enableHierNs bool = true
param allowBlobPublicAccess bool = false
param allowSharedKeyAccess bool = false
param defaultActionDeny bool = true
@description('If provided, diagnostic settings will be sent to this LA workspace')
param logAnalyticsWorkspaceId string = ''

resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  sku: { name: 'Standard_LRS' }
  kind: enableHierNs ? 'StorageV2' : 'StorageV2'
  tags: tags
  properties: {
    minimumTlsVersion: minTlsVersion
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    isHnsEnabled: enableHierNs
    networkAcls: {
      defaultAction: defaultActionDeny ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

@description('Optional diagnostic settings to Log Analytics')
resource stDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  name: 'diag-to-la'
  scope: st
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'StorageRead', enabled: true }
      { category: 'StorageWrite', enabled: true }
      { category: 'StorageDelete', enabled: true }
    ]
    metrics: [
      { category: 'Transaction', enabled: true }
      { category: 'Capacity',   enabled: true }
    ]
  }
}

output storageId string = st.id
