targetScope = 'resourceGroup'

@description('Log Analytics workspace name')
param name string

@description('Region')
param location string

@description('Tags to apply')
param tags object = {}

@description('Retention in days (7–730). 0 uses workspace default.')
@minValue(0)
@maxValue(730)
param retentionDays int = 30

@description('Daily ingestion quota in GB. -1 = unlimited (inherit platform limits)')
param dailyQuotaGb int = -1

@description('Public network access for ingestion (Enabled/Disabled)')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Public network access for query (Enabled/Disabled)')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccessForQuery string = 'Enabled'

@description('Create a default DCR (AMA) that sends common VM streams (Windows Events, Syslog, Perf) to this workspace')
param createDefaultDcr bool = true

@description('Name for the Data Collection Rule (if created)')
param dcrName string = 'dcr-default'

/* ---------------------------
   Log Analytics Workspace
---------------------------- */
resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionDays == 0 ? 30 : retentionDays
    workspaceCapping: { dailyQuotaGb: dailyQuotaGb }
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    features: {
      // Prefer RBAC over shared keys when possible
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

/* ---------------------------------------
   Default Data Collection Rule (for AMA)
   NOTE:
   - Correct stream names
   - Correct XPath pattern: Channel!* (not just "Channel")
   - NO PlatformTelemetry here (must be its own DCR kind)
---------------------------------------- */
resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = if (createDefaultDcr) {
  name: dcrName
  location: location
  tags: tags
  properties: {
    dataSources: {
      windowsEventLogs: [
        {
          name: 'win-events-default'
          streams: [
            'Microsoft-WindowsEvent'
          ]
          xPathQueries: [
            'Security!*'
            'System!*'
            'Application!*'
          ]
        }
      ]
      syslog: [
        {
          name: 'linux-syslog-default'
          streams: ['Microsoft-Syslog']
          facilityNames: ['auth', 'authpriv', 'daemon', 'syslog', 'user', 'kern']
          logLevels: ['Debug', 'Info', 'Notice', 'Warning', 'Error', 'Critical', 'Alert', 'Emergency']
        }
      ]
      performanceCounters: [
        {
          name: 'perf-default'
          streams: ['Microsoft-Perf']
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\Available MBytes'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\LogicalDisk(_Total)\\Disk Reads/sec'
            '\\LogicalDisk(_Total)\\Disk Writes/sec'
            '\\Network Interface(*)\\Bytes Total/sec'
          ]
          samplingFrequencyInSeconds: 60
        }
      ]
      // ❌ Removed platformTelemetry from this DCR.
    }
    destinations: {
      logAnalytics: [
        {
          name: 'la-dest'
          workspaceResourceId: la.id
        }
      ]
    }
    dataFlows: [
      { streams: ['Microsoft-WindowsEvent'], destinations: ['la-dest'] }
      { streams: ['Microsoft-Syslog'], destinations: ['la-dest'] }
      { streams: ['Microsoft-Perf'], destinations: ['la-dest'] }
    ]
  }
}

/* ---------------------------------------
   (Optional) Separate DCR for PlatformTelemetry
   Uncomment ONLY if you truly need it, and do not mix with WindowsEvent/Syslog/Perf.
   Check current allowed streams for PlatformTelemetry in Azure docs.

resource dcrPlatform 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${dcrName}-platform'
  location: location
  kind: 'PlatformTelemetry'
  properties: {
    dataSources: {
      platformTelemetry: [
        {
          name: 'plat-default'
          // streams: [ '<valid-platform-streams-here>' ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        { name: 'la-dest', workspaceResourceId: la.id }
      ]
    }
    dataFlows: [
      // { streams: [ '<valid-platform-streams-here>' ], destinations: [ 'la-dest' ] }
    ]
  }
}
---------------------------------------- */

/* ------------- Outputs ------------- */
output workspaceId string = la.id
output workspaceName string = la.name
output workspaceGuid string = la.properties.customerId
output dcrId string = createDefaultDcr ? dcr.id : ''
