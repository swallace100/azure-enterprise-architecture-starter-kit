targetScope = 'subscription'

@description('Log Analytics workspace resource ID to receive Subscription Activity Logs')
param logAnalyticsWorkspaceId string

@description('Enable all Activity Log categories')
param enableAllCategories bool = true

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
  name: 'send-activity-logs-to-law'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      for c in categories: {
        category: c
        enabled: enableAllCategories
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

output diagnosticSettingId string = subDiag.id
