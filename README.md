<div align="center">

<br/>

<img src="https://raw.githubusercontent.com/Akshatsainiaks/srevox-website/main/public/favicon.svg" width="96" height="96" alt="Srevox Logo"/>

<br/>

# ⚡ Srevox

### **Catch crashes before your users do.**

*Real-time Kubernetes crash detection with AI-powered root cause analysis — fully self-hosted.*

<br/>

[![Docker Pulls](https://img.shields.io/docker/pulls/akshatsaini08/srevox-api?style=for-the-badge&logo=docker&label=Docker%20Pulls&color=0ea5e9&labelColor=0f172a)](https://hub.docker.com/u/akshatsaini08)
[![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red?style=for-the-badge&labelColor=0f172a)](#-license)
[![Go](https://img.shields.io/badge/Go-1.25+-00ADD8?style=for-the-badge&logo=go&logoColor=white&labelColor=0f172a)](https://golang.org)
[![Node](https://img.shields.io/badge/Node-18+-339933?style=for-the-badge&logo=node.js&logoColor=white&labelColor=0f172a)](https://nodejs.org)

<br/>

> 🐳 **No clone needed. Just Docker + a `.env` file.**
> Built for on-prem, VMware, bare-metal, private cloud & air-gapped environments.

<br/>

[🚀 Quick Start](#-quick-start--no-clone-needed) · [🏗️ Architecture](#%EF%B8%8F-architecture) · [🔌 Connect Cluster](#-connect-your-k8s-cluster) · [🤖 AI Diagnosis](#-ai-diagnosis)

</div>

---

## 🌟 Why Srevox?

| Without Srevox | With Srevox |
|---|---|
| 😰 Users report crashes to you | ⚡ You know before users notice |
| 🔍 Manual `kubectl logs` digging | 🤖 AI gives root cause + fix steps |
| 📱 No team alerting | 🔔 Slack, Teams, Email, WhatsApp |
| ☁️ Vendor lock-in monitoring | 🔒 100% self-hosted, data stays yours |
| 🐢 Polling-based, delayed alerts | 🚀 Sub-5s detection via Watch API |

---

## ✨ Feature Highlights

<table>
<tr>
<td width="50%">

**🔍 Detection & Alerting**
- ⚡ Sub-5s crash detection via K8s Watch API
- 🔔 Email, Teams, Slack, WhatsApp, Webhook
- 🛡️ Noise control: cooldowns & restart thresholds
- 🏷️ Namespace & label-based filtering

</td>
<td width="50%">

**🤖 AI-Powered Intelligence**
- 🧠 Root cause analysis on every crash
- 🛠️ Step-by-step `kubectl` fix commands
- 🌐 Groq, OpenAI, Anthropic, or local Ollama
- 🔑 Per-user AI provider configuration

</td>
</tr>
<tr>
<td width="50%">

**🏗️ Infrastructure**
- ☁️ EKS, GKE, AKS, on-prem, k3s, RKE
- 🐳 Docker-native — one `docker-compose.yml`
- 🔒 Runs entirely inside your network
- 💾 PostgreSQL-backed incident history

</td>
<td width="50%">

**👥 Team & Access**
- 👤 Service owner routing
- 🔐 Role-based access (admin/member/viewer)
- 📊 Incident dashboard & acknowledgement
- 🔑 JWT-secured API

</td>
</tr>
</table>

> 👥 **Multi-Tenant Team Isolation**: Team management, user invitation flows, and login evaluation are fully stable. Multiple organizations can safely register the same email address without cross-tenant side-effects or leakage.

---

## 🚀 Quick Start — No Clone Needed

### Prerequisites

```
✅ Docker
✅ Docker Compose
❌ No Kubernetes experience needed for setup
❌ No code to clone or build
```

### Step-by-step Setup

```mermaid
flowchart LR
    A([🖥️ Your Server]) -->|curl setup.sh| B[📥 Download Files]
    B --> C[📝 Edit .env]
    C --> D[🐳 docker compose up]
    D --> E([✅ Srevox Running])

    style A fill:#1e293b,stroke:#6366f1,color:#e2e8f0
    style B fill:#1e293b,stroke:#0ea5e9,color:#e2e8f0
    style C fill:#1e293b,stroke:#f59e0b,color:#e2e8f0
    style D fill:#1e293b,stroke:#22c55e,color:#e2e8f0
    style E fill:#16a34a,stroke:#22c55e,color:#ffffff
```

**1️⃣ One-command setup**

```bash
curl -fsSL https://raw.githubusercontent.com/Akshatsainiaks/srevox-setup/main/setup.sh | bash
```

**2️⃣ Configure your environment**

```bash
cd srevox && nano .env
```

```env
# ── Required ─────────────────────────────────────────────────────
POSTGRES_PASSWORD=your_secure_password
BACKEND_SECRET_KEY=any_random_32_char_string_here__   # min 32 chars
ENCRYPTION_KEY=exactly_32_chars_here____________       # exactly 32 chars
NEXT_PUBLIC_API_URL=http://YOUR_SERVER_IP:4000
FRONTEND_URL=http://YOUR_SERVER_IP:3000

# ── AI Diagnosis (pick one) ───────────────────────────────────────
AI_PROVIDER=groq                                       # groq | openai | anthropic | ollama
GROQ_API_KEY=gsk_...                                   # free at console.groq.com
```

**3️⃣ Launch**

```bash
docker compose up -d
```

| Service | URL | Default Credentials |
|---|---|---|
| 🖥️ Dashboard | `http://YOUR_SERVER_IP:3000` | `admin@srevox.local` / `admin123` |
| 🔌 API | `http://YOUR_SERVER_IP:4000` | JWT-secured |

> ⚠️ **Change the default password immediately after first login.**

---

## 🏗️ Architecture

### System Overview

```mermaid
graph TB
    subgraph K8S["☸️ Kubernetes Cluster"]
        P1[Pod: healthy]
        P2[Pod: 💥 crashing]
        P3[Pod: healthy]
        AG[🕵️ Srevox Agent\nGo Watcher]
        P2 -->|Watch API event| AG
    end

    subgraph SREVOX["🏠 Your Internal Network — Srevox Stack"]
        direction TB
        R[(🔴 Redis 7\nPub/Sub)]
        W[⚙️ Alert Worker\nNode.js]
        API[🚀 API Server\nFastify :4000]
        DB[(🐘 PostgreSQL 16\nIncidents + Config)]
        AI[🤖 AI Service\nDiagnosis Engine]
        FE[🖥️ Dashboard\nNext.js :3000]

        R -->|srevox:crashes| W
        W -->|Save incident| DB
        W -->|Trigger diagnosis| AI
        AI -->|Update incident| DB
        API <-->|Query/Update| DB
        FE <-->|REST/WS| API
    end

    subgraph CHANNELS["📣 Alert Channels"]
        SL[Slack]
        TE[Teams]
        EM[Email]
        WA[WhatsApp]
        WH[Webhook]
    end

    subgraph AI_PROVIDERS["🧠 AI Providers"]
        GR[Groq]
        OA[OpenAI]
        AN[Anthropic]
        OL[Ollama\nLocal/Offline]
    end

    AG -->|Publish JSON| R
    W --> SL & TE & EM & WA & WH
    AI --> GR & OA & AN & OL

    style K8S fill:#0f172a,stroke:#6366f1,color:#e2e8f0
    style SREVOX fill:#0f172a,stroke:#0ea5e9,color:#e2e8f0
    style CHANNELS fill:#0f172a,stroke:#22c55e,color:#e2e8f0
    style AI_PROVIDERS fill:#0f172a,stroke:#f59e0b,color:#e2e8f0
```

### Crash Detection Flow

```mermaid
sequenceDiagram
    participant K8s as ☸️ Kubernetes API
    participant Agent as 🕵️ Srevox Agent
    participant Redis as 🔴 Redis
    participant Worker as ⚙️ Alert Worker
    participant AI as 🤖 AI Service
    participant Channel as 📣 Alert Channel
    participant DB as 🐘 PostgreSQL
    participant User as 👤 Engineer

    K8s->>Agent: Pod enters OOMKilled / CrashLoopBackOff
    Note over Agent: Watch stream event — no polling
    Agent->>Redis: PUBLISH srevox:crashes {JSON}
    Redis->>Worker: Event received (<5s)
    Worker->>Worker: Apply filters, cooldowns, rules
    Worker->>DB: Save incident
    Worker->>Channel: Send alert (Slack/Teams/Email/WA)
    Channel-->>User: 🔔 Notification
    User->>AI: Click "AI Diagnosis"
    AI->>K8s: Fetch pod logs & events
    AI->>AI: Analyze with LLM
    AI-->>User: Root cause + kubectl fix commands
```

### Alert Rule Evaluation

```mermaid
flowchart TD
    E([📨 Crash Event]) --> F1{Namespace\nfiltered?}
    F1 -->|Yes| DROP1([🚫 Drop])
    F1 -->|No| F2{Restart count\n≥ threshold?}
    F2 -->|No| DROP2([🚫 Drop])
    F2 -->|Yes| F3{Cooldown\nactive?}
    F3 -->|Yes| DROP3([🚫 Suppressed])
    F3 -->|No| F4{Service owner\nrule match?}
    F4 -->|Yes| OWN[📬 Route to\nservice owner]
    F4 -->|No| DEF[📢 Default\nalert rule]
    OWN & DEF --> SEND([✅ Send Alert])

    style E fill:#6366f1,stroke:#818cf8,color:#fff
    style SEND fill:#16a34a,stroke:#22c55e,color:#fff
    style DROP1 fill:#7f1d1d,stroke:#ef4444,color:#fff
    style DROP2 fill:#7f1d1d,stroke:#ef4444,color:#fff
    style DROP3 fill:#78350f,stroke:#f59e0b,color:#fff
```

---

## 🔌 Connect Your K8s Cluster

### Deployment Flow

```mermaid
flowchart LR
    A[kubectl apply\nagent.yml] --> B[Agent Pod\nrunning in\nkube-system]
    B --> C[Set env vars\nREDIS_URL\nCLUSTER_ID]
    C --> D{Agent connects\nto Redis?}
    D -->|✅ Yes| E[Watch stream\nactive]
    D -->|❌ No| F[Check firewall\nport 6379]
    F --> C
    E --> G([✅ Cluster\nMonitored])

    style G fill:#16a34a,stroke:#22c55e,color:#fff
    style F fill:#7f1d1d,stroke:#ef4444,color:#fff
```

```bash
# 1. Deploy the agent
kubectl apply -f \
  https://raw.githubusercontent.com/Akshatsainiaks/srevox-setup/main/srevox-agent.yml

# 2. Configure it (get CLUSTER_ID from Dashboard → Clusters → Add Cluster)
kubectl set env deployment/srevox-agent -n kube-system \
  REDIS_URL=redis://YOUR_SREVOX_IP:6379 \
  CLUSTER_ID=YOUR_UUID_FROM_DASHBOARD \
  CLUSTER_NAME=production

# 3. Verify it's watching
kubectl logs -n kube-system deployment/srevox-agent -f
```

---

## 🤖 AI Diagnosis

Click **"AI Diagnosis"** on any incident to instantly receive:

```mermaid
mindmap
  root((🤖 AI Diagnosis))
    Root Cause
      Why the pod crashed
      Memory / config / code issue
    Fix Commands
      kubectl commands
      Exact pod & namespace
      Step-by-step order
    Prevention
      Resource limits
      Health checks
      Config recommendations
    Context
      Recent log analysis
      Event timeline
      Restart history
```

### Supported AI Providers

| Provider | Speed | Cost | Internet Required | Best For |
|---|---|---|---|---|
| 🟢 **Groq** | ⚡ Fastest | Free tier | Yes | Self-hosted default |
| 🔵 **OpenAI** | Fast | Paid | Yes | GPT-4o quality |
| 🟣 **Anthropic** | Fast | Paid | Yes | Complex analysis |
| 🟡 **Ollama** | Medium | Free | ❌ Never | Air-gapped environments |

Configure per-user: **Dashboard → Settings → AI Diagnosis**

---

## 🔔 Alert Channels Setup

```mermaid
graph LR
    subgraph CONFIG["📝 Configure in Dashboard"]
        A[Alert Rules] --> B[Add Channel]
    end

    B --> SL[🟢 Slack\nwebhook URL]
    B --> TE[🔵 Teams\nwebhook URL]
    B --> EM[📧 Email\nSMTP config]
    B --> WA[📱 WhatsApp\nTwilio creds]
    B --> WH[🔗 Webhook\nany HTTP endpoint]

    style CONFIG fill:#0f172a,stroke:#6366f1,color:#e2e8f0
```

<details>
<summary><b>📧 Email / Gmail Setup</b></summary>

```
SMTP Host    → smtp.gmail.com
SMTP Port    → 587
SMTP User    → you@gmail.com
SMTP Pass    → App Password (Google Account → Security → App Passwords)
To           → oncall@yourcompany.com
```
</details>

<details>
<summary><b>💬 Microsoft Teams Setup</b></summary>

```
webhook_url → https://your-org.webhook.office.com/webhookb2/...
```
Get this from: Teams Channel → ⋯ More → Connectors → Incoming Webhook
</details>

<details>
<summary><b>🟢 Slack Setup</b></summary>

```
webhook_url → https://hooks.slack.com/services/T.../B.../...
```
Get this from: api.slack.com → Your Apps → Incoming Webhooks
</details>

<details>
<summary><b>📱 WhatsApp (via Twilio)</b></summary>

```
account_sid → ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
auth_token  → your_auth_token
from        → whatsapp:+14155238886
to          → whatsapp:+91XXXXXXXXXX
```
</details>

---

## ⚙️ Environment Variables

### Required

| Variable | Description | Example |
|---|---|---|
| `POSTGRES_PASSWORD` | Database password | `s3cur3p@ss!` |
| `BACKEND_SECRET_KEY` | JWT signing key (min 32 chars) | `my_super_secret_key_32chars!!` |
| `ENCRYPTION_KEY` | Channel config encryption (**exactly** 32 chars) | `exactlythirtytwocharactershere!` |
| `NEXT_PUBLIC_API_URL` | API URL seen from browser | `http://192.168.1.10:4000` |
| `FRONTEND_URL` | Dashboard URL for CORS | `http://192.168.1.10:3000` |

### Optional — AI Diagnosis

| Variable | Description |
|---|---|
| `AI_PROVIDER` | `groq` / `openai` / `anthropic` / `ollama` |
| `GROQ_API_KEY` | Free at [console.groq.com](https://console.groq.com) |
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OLLAMA_BASE_URL` | Local Ollama URL (e.g. `http://localhost:11434`) |

### Optional — Email Alerts

| Variable | Description |
|---|---|
| `SMTP_HOST` | SMTP server hostname |
| `SMTP_PORT` | Port (`587` for TLS) |
| `SMTP_USER` | SMTP username / email |
| `SMTP_PASS` | Password or App Password |

---

## 🐳 Docker Images

| Image | Tag |
|---|---|
| `akshatsaini08/srevox-api` | `latest` |
| `akshatsaini08/srevox-frontend` | `latest` |
| `akshatsaini08/srevox-worker` | `latest` |
| `akshatsaini08/srevox-ai` | `latest` |
| `akshatsaini08/srevox-agent` | `latest` |

All images are on [Docker Hub →](https://hub.docker.com/u/akshatsaini08)

---

## 🧪 Testing Your Setup

### Health Check Workflow

```mermaid
flowchart TD
    A([Start Testing]) --> B[Check Redis\nPUBSUB NUMSUB]
    B --> C{Subscribers\n= 1?}
    C -->|No| D[❌ Worker not connected\nCheck REDIS_URL in .env]
    C -->|Yes| E[Send test crash\nredis-cli PUBLISH]
    E --> F{Incident in\ndashboard?}
    F -->|No| G[Check CLUSTER_ID\nmust match exactly]
    F -->|Yes| H[Test real pod crash\nkubectl run crash-test]
    H --> I{Alert\nreceived?}
    I -->|No| J[Check alert rules\nhave channels added]
    I -->|Yes| K([✅ All working!])

    style A fill:#6366f1,stroke:#818cf8,color:#fff
    style K fill:#16a34a,stroke:#22c55e,color:#fff
    style D fill:#7f1d1d,stroke:#ef4444,color:#fff
    style G fill:#7f1d1d,stroke:#ef4444,color:#fff
    style J fill:#78350f,stroke:#f59e0b,color:#fff
```

**Verify alert worker is connected**
```bash
redis-cli -h YOUR_REDIS_IP -p 6379 PUBSUB NUMSUB srevox:crashes
# Expected: (integer) 1
```

**Send a test crash event**
```bash
redis-cli -h YOUR_REDIS_IP -p 6379 PUBLISH srevox:crashes '{
  "cluster_id":     "YOUR_CLUSTER_UUID",
  "pod_name":       "test-pod",
  "namespace":      "default",
  "container_name": "app",
  "crash_reason":   "OOMKilled",
  "restart_count":  5,
  "exit_code":      137,
  "pod_labels":     {},
  "raw_event":      {},
  "detected_at":    "2026-05-16T14:00:00Z"
}'
```

**Simulate a real pod crash**
```bash
kubectl run crash-test --image=busybox --restart=Always -- /bin/sh -c "exit 1"
kubectl get pod crash-test -w
kubectl delete pod crash-test
```

### Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `PUBSUB NUMSUB` → `0` | Worker not connected | Check `REDIS_URL` in `.env` |
| `PUBLISH` returns `0` | No subscribers | Restart alert worker container |
| "All channels filtered" | Rule has no channels | Dashboard → Alert Rules → Add Channel |
| Agent can't reach Redis | Firewall or bind issue | Open port `6379`; set `bind 0.0.0.0` in Redis config |
| No incidents in dashboard | `CLUSTER_ID` mismatch | Must match UUID exactly from Dashboard |
| `pods is forbidden` / Permission Error | Missing agent RBAC permissions | Apply RBAC permissions. See [RBAC Setup Guide](docs/agent-rbac.md) |

---

## 🔐 Security

- 🔑 Channel configs **encrypted at rest** in PostgreSQL
- 🛡️ JWT tokens signed with `BACKEND_SECRET_KEY`
- 🔒 Redis should be **LAN-only** — never expose port `6379` to the internet
- 🌐 Use **nginx or Caddy with TLS** in production environments
- 📦 No data leaves your network — all AI calls go directly from your server

---

## 📄 License

All rights reserved. Srevox is proprietary software. The configurations, deployment files, and setup scripts provided in this repository are for personal or internal company self-hosted use. Commercial redistribution or managed-service offerings require a commercial license.

---

<div align="center">

**Built for teams that run their own infrastructure.**

*No cloud. No SaaS. No data leaving your network.*

⚡ **Srevox** — Catch crashes before your users do.

[🐳 Docker Hub](https://hub.docker.com/u/akshatsaini08) · [🐛 Issues](https://github.com/Akshatsainiaks/srevox-setup/issues) · [⭐ Star](https://github.com/Akshatsainiaks/srevox-setup)

</div>
