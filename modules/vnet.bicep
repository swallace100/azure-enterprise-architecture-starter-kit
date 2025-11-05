targetScope = 'resourceGroup'

@description('VNet name')
param name string

@description('Region')
param location string

@description('Tags to apply')
param tags object = {}

@description('Address space list (e.g., ["10.20.0.0/16"])')
param addressSpace array

@description('Subnets: { name, prefix, optional serviceEndpoints: string[], optional delegations: { serviceName }[] }')
param subnets array = []

// --- Normalize so properties always exist (avoid ARM missing-property errors)
var normalizedSubnets = [
  for s in subnets: {
    name: s.name
    prefix: s.prefix
    serviceEndpoints: s.?serviceEndpoints ?? []
    delegations: s.?delegations ?? []
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [
  for sn in normalizedSubnets: {
    parent: vnet
    name: sn.name
    properties: {
      addressPrefix: sn.prefix
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      serviceEndpoints: [for se in sn.serviceEndpoints: { service: se }]
      delegations: [
        for d in sn.delegations: {
          name: 'del-${d.serviceName}'
          properties: { serviceName: d.serviceName }
        }
      ]
    }
  }
]

output vnetId string = vnet.id
output subnetIds array = [for (sn, i) in normalizedSubnets: { name: sn.name, id: subnet[i].id }]
