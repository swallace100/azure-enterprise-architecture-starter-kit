targetScope = 'subscription'

@description('Deployment location for RGs and regional resources')
param location string = 'japaneast'

@description('Org/environment tags applied everywhere')
param baseTags object = {
  org: 'acme'
  env: 'dev'
  owner: 'platform'
}

var rgPlatformName = 'rg-platform-${baseTags.env}'
var rgNetworkName  = 'rg-network-${baseTags.env}'
var rgAppName      = 'rg-app-${baseTags.env}'
var rgSecName      = 'rg-secops-${baseTags.env}'

// Resource Groups
resource rgPlatform 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgPlatformName
  location: location
  tags: baseTags
}
resource rgNetwork 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgNetworkName
  location: location
  tags: baseTags
}
resource rgApp 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgAppName
  location: location
  tags: baseTags
}
resource rgSec 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgSecName
  location: location
  tags: baseTags
}

// Log Analytics (platform)
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'logAnalytics'
  scope: resourceGroup(rgPlatform.name)
  params: {
    name: 'log-${baseTags.env}'
    location: location
    tags: baseTags
    retentionDays: 30
  }
}

// VNet (network)
module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  scope: resourceGroup(rgNetwork.name)
  params: {
    name: 'vnet-${baseTags.env}'
    location: location
    addressSpace: [ '10.20.0.0/16' ]
    subnets: [
      { name: 'snet-app', prefix: '10.20.10.0/24' }
      { name: 'snet-data', prefix: '10.20.20.0/24' }
    ]
    tags: baseTags
  }
}

// Key Vault (platform)
module kv 'modules/keyvault.bicep' = {
  name: 'keyVault'
  scope: resourceGroup(rgPlatform.name)
  params: {
    name: 'kv-${uniqueString(subscription().id, baseTags.env)}'
    location: location
    tags: baseTags
    purgeProtectionEnabled: true
    softDeleteRetentionDays: 90
    rbacAuthorization: true
  }
}

// Storage (app)
module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: resourceGroup(rgApp.name)
  params: {
    name: 'st${uniqueString(subscription().id, baseTags.env)}'
    location: location
    tags: baseTags
    enableHierNs: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minTlsVersion: 'TLS1_2'
    defaultActionDeny: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// Starter policy assignment (subscription)
module policy 'modules/policy.bicep' = {
  name: 'basePolicy'
  params: {
    targetSubscriptionId: subscription().subscriptionId
    requiredTags: ['org','env','owner']
  }
}

// Diagnostic Logs
module subActivityLogs 'modules/diagnostics.bicep' = {
  name: 'activityLogs'
  params: {
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    retentionDays: 0
  }
}

// Suppose you created an NSG named nsg-app (not shown here)
module nsgFlow 'modules/nsg-flowlogs.bicep' = {
  name: 'nsgFlowLogsApp'
  scope: resourceGroup(rgNetwork.name)
  params: {
    location: location
    networkSecurityGroupId: nsgApp.id
    storageAccountId: storage.outputs.storageId     // or a dedicated stg in rg-secops
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.workspaceId
    trafficAnalyticsInterval: 60
  }
}

module identities 'modules/identities.bicep' = {
  name: 'uami'
  scope: resourceGroup(rgPlatform.name)
  params: {
    identities: [
      { name: 'idp-github-oidc', location: location, tags: baseTags }
      { name: 'workload-app',    location: location, tags: baseTags }
    ]
    roleAssignments: [
      // CI identity gets Contributor at sub (or RG if you prefer tighter scope)
      {
        identityName: 'idp-github-oidc'
        scopeResourceId: subscriptionResourceId('Microsoft.Resources/subscriptions', subscription().subscriptionId)
        roleName: 'Contributor'
      }
      // Workload identity gets Reader at RG app (fine-tune later)
      {
        identityName: 'workload-app'
        scopeResourceId: resourceGroup(rgApp.name).id
        roleName: 'Reader'
      }
    ]
  }
}
