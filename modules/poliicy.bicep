targetScope = 'subscription'

@description('Subscription to assign policies to')
param targetSubscriptionId string = subscription().subscriptionId

@description('Tags that must exist on resources')
param requiredTags array = [
  'org'
  'env'
  'owner'
]

var policyPrefix = 'starter' // rename for your org

// ---------------------
// Policy: Require tags
// ---------------------
resource polRequireTags 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: '${policyPrefix}-require-tags'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Require specific tags on resources'
    description: 'Ensures required tags are present on all resources.'
    metadata: {
      category: 'Tags'
      version: '1.0.0'
    }
    parameters: {
      requiredTags: {
        type: 'Array'
        metadata: {
          displayName: 'Required tag names'
        }
      }
    }
    policyRule: {
      if: {
        field: 'type'
        notEquals: 'Microsoft.Resources/subscriptions/resourceGroups'
      }
      then: {
        effect: 'deny'
        condition: {
          anyOf: [
            for t in requiredTags: {
              field: '[concat(''tags['', '''', t, '''', '']'')]'
              exists: false
            }
          ]
        }
      }
    }
  }
}

// ---------------------------------------
// Policy: Enforce minimum TLS 1.2 on PaaS
// (storage accounts in this starter)
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
resource initiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '${policyPrefix}-base-initiative'
  properties: {
    displayName: 'Starter baseline initiative'
    description: 'Tag hygiene + TLS + no public blob.'
    metadata: { category: 'Compliance', version: '1.0.0' }
    policyType: 'Custom'
    parameters: {
      requiredTags: {
        type: 'Array'
        metadata: { displayName: 'Required tag names' }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: polRequireTags.id
        parameters: {
          requiredTags: { value: requiredTags }
        }
      }
      { policyDefinitionId: polEnforceTls.id }
      { policyDefinitionId: polDenyPublicBlob.id }
    ]
  }
}

// ------------------------------
// Initiative Assignment
// ------------------------------
resource assignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${policyPrefix}-baseline-assignment'
  scope: subscription(targetSubscriptionId)
  properties: {
    displayName: 'Starter baseline assignment'
    policyDefinitionId: initiative.id
    enforcementMode: 'Default'
    parameters: {
      requiredTags: { value: requiredTags }
    }
  }
}

output initiativeId string = initiative.id
output assignmentId string = assignment.id
