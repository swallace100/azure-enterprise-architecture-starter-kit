targetScope = 'resourceGroup'

@description('Identities to create. Example: [{ name: "idp-github-oidc", location: "japaneast", tags: { role: "cicd" } }]')
param identities array = []

@description('Optional RBAC role assignments after identities are created. Scope is either "rg" (this RG) or "sub" (current subscription).')
/*
  Example:
  [
    { identityName: 'idp-github-oidc', roleName: 'Contributor', scope: 'sub' },
    { identityName: 'workload-app',    roleName: 'Reader',      scope: 'rg'  }
  ]
  You may also pass roleDefinitionId instead of roleName.
*/
param roleAssignments array = []

@description('Common built-in role name → ID map')
var roleIds = {
  Owner: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  'User Access Administrator': 'f1a07417-d97a-45cb-824c-7a7467783830'
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
  'Storage Blob Data Contributor': 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  AcrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  AcrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
}

/* -----------------------
   Create identities
------------------------ */
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [
  for id in identities: {
    name: id.name
    location: id.location
    tags: id.tags ?? {}
  }
]

/* -----------------------
   Helper: Array of identity names so we can look up an index by name
------------------------ */
var identityNames = [for id in identities: id.name]

/* -----------------------
   Role assignments at SUBSCRIPTION scope (this subscription)
------------------------ */
resource rbacSub 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for ra in roleAssignments: if (ra.scope == 'sub') {
    // find the matching identity index by name
    // NOTE: indexOf returns -1 if not found; consider validating in CI
    name: guid(
      subscription().id,
      (ra.roleDefinitionId ?? roleIds[ra.roleName]),
      uami[indexOf(identityNames, ra.identityName)].id
    )
    properties: {
      roleDefinitionId: ra.roleDefinitionId ?? subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        roleIds[ra.roleName]
      )
      principalId: uami[indexOf(identityNames, ra.identityName)].properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

/* -----------------------
   Role assignments at RESOURCE GROUP scope (this RG)
------------------------ */
resource rbacRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for ra in roleAssignments: if (ra.scope == 'rg') {
    name: guid(
      resourceGroup().id,
      (ra.roleDefinitionId ?? roleIds[ra.roleName]),
      uami[indexOf(identityNames, ra.identityName)].id
    )
    scope: resourceGroup()
    properties: {
      roleDefinitionId: ra.roleDefinitionId ?? subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        roleIds[ra.roleName]
      )
      principalId: uami[indexOf(identityNames, ra.identityName)].properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

/* -----------------------
   Outputs (portable array)
------------------------ */
output identities array = [
  for (id, i) in identities: {
    name: id.name
    id: uami[i].id
    clientId: uami[i].properties.clientId
    principalId: uami[i].properties.principalId
  }
]
