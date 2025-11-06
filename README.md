![Azure](https://img.shields.io/badge/Azure-Bicep-blue?logo=microsoftazure)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

# Azure Enterprise Architecture Starter Kit

This repository provides a **subscription-scope Bicep blueprint** for standing up a secure, enterprise-ready Azure landing zone with baseline governance, networking, monitoring, and identity — deployable in minutes.

It’s designed for teams who want Azure **ready on Day 1** with best-practice defaults.

---

## What gets deployed automatically

- **Resource groups**
  - `rg-platform`, `rg-network`, `rg-app`, `rg-secops`
- **Networking**
  - Hub-lite VNet, subnets, private-endpoint-safe configuration
- **Security**
  - Key Vault (RBAC), TLS enforcement, deny public blob, managed identities
- **Observability**
  - Log Analytics workspace + Data Collection Rule + diagnostics wired in
- **Governance**
  - Base Azure Policy initiative (tagging, TLS, no public blob)

---

## Repository Structure

````text
azure-enterprise-architecture-starter-kit/
├─ main.bicep                     # subscription-scope entry point
├─ modules/
│  ├─ vnet.bicep
│  ├─ vnet-flowlogs.bicep
│  ├─ storage.bicep
│  ├─ keyvault.bicep
│  ├─ loganalytics.bicep
│  ├─ diagnostics.bicep
│  ├─ policy.bicep
│  └─ identities.bicep
├─ environments/
│  ├─ dev/sub.parameters.json
│  └─ prod/sub.parameters.json
└─ scripts/
   ├─ deploy-sub.sh
   └─ deploy-sub.ps1

## Deploy (CLI)

```bash
az login --tenant <TENANT_ID> --use-device-code
az account set --subscription "<SUBSCRIPTION_ID>"

az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters @environments/dev/sub.parameters.json

````

Re-running is safe — the template is idempotent.

## GitHub Actions (OIDC) — optional

This repo includes `.github/workflows/deploy.yml` that deploys using federated identity (no Azure secrets needed).

If using this, create three encrypted GitHub secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Cleanup (to avoid cost)

```bash
az group delete -n rg-platform-dev -y
az group delete -n rg-network-dev -y
az group delete -n rg-app-dev -y
az group delete -n rg-secops-dev -y

```

## License

MIT. Free for personal or commercial use.
