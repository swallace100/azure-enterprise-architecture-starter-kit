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
param subnets array = [
  // Example:
  // {
  //   name: 'snet-app'
  //   prefix: '10.20.10.0/24'
  //   serviceEndpoints: [ 'Microsoft.Storage' ]
  //   delegations: [ { serviceName: 'Microsoft.App/environments' } ]
  // }
]

/* ---------------------------------------------
   Virtual Network
---------------------------------------------- */
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

/* ---------------------------------------------
   Subnets as child resources (loop)
   — Most compatible pattern across Bicep versions
---------------------------------------------- */
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [
  for s in subnets: {
    parent: vnet
    name: '${s.name}'
    properties: {
      addressPrefix: s.prefix
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      serviceEndpoints: [
        for se in (s.serviceEndpoints ?? []): {
          service: se
        }
      ]
      delegations: [
        for d in (s.delegations ?? []): {
          name: 'del-${d.serviceName}'
          properties: {
            serviceName: d.serviceName
          }
        }
      ]
    }
  }
]

/* ---------------------------------------------
   Outputs
---------------------------------------------- */
output vnetId string = vnet.id

// Use the input `subnets` for the loop, and index into the resource collection
output subnetIds array = [
  for (s, i) in subnets: {
    name: s.name
    id: subnet[i].id
  }
]
