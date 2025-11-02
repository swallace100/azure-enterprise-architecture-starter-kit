targetScope = 'resourceGroup'

@description('VNet name')
param name string

@description('Region')
param location string

@description('Tags to apply')
param tags object = {}

@description('Address space list (e.g., ["10.20.0.0/16"])')
param addressSpace array

@description('Subnets definition: name, prefix, optional serviceEndpoints (string[]), delegations (array of { serviceName: string })')
param subnets array = [
  // Example:
  // {
  //   name: 'snet-app'
  //   prefix: '10.20.10.0/24'
  //   serviceEndpoints: [ 'Microsoft.Storage' ]
  //   delegations: [
  //     { serviceName: 'Microsoft.App/environments' }
  //   ]
  // }
]

/*
  Normalize subnet inputs up-front so we don't nest for-expressions in properties.
*/
var normalizedSubnets = [
  for s in subnets: {
    name: s.name
    prefix: s.prefix
    serviceEndpointsObjs: empty(s.serviceEndpoints)
      ? []
      : [
          for se in s.serviceEndpoints: {
            service: se
          }
        ]
    delegationsObjs: empty(s.delegations)
      ? []
      : [
          for d in s.delegations: {
            name: 'del-${d.serviceName}'
            properties: {
              serviceName: d.serviceName
              actions: []
            }
          }
        ]
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
    subnets: [
      for sn in normalizedSubnets: {
        name: sn.name
        properties: {
          addressPrefix: sn.prefix
          privateEndpointNetworkPolicies: 'Disabled' // friendly for Private Endpoints later
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: sn.serviceEndpointsObjs
          delegations: sn.delegationsObjs
        }
      }
    ]
  }
}

output vnetId string = vnet.id

// Older Bicep versions can choke on object-comprehension in outputs,
// so we emit an array of {name, id} pairs for portability.
output subnetIds array = [
  for s in vnet.properties.subnets: {
    name: s.name
    id: s.id
  }
]
