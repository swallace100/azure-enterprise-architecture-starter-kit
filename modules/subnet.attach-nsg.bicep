targetScope = 'resourceGroup'

@description('VNet name')
param vnetName string

@description('Subnet name')
param subnetName string

@description('NSG resource ID to attach')
param nsgId string

@description('Subnet address prefix (must match existing)')
param addressPrefix string

// Update/ensure the subnet references the NSG
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: addressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroup: { id: nsgId }
  }
}
