targetScope = 'subscription'

@description('Organization tag name')
param tagOrg string = 'org'

@description('Environment tag name')
param tagEnv string = 'env'

@description('Owner tag name')
param tagOwner string = 'owner'

var policyPrefix = 'starter'

// Helper for Azure Policy field expression (kept readable):
// Outer quotes are single (Bicep), inner are double (Policy expression).
var tagFieldExpression = '[format("tags[{0}]", parameters("tagName"))]'

// ---------------------
// Policy: Require a single tag
// ---------------------
resource polRequireTag 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}-require-tag'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Require a specific tag on resources'
    description: 'Ensures the specified tag exists on non-RG resources.'
    metadata: {
      category: 'Tags'
      version: '1.0.0'
    }
    parameters: {
      tagName: {
        type: 'String'
        metadata: { displayName: 'Required tag name' }
      }
    }
    policyRule: {
      if: {
        allOf: [
          { field: 'type', notEquals: 'Microsoft.Resources/subscriptions/resourceGroups' }
          { field: tagFieldExpression, exists: 'false' }
        ]
      }
      then: { effect: 'deny' }
    }
  }
}

// ---------------------------------------
// Policy: Enforce minimum TLS 1.2 for Storage
// ---------------------------------------
resource polEnforceTls 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}-enforce-tls12'
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: 'Enforce minimum TLS 1.2 for Storage'
    metadata: { category: 'Security', version: '1.0.0' }
    policyRule: {
      if: {
        allOf: [
          { field: 'type', equals: 'Microsoft.Storage/storageAccounts' }
          { field: 'Microsoft.Storage/storageAccounts/minimumTlsVersion', notEquals: 'TLS1_2' }
        ]
      }
      then: { effect: 'deny' }
    }
  }
}

// --------------------------------------------------
// Policy: Deny public blob access on Storage Accounts
// --------------------------------------------------
resource polDenyPublicBlob 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}-deny-public-blob'
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: 'Deny public blob access on storage accounts'
    metadata: { category: 'Storage', version: '1.0.0' }
    policyRule: {
      if: {
        allOf: [
          { field: 'type', equals: 'Microsoft.Storage/storageAccounts' }
          { field: 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess', equals: true }
        ]
      }
      then: { effect: 'deny' }
    }
  }
}

// ------------------------------
// Initiative (Policy Set)
// ------------------------------
// Expose three parameters at the initiative level so you can override at assignment time.
resource initiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${policyPrefix}-base-initiative'
  properties: {
    displayName: 'Starter baseline initiative'
    description: 'Tag hygiene + TLS + no public blob.'
    metadata: { category: 'Compliance', version: '1.0.0' }
    policyType: 'Custom'
    parameters: {
      tagOrg: { type: 'String', metadata: { displayName: 'Org tag' }, defaultValue: tagOrg }
      tagEnv: { type: 'String', metadata: { displayName: 'Env tag' }, defaultValue: tagEnv }
      tagOwner: { type: 'String', metadata: { displayName: 'Owner tag' }, defaultValue: tagOwner }
    }

    // To reference initiative parameters, we must use Policy expressions as strings.
    policyDefinitions: [
      {
        policyDefinitionId: polRequireTag.id
        parameters: {
          tagName: { value: '[parameters("tagOrg")]' }
        }
      }
      {
        policyDefinitionId: polRequireTag.id
        parameters: {
          tagName: { value: '[parameters("tagEnv")]' }
        }
      }
      {
        policyDefinitionId: polRequireTag.id
        parameters: {
          tagName: { value: '[parameters("tagOwner")]' }
        }
      }
      { policyDefinitionId: polEnforceTls.id }
      { policyDefinitionId: polDenyPublicBlob.id }
    ]
  }
}

// ------------------------------
// Initiative Assignment (current subscription)
// ------------------------------
resource assignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}-baseline-assignment'
  properties: {
    displayName: 'Starter baseline assignment'
    policyDefinitionId: initiative.id
    enforcementMode: 'Default'
    // You can override these at deploy time if you want custom names
    parameters: {
      tagOrg: { value: tagOrg }
      tagEnv: { value: tagEnv }
      tagOwner: { value: tagOwner }
    }
  }
}

output initiativeId string = initiative.id
output assignmentId string = assignment.id
