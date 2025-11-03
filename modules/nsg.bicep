targetScope = 'resourceGroup'

@description('NSG name')
param name string

@description('Region')
param location string

@description('Tags')
param tags object = {}

@description('Security rules (array of Microsoft.Network/securityRules schema objects)')
param securityRules array = [
  // Example allow-out:
  {
    name: 'Allow-Internet-Out'
    properties: {
      description: 'Allow outbound to Internet'
      access: 'Allow'
      direction: 'Outbound'
      priority: 4000
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Internet'
    }
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

output nsgId string = nsg.id
output nsgName string = nsg.name
