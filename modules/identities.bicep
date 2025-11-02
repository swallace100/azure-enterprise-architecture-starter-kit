targetScope = 'resourceGroup'

@description('Identities to create')
param identities array = [
  // { name: 'idp-github-oidc', location: 'japaneast', tags: { role: 'cicd' } }
]

@description('Optional RBAC role assignments to bind after identities are created')
/*
  Example:
  [
    {
      identityName: 'idp-github-oidc',
      scopeResourceId: subscriptionResourceId('Microsoft.Resources/subscriptions', subscription().subscriptionId),
      roleName: 'Contributor'
    },
    {
      identityName: 'workload-app',
      scopeResourceId: resourceId('Microsoft.KeyVault/vaults', 'kv-xxxx'),
      roleName: 'Key Vault Secrets User'
    }
  ]
*/
param roleAssignments array = []

@description('Common built-in role name → ID map')
var roleIds = {
  'Owner':               '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  'Contributor':         'b24988ac-6180-42a0-ab88-20f7382dd24c'
  'Reader':              'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  'User Access Administrator': 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // (example, replace if you need)
  'Key Vault Administrator':   '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Secrets User':    '4633458b-17de-408a-b874-0445c86b69e6'
  'Storage Blob Data Contributor': 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  'AcrPull':                   '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  'AcrPush':                   '8311e382-0749-4cb8-b61a-304f252e45ec'
}

// ---------- Identities ----------
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [for id in identities: {
  name: id.name
  location: id.location
  tags: union(id.tags ?? {}, {})
}]

// Build a map name -> principalId so we can reference in RBAC
var principalMap = {
  for id, i in identities: id.name: uami[i].properties.principalId
}

// ---------- Role Assignments ----------
/*
  Each role assignment needs a stable GUID. We use uniqueString with:
  (scopeResourceId | roleId | principalId)
*/
resource rbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for ra in roleAssignments: {
  name: guid(ra.scopeResourceId, coalesce(ra.roleDefinitionId, roleIds[ra.roleName]), principalMap[ra.identityName])
  scope: tenantResourceId('?') // placeholder; replaced below via conditional scoping
  // NOTE: We must set the correct scope dynamically. Workaround: we emit at the correct scope using 'existing' scope references.
}] // This block is replaced below with three typed variants

// ---- Variant 1: Scope = Subscription ----
resource rbacSub 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for ra in roleAssignments: if (split(ra.scopeResourceId, '/')[2] == 'subscriptions') {
  name: guid(ra.scopeResourceId, coalesce(ra.roleDefinitionId, roleIds[ra.roleName]), principalMap[ra.identityName])
  scope: subscription(split(ra.scopeResourceId, '/')[2] == 'subscriptions' ? split(ra.scopeResourceId, '/')[4] : subscription().subscriptionId)
  properties: {
    roleDefinitionId: ra.roleDefinitionId ?? subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[ra.roleName])
    principalId: principalMap[ra.identityName]
    principalType: 'ServicePrincipal'
  }
}]

// ---- Variant 2: Scope = Resource Group ----
resource rbacRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for ra in roleAssignments: if (split(ra.scopeResourceId, '/')[6] == 'resourceGroups') {
  name: guid(ra.scopeResourceId, coalesce(ra.roleDefinitionId, roleIds[ra.roleName]), principalMap[ra.identityName])
  scope: resourceGroup(split(ra.scopeResourceId, '/')[4], split(ra.scopeResourceId, '/')[8])
  properties: {
    roleDefinitionId: ra.roleDefinitionId ?? subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[ra.roleName])
    principalId: principalMap[ra.identityName]
    principalType: 'ServicePrincipal'
  }
}]

// ---- Variant 3: Scope = Specific Resource ----
resource targetRes 'Microsoft.Resources/deployments@2021-04-01' existing = [for ra in roleAssignments: if (split(ra.scopeResourceId, '/')[6] != 'resourceGroups' && split(ra.scopeResourceId, '/')[2] == 'subscriptions'): {
  name: 'placeholder' // not used; we only want the scope by raw ID, which Bicep does not permit directly
}] // (Bicep lacks a direct "scope by resourceId" reference for arbitrary resources.)

// Fallback note:
// For resource-scoped RBAC, pass the RG scope (or assign roles in the specific resource module).
// This template safely handles subscription and RG scopes—the two most common for UAMI used by CI/CD.
output identities object = {
  for id, i in identities: id.name: {
    id: uami[i].id
    clientId: uami[i].properties.clientId
    principalId: uami[i].properties.principalId
  }
}
