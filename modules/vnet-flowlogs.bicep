targetScope = 'resourceGroup'

@description('Region for the Network Watcher (e.g., japaneast). Must match the watcher region.')
param location string

@description('Virtual Network resource ID to enable flow logs on.')
param virtualNetworkId string

@description('Storage account resource ID to store raw flow logs.')
param storageAccountId string

@description('Log Analytics workspace resource ID for Traffic Analytics.')
param logAnalyticsWorkspaceResourceId string

@description('Set true to enable Traffic Analytics.')
param enableTrafficAnalytics bool = true

@description('Traffic Analytics interval in minutes (10 or 60).')
@allowed([10, 60])
param trafficAnalyticsInterval int = 60

@description('Retention (days) for the storage log container. 0 = infinite/no retention policy.')
@minValue(0)
@maxValue(3650)
param storageRetentionDays int = 0

@description('Region string for the Log Analytics workspace (should match the LAW region). Defaults to `location`.')
param workspaceRegion string = location

var vnetName = last(split(virtualNetworkId, '/'))

// Existing regional Network Watcher in this RG (NetworkWatcherRG).
// Name format is "NetworkWatcher_<region>" (underscore).
resource watcher 'Microsoft.Network/networkWatchers@2023-11-01' existing = {
  name: 'NetworkWatcher_${location}'
}

// Flow logs resource (child of watcher). Scope is inherited from parent.
resource vnetFlow 'Microsoft.Network/networkWatchers/flowLogs@2023-11-01' = {
  parent: watcher
  name: 'vnetFlowLog-${vnetName}'
  location: location
  properties: {
    targetResourceId: virtualNetworkId
    enabled: true
    storageId: storageAccountId

    // Retention only applies if > 0
    retentionPolicy: {
      days: storageRetentionDays
      enabled: storageRetentionDays > 0
    }

    format: {
      type: 'JSON'
      version: 2
    }

    // Optional Traffic Analytics block
    flowAnalyticsConfiguration: enableTrafficAnalytics
      ? {
          networkWatcherFlowAnalyticsConfiguration: {
            enabled: true
            workspaceResourceId: logAnalyticsWorkspaceResourceId
            workspaceRegion: workspaceRegion
            trafficAnalyticsInterval: trafficAnalyticsInterval
          }
        }
      : null
  }
}

output flowLogsId string = vnetFlow.id
