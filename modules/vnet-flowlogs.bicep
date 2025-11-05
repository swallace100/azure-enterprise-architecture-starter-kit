targetScope = 'resourceGroup'

@description('Region for Network Watcher and flow logs')
param location string

@description('Virtual Network resource ID to enable flow logs on')
param virtualNetworkId string

@description('Storage account resource ID to store raw flow logs')
param storageAccountId string

@description('Log Analytics workspace resource ID for Traffic Analytics')
param logAnalyticsWorkspaceResourceId string

@description('Enable Traffic Analytics (LA-based) in addition to raw logs')
param enableTrafficAnalytics bool = true

@description('Traffic Analytics interval in minutes (10 or 60)')
@allowed([10, 60])
param trafficAnalyticsInterval int = 60

@description('Retention (days) for storage log container; 0 = infinite')
@minValue(0)
@maxValue(3650)
param storageRetentionDays int = 0

var vnetName = last(split(virtualNetworkId, '/'))

// Ensure a Network Watcher exists in this region (idempotent)
resource watcher 'Microsoft.Network/networkWatchers@2023-11-01' = {
  name: 'NetworkWatcher_${location}'
  location: location
}

// VNet flow logs (child of watcher)
resource vnetFlow 'Microsoft.Network/networkWatchers/flowLogs@2023-11-01' = {
  name: 'vnetFlowLog-${vnetName}'
  parent: watcher
  location: location
  properties: {
    targetResourceId: virtualNetworkId
    enabled: true

    // flowLogType removed — Azure infers VNet vs NSG from targetResourceId

    storageId: storageAccountId
    retentionPolicy: {
      days: storageRetentionDays
      enabled: storageRetentionDays > 0
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: enableTrafficAnalytics
      ? {
          networkWatcherFlowAnalyticsConfiguration: {
            enabled: true
            workspaceResourceId: logAnalyticsWorkspaceResourceId
            workspaceRegion: location
            trafficAnalyticsInterval: trafficAnalyticsInterval
          }
        }
      : null
  }
}

output flowLogsId string = vnetFlow.id
