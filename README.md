# azure-enterprise-architecture-starter-kit

This is a Bicep starter kit for Azure enterprise architecture that includes an app. This can be used by a range of organizations to get started almost immediately with Azure ready to go.

## Plan:

### Phase 0 — Core platform (minimal, day-1)

- Subscription-scope deployment creates:

  - Resource groups: rg-platform, rg-network, rg-app, rg-secops

  - Log Analytics workspace, Azure Monitor DCR, diag settings plumbed everywhere

  - Key Vault (RBAC mode), Storage (Data Lake Gen2 enabled), and VNet (hub-lite)

  - Managed Identities for CI/CD and workloads

  - Base Azure Policy assignment (tagging, deny public blob, enforce TLS, disallow RDP/SSH inbound, etc.)

### Phase 1 — App baseline

- Pick one: Azure Container Apps (simpler) or AKS (heavier later).

  - Front Door (WAF) or App GW (WAF), ACR, Application Insights, private endpoints for KV/Storage.

  - Optional: Azure SQL or Cosmos DB module with private endpoints.

### Phase 2 — Data + events

- Event Hub / Service Bus, Data Factory, DL Gen2 zones (raw/curated), scheduled pipelines.

### Phase 3 — Security & governance

- More policies (naming, SKUs, regions), Defender for Cloud plans, workload identity federation (GitHub OIDC) for CI/CD, Secrets rotation.

### Phase 4 — FinOps & observability

- Cost mgmt budgets/alerts, standardized diag-settings module, common Kusto queries/workbooks.

### Architecture

```text
azure-enterprise-starter-bicep/
├─ bicepconfig.json
├─ main.bicep                     # targetScope = 'subscription' (creates RGs & wires modules)
├─ modules/
│  ├─ storage.bicep               # secure storage (no public, private endpoints optional)
│  ├─ keyvault.bicep              # RBAC, purge protection, secrets/keys options
│  ├─ vnet.bicep                  # hub-lite, subnets, service endpoints
│  ├─ loganalytics.bicep          # LA + DCR + common tables
│  ├─ diagnostics.bicep           # attach diag settings to any resource
│  ├─ containerapps.bicep         # env, workload profile, app sample (later)
│  ├─ acr.bicep
│  ├─ policy.bicep                # starter policy set (deny public, enforce tags/TLS)
│  └─ identities.bicep
├─ environments/
│  ├─ dev/
│  │  └─ sub.bicepparam
│  └─ prod/
│     └─ sub.bicepparam
├─ scripts/
│  ├─ deploy-sub.sh
│  └─ deploy-sub.ps1
└─ .github/workflows/
   └─ deploy.yml                  # GitHub OIDC → az deployment sub create


```

### One-Line to Deploy

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters @environments/dev/sub.bicepparam

```
