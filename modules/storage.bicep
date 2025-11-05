targetScope = 'resourceGroup'

@allowed(['TLS1_2', 'TLS1_3'])
param minTlsVersion string
param name string
param location string
param tags object
param enableHierNs bool = true
param allowBlobPublicAccess bool = false
param allowSharedKeyAccess bool = false
param defaultActionDeny bool = true

@description('If provided, diagnostic settings will be sent to this Log Analytics workspace')
param logAnalyticsWorkspaceId string = ''

@description('Also emit diagnostics for File/Queue/Table services (optional)')
param enableFileQueueTableDiag bool = false

// ---------------- Storage Account ----------------
resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
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

// ---------- Service subresources (use parent syntax) ----------
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: st
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = if (enableFileQueueTableDiag) {
  name: 'default'
  parent: st
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = if (enableFileQueueTableDiag) {
  name: 'default'
  parent: st
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = if (enableFileQueueTableDiag) {
  name: 'default'
  parent: st
}

// ---------------- Diagnostics (scope to service, not account) ----------------
// Blob diagnostics
resource blobDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  name: 'diag-to-la-blob'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'StorageRead', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageWrite', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageDelete', enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
    // Metrics categories vary; 'Transaction' is widely supported at service scope.
    metrics: [
      { category: 'Transaction', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      // If you later see a category error for 'Capacity', just remove/add based on region/support.
      // { category: 'Capacity',    enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
  }
}

// Optional: File/Queue/Table diagnostics (only if enabled)
resource fileDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '' && enableFileQueueTableDiag) {
  name: 'diag-to-la-file'
  scope: fileService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'StorageRead', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageWrite', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageDelete', enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
    metrics: [
      { category: 'Transaction', enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
  }
}

resource queueDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '' && enableFileQueueTableDiag) {
  name: 'diag-to-la-queue'
  scope: queueService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'StorageRead', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageWrite', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageDelete', enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
    metrics: [
      { category: 'Transaction', enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
  }
}

resource tableDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '' && enableFileQueueTableDiag) {
  name: 'diag-to-la-table'
  scope: tableService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'StorageRead', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageWrite', enabled: true, retentionPolicy: { days: 0, enabled: false } }
      { category: 'StorageDelete', enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
    metrics: [
      { category: 'Transaction', enabled: true, retentionPolicy: { days: 0, enabled: false } }
    ]
  }
}

output storageId string = st.id
