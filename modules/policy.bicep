targetScope = 'subscription'

@description('Short prefix for all policy artifacts')
param policyPrefix string = 'starter'

@description('Tag parameter names used across the initiative')
param tagOrg string
param tagEnv string
param tagOwner string

@description('Resource types to exclude from the tag requirement (lack tags or shouldn’t be enforced)')
param excludedTypes array = [
  'Microsoft.Network/networkWatchers/flowLogs'
  // add more if needed, e.g. 'Microsoft.Insights/diagnosticSettings'
]

// Helper to build 'tags[<name>]' inside the policy expression (must be single-quoted)
var tagField = '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'

// ---------------------
// Require a specific tag
// ---------------------
// ---------------------
// Require a specific tag (updated)
// ---------------------
resource polRequireTag 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}-require-tag'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Require a specific tag on resources'
    description: 'Ensures a required tag is present on resources that support tags.'
    metadata: { category: 'Tags', version: '1.0.2' }
    parameters: {
      tagName: {
        type: 'String'
        metadata: { displayName: 'Required tag name' }
      }
      excludedTypes: {
        type: 'Array'
        metadata: { displayName: 'Excluded resource types' }
        defaultValue: [] // 👈 required for safe updates
      }
    }

    policyRule: {
      if: {
        allOf: [
          // don’t apply to RGs
          { field: 'type', notEquals: 'Microsoft.Resources/subscriptions/resourceGroups' }

          // only apply to resources that actually have a tags bag
          { field: 'tags', exists: 'true' }

          // exclude specific types, if provided
          { not: { field: 'type', in: '[parameters(\'excludedTypes\')]' } }

          // required tag missing
          { field: tagField, exists: 'false' }
        ]
      }
      then: { effect: 'deny' }
    }
  }
}

// ---------------------
// Enforce minimum TLS 1.2 on Storage
// ---------------------
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

// ---------------------
// Deny public blob access
// ---------------------
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

// ---------------------
// Initiative
// ---------------------
resource initiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${policyPrefix}-base-initiative'
  properties: {
    displayName: 'Starter baseline initiative'
    description: 'Tag hygiene + TLS + no public blob.'
    metadata: { category: 'Compliance', version: '1.0.2' } // bumped
    policyType: 'Custom'
    parameters: {
      // bubble up the excluded types to the set so you can tweak at assignment time
      excludedTypes: {
        type: 'Array'
        metadata: { displayName: 'Excluded resource types' }
        defaultValue: excludedTypes
      }
      tagOrg: { type: 'String', defaultValue: 'org' } // <-- add defaultValue
      tagEnv: { type: 'String', defaultValue: 'env' } // <-- add defaultValue
      tagOwner: { type: 'String', defaultValue: 'owner' } // <-- add defaultValue
    }
    policyDefinitions: [
      // Require org
      {
        policyDefinitionId: polRequireTag.id
        parameters: {
          tagName: { value: 'org' }
          excludedTypes: { value: '[parameters(\'excludedTypes\')]' }
        }
      }
      // Require env
      {
        policyDefinitionId: polRequireTag.id
        parameters: {
          tagName: { value: 'env' }
          excludedTypes: { value: '[parameters(\'excludedTypes\')]' }
        }
      }
      // Require owner
      {
        policyDefinitionId: polRequireTag.id
        parameters: {
          tagName: { value: 'owner' }
          excludedTypes: { value: '[parameters(\'excludedTypes\')]' }
        }
      }
      { policyDefinitionId: polEnforceTls.id }
      { policyDefinitionId: polDenyPublicBlob.id }
    ]
  }
}

// ---------------------
// Assignment (sub-scope)
// ---------------------
resource assignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}-baseline-assignment'
  properties: {
    displayName: 'Starter baseline assignment'
    policyDefinitionId: initiative.id
    enforcementMode: 'Default' // set to 'DoNotEnforce' if you need a bootstrap pass
    parameters: {
      excludedTypes: { value: excludedTypes }
      tagOrg: { value: tagOrg }
      tagEnv: { value: tagEnv }
      tagOwner: { value: tagOwner }
    }
  }
}

output initiativeId string = initiative.id
output assignmentId string = assignment.id
