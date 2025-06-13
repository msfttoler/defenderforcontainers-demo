# 🛡️ Azure Container Apps + Microsoft Defender for Containers Demo

This Terraform-based demo deploys a secure Azure Container Apps environment using Microsoft Defender for Containers and OWASP Juice Shop — a known vulnerable application used to showcase runtime security, vulnerability scanning, and policy enforcement.

---

## 🎯 What This Demo Shows

- Deployment of OWASP Juice Shop in Azure Container Apps
- Integration with Microsoft Defender for Containers (agentless runtime + ACR scanning)
- Log forwarding to Log Analytics for investigation and dashboarding
- Azure Policy to **restrict container images** to your private ACR
- End-to-end security posture monitoring using Defender and Azure-native tools

---

## 🚀 Quick Start

### 📦 Prerequisites

- Terraform CLI ≥ 1.4
- Azure CLI logged in: `az login`
- Docker installed and running (to push Juice Shop image)

### ⚙️ Deploy the Environment

```bash
terraform init
terraform apply -auto-approve