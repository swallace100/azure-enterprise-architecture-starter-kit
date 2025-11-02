targetScope = 'subscription'

@description('Log Analytics workspace resource ID to receive Activity Logs')
param logAnalyticsWorkspaceId string

@description('Diagnostic settings name')
param name string = 'activitylog-to-la'

@description('Route metrics, in addition to logs')
param enableMetrics bool = true

@description('Optional log retention (days). 0 = use LA workspace retention.')
@minValue(0)
@maxValue(3650)
param retentionDays int = 0

// Subscription Activity Log categories
var categories = [
  'Administrative'
  'Security'
  'ServiceHealth'
  'Alert'
  'Recommendation'
  'Policy'
  'Autoscale'
  'ResourceHealth'
]

resource subDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: name
  // Scope is the current subscription (control-plane Activity Log)
  scope: subscription()
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [for c in categories: {
      category: c
      enabled: true
      retentionPolicy: {
        enabled: retentionDays > 0
        days: retentionDays
      }
    }]
    metrics: enableMetrics ? [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: retentionDays > 0
          days: retentionDays
        }
      }
    ] : []
    // No data collection rules at this scope
  }
}

output diagnosticSettingsId string = subDiag.id
