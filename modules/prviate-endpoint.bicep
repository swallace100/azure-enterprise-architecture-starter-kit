param name string
param location string
param targetResourceId string
param subnetId string
param groupIds array // e.g. ['blob'], ['vault'], ['dfs']

resource pep 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: name
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-pls'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: groupIds
          requestMessage: 'Private endpoint created by starter kit'
        }
      }
    ]
  }
}

output id string = pep.id
