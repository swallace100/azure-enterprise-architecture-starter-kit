targetScope = 'resourceGroup'

@description('Key Vault name (must be globally unique within Azure)')
param name string
@description('Region')
param location string
@description('Tags to apply')
param tags object = {}

@description('Enable purge protection (recommended true)')
param purgeProtectionEnabled bool = true
@minValue(7)
@maxValue(90)
@description('Soft delete retention in days (7–90)')
param softDeleteRetentionDays int = 90

@description('Use RBAC authorization instead of access policies')
param rbacAuthorization bool = true

@description('Allow public network access (recommended Disabled; use private endpoints later)')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('IP rules allowed when public network access is Enabled')
param allowedIpCidrs array = []

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enablePurgeProtection: purgeProtectionEnabled
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionDays
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: publicNetworkAccess == 'Enabled' ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      ipRules: [for cidr in allowedIpCidrs: { value: cidr }]
      virtualNetworkRules: [] // wire later via Private Endpoints + Private DNS
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: rbacAuthorization
    // No accessPolicies when RBAC is enabled
  }
}

output vaultId string = kv.id
output vaultUri string = kv.properties.vaultUri
