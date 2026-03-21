// azure-webapp-template — base infrastructure stack
// Parametrised by appName, location, computeType (swa | functionapp), includeIdeasBoard

@description('Application name — used as prefix for all resources.')
param appName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Compute type: swa = Static Web App + integrated Functions; functionapp = standalone Consumption-plan Function App.')
@allowed(['swa', 'functionapp'])
param computeType string = 'swa'

@description('Provision Table Storage and ideas table for the /ideas board feature.')
param includeIdeasBoard bool = true

@description('Environment tag applied to all resources.')
param environment string = 'production'

// ── Derived names ─────────────────────────────────────────────────────────────
var prefix = 'fh-${appName}'
var keyVaultName = 'kv-${prefix}'
var logAnalyticsName = 'log-${prefix}'
var appInsightsName = 'appi-${prefix}'
var identityName = 'id-${prefix}'
// Storage account names: 3-24 chars, lowercase alphanumeric only
var storageAccountName = 'st${take(replace(replace(appName, '-', ''), '_', ''), 14)}${take(uniqueString(resourceGroup().id), 8)}'
var needsStorage = computeType == 'functionapp' || includeIdeasBoard

var tags = {
  app: appName
  environment: environment
  managedBy: 'bicep'
}

// ── User-Assigned Managed Identity ────────────────────────────────────────────
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

// ── Log Analytics Workspace ───────────────────────────────────────────────────
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ── Application Insights ──────────────────────────────────────────────────────
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ── Key Vault ─────────────────────────────────────────────────────────────────
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

// Key Vault Secrets User role — lets the Managed Identity read secrets
var kvSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentity.id, kvSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Storage Account (Function App runtime or Ideas board) ─────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (needsStorage) {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = if (needsStorage) {
  parent: storageAccount
  name: 'default'
}

resource ideasTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = if (includeIdeasBoard) {
  parent: tableService
  name: 'ideas'
}

// Storage Table Data Contributor — lets the Managed Identity read/write table rows
var storageTableContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (needsStorage) {
  name: guid(storageAccount.id, managedIdentity.id, storageTableContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableContributorRoleId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Static Web App (swa mode) ─────────────────────────────────────────────────
resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = if (computeType == 'swa') {
  name: 'swa-${prefix}'
  location: location
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

// ── Function App (functionapp mode) ───────────────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = if (computeType == 'functionapp') {
  name: 'asp-${prefix}'
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = if (computeType == 'functionapp') {
  name: 'func-${prefix}'
  location: location
  kind: 'functionapp'
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          // Use account name (not connection string) — auth via Managed Identity
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: managedIdentity.properties.clientId
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVault.properties.vaultUri
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentity.properties.clientId
        }
      ]
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output storageAccountName string = needsStorage ? storageAccount.name : ''
output staticWebAppDefaultHostname string = computeType == 'swa' ? staticWebApp.properties.defaultHostname : ''
output functionAppDefaultHostname string = computeType == 'functionapp' ? functionApp.properties.defaultHostName : ''
