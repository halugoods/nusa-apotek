# Deployment Guide

PRDKit can be deployed in several configurations depending on your team's needs — from a local development workspace to a fully cloud-hosted team environment.

## Deployment Options Overview

| Mode | Best For | Setup Time | Collaboration | Cost |
|---|---|---|---|---|
| **Local Workspace** | Individual developers | 5 minutes | No | Free |
| **Self-Hosted Server** | Teams with existing infra | 30 minutes | Yes (LAN) | Server costs |
| **Cloud Workspace** | Distributed teams | 15 minutes | Yes (global) | Usage-based |
| **Docker Deployment** | Containerized environments | 10 minutes | Depends on config | Container host costs |

---

## Local Workspace

The default mode. PRDKit runs entirely on your development machine.

### Setup

```bash
# Install and initialize
npx @prdkit/cli init my-project
cd my-project

# Configure local AI providers (Ollama for offline, or API keys for cloud providers)
npx prdkit providers add ollama
npx prdkit providers add openai  # Requires OPENAI_API_KEY
```

### Usage

```bash
# Start the interactive studio
npx prdkit dev

# Run individual commands
npx prdkit generate "my idea"
npx prdkit compile blueprints/app.prdl
npx prdkit export blueprints/app.prdl --all
```

### File Storage

All blueprints, exports, and configuration live on your local filesystem:

```
~/projects/my-project/
  ├── blueprints/           # .prdl files
  ├── exports/              # Generated artifacts
  ├── templates/            # Custom templates
  ├── prdkit.config.json    # Project configuration
  └── .env                  # API keys (gitignored)
```

### Pros & Cons

| ✅ Advantages | ❌ Limitations |
|---|---|
| No network dependency | No team collaboration |
| Full control over data | Single machine only |
| Free (except AI API costs) | No shared template library |
| Works fully offline with Ollama | Cannot delegate generation to a server |

---

## Self-Hosted Server

Run PRDKit as a service on your own infrastructure, accessible to your team over the network.

### Architecture

```
┌──────────────┐      HTTP/WebSocket       ┌──────────────────┐
│   Developer   │ ◄──────────────────────► │  PRDKit Server    │
│   (CLI/Web)   │                           │                  │
└──────────────┘                           │  - API Server     │
                                            │  - Agent Workers  │
┌──────────────┐                           │  - File Store     │
│   Developer   │                           │  - Auth Gateway   │
│   (CLI/Web)   │                           │  - Job Queue      │
└──────────────┘                           └──────────────────┘
                                                      │
                                                      ▼
                                            ┌──────────────────┐
                                            │   PostgreSQL      │
                                            │   (Metadata)      │
                                            └──────────────────┘
```

### Setup

```bash
# On the server
npx @prdkit/cli init-server

# This creates:
#   /opt/prdkit-server/
#     ├── server.js           # Express/Fastify server
#     ├── config.yml          # Server configuration
#     ├── data/               # Workspace storage
#     ├── plugins/            # Server plugins
#     └── docker-compose.yml  # PostgreSQL + optional Redis
```

### Configuration

```yaml
# config.yml
server:
  host: "0.0.0.0"
  port: 8080
  ssl:
    enabled: true
    cert: /etc/ssl/prdkit.crt
    key: /etc/ssl/prdkit.key

auth:
  method: jwt
  jwtSecret: "${PRDKIT_JWT_SECRET}"
  providers:
    - type: oidc
      name: "Google Workspace"
      issuer: "https://accounts.google.com"
    - type: local
      name: "Email & Password"

storage:
  type: local
  path: /opt/prdkit-server/data
  # Or use S3-compatible storage:
  # type: s3
  # bucket: prdkit-blueprints
  # region: us-east-1

ai:
  providers:
    openai:
      apiKey: "${OPENAI_API_KEY}"
    anthropic:
      apiKey: "${ANTHROPIC_API_KEY}"

agents:
  maxConcurrent: 5
  timeout: 60000
  queue: "redis"  # or "in-memory"
```

### Starting the Server

```bash
# With Docker (recommended)
cd /opt/prdkit-server
docker compose up -d

# Or directly
node server.js
```

### Connecting Clients

```bash
# From a developer's machine
npx prdkit remote connect --server https://prdkit.internal.company.com

# Or via CLI flag
npx prdkit generate "task manager" --server https://prdkit.internal.company.com
```

### Team Features

- **Shared blueprints** — All team members access the same blueprint library
- **Version history** — Full audit trail of changes
- **Role-based access** — Admin, Editor, Viewer roles
- **Collaborative editing** — Multiple users can edit the same blueprint (with merge conflict resolution)
- **Web dashboard** — Browser-based blueprint browser and editor (available at `/dashboard`)

### Scaling

| Component | Scaling Strategy |
|---|---|
| API Server | Horizontal — add more instances behind a load balancer |
| Agent Workers | Horizontal — increase `maxConcurrent` or add worker nodes |
| Database | Vertical — upgrade PostgreSQL; read replicas for dashboard queries |
| Storage | Horizontal — use S3-compatible object storage |

---

## Cloud Workspace

PRDKit Cloud is a managed SaaS offering. No infrastructure to manage.

### Getting Started

```bash
# Sign up
npx prdkit cloud signup

# Login
npx prdkit cloud login

# Create a workspace
npx prdkit cloud workspace create my-team-workspace

# Invite team members
npx prdkit cloud invite colleague@company.com --role editor
```

### Workspace Management

```bash
# List workspaces
npx prdkit cloud workspace list

# Switch workspace
npx prdkit cloud workspace use my-team-workspace

# View usage & billing
npx prdkit cloud billing

# Export workspace data
npx prdkit cloud export --all
```

### Features

| Feature | Cloud Free | Cloud Pro | Cloud Enterprise |
|---|---|---|---|
| Users | Up to 3 | Unlimited | Unlimited |
| Blueprints | 10 | Unlimited | Unlimited |
| Export formats | All | All | All + custom |
| Templates | Built-in | Built-in + custom | Custom + premium |
| AI providers | Bring your own key | Bundled + BYOK | Bundled, BYOK, private models |
| Audit log | 7 days | 90 days | 1 year |
| SSO | — | — | SAML/OIDC |
| SLA | — | 99.9% | 99.99% |
| Support | Community | Email | Dedicated |

### Data Residency

```bash
# Choose a region
npx prdkit cloud workspace configure --region eu-west-1

# Available regions: us-east-1, eu-west-1, ap-southeast-1
```

---

## Environment Variables

PRDKit respects the following environment variables:

### Core

| Variable | Required | Default | Description |
|---|---|---|---|
| `PRDKIT_HOME` | No | `~/.prdkit` | PRDKit configuration directory |
| `PRDKIT_LOG_LEVEL` | No | `info` | Logging level: `debug`, `info`, `warn`, `error` |
| `PRDKIT_CONFIG_FILE` | No | `./prdkit.config.json` | Path to config file |
| `PRDKIT_TELEMETRY` | No | `true` | Set to `false` to disable telemetry |

### AI Provider API Keys

| Variable | Required For |
|---|---|
| `OPENAI_API_KEY` | OpenAI provider |
| `ANTHROPIC_API_KEY` | Anthropic provider |
| `GEMINI_API_KEY` | Google Gemini provider |
| `DEEPSEEK_API_KEY` | DeepSeek provider |
| `OPENROUTER_API_KEY` | OpenRouter provider |

### Server Mode

| Variable | Required | Default | Description |
|---|---|---|---|
| `PRDKIT_SERVER_PORT` | No | `8080` | HTTP server port |
| `PRDKIT_SERVER_HOST` | No | `0.0.0.0` | Server bind address |
| `PRDKIT_JWT_SECRET` | Yes* | — | JWT signing secret (*required with JWT auth) |
| `PRDKIT_DATABASE_URL` | Yes* | — | PostgreSQL connection string (*required for multi-user) |
| `PRDKIT_REDIS_URL` | No | — | Redis connection string for job queue |
| `PRDKIT_S3_BUCKET` | No | — | S3 bucket for file storage |
| `PRDKIT_S3_REGION` | No | `us-east-1` | S3 bucket region |
| `PRDKIT_S3_ACCESS_KEY` | No | — | S3 access key |
| `PRDKIT_S3_SECRET_KEY` | No | — | S3 secret key |

### Security

| Variable | Default | Description |
|---|---|---|
| `PRDKIT_RATE_LIMIT_WINDOW` | `60000` | Rate limit window in ms |
| `PRDKIT_RATE_LIMIT_MAX` | `100` | Max requests per window |
| `PRDKIT_CORS_ORIGIN` | `*` | Allowed CORS origins |
| `PRDKIT_MAX_BLUEPRINT_SIZE` | `10485760` | Max blueprint file size (bytes) |
| `PRDKIT_ENCRYPTION_KEY` | — | Key for encrypting stored API keys |

### Example .env File

```bash
# .env

# --- AI Providers ---
OPENAI_API_KEY=sk-proj-...
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIza...
DEEPSEEK_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-...

# --- Server Mode ---
PRDKIT_JWT_SECRET=your-256-bit-secret
PRDKIT_DATABASE_URL=postgresql://prdkit:password@localhost:5432/prdkit
PRDKIT_REDIS_URL=redis://localhost:6379
PRDKIT_SERVER_PORT=8080
PRDKIT_S3_BUCKET=my-prdkit-blueprints
PRDKIT_S3_REGION=us-east-1

# --- Security ---
PRDKIT_RATE_LIMIT_MAX=200
PRDKIT_CORS_ORIGIN=https://prdkit.mycompany.com
```

---

## Docker Deployment

### Quick Start

```bash
# Pull and run the PRDKit server
docker run -d \
  --name prdkit-server \
  -p 8080:8080 \
  -v prdkit-data:/data \
  -e OPENAI_API_KEY=sk-... \
  -e PRDKIT_JWT_SECRET=your-secret \
  -e PRDKIT_DATABASE_URL=postgresql://... \
  halugoods/prdkit-server:latest
```

### Docker Compose (Full Stack)

```yaml
# docker-compose.yml
version: "3.8"

services:
  prdkit:
    image: halugoods/prdkit-server:latest
    ports:
      - "8080:8080"
    environment:
      - PRDKIT_JWT_SECRET=${PRDKIT_JWT_SECRET}
      - PRDKIT_DATABASE_URL=postgresql://prdkit:prdkit@db:5432/prdkit
      - PRDKIT_REDIS_URL=redis://redis:6379
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - PRDKIT_LOG_LEVEL=info
    volumes:
      - prdkit-data:/data
      - ./prdkit.config.yml:/app/config.yml:ro
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: prdkit
      POSTGRES_PASSWORD: prdkit
      POSTGRES_DB: prdkit
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U prdkit"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped

volumes:
  prdkit-data:
  pgdata:
  redisdata:
```

### Using Docker for Local Development (No Server)

```bash
# Run PRDKit CLI from Docker for isolated execution
docker run --rm -it \
  -v $(pwd):/workspace \
  -e OPENAI_API_KEY=sk-... \
  halugoods/prdkit-cli:latest \
  generate "task management API"
```

### Docker Image Tags

| Tag | Description |
|---|---|
| `latest` | Latest stable release |
| `x.y.z` | Specific version (e.g., `1.0.0`) |
| `nightly` | Latest development build |
| `cli` | CLI-only image (no server) |
| `server` | Server-only image |

### Kubernetes Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prdkit-server
  namespace: prdkit
spec:
  replicas: 3
  selector:
    matchLabels:
      app: prdkit
  template:
    metadata:
      labels:
        app: prdkit
    spec:
      containers:
        - name: prdkit
          image: halugoods/prdkit-server:latest
          ports:
            - containerPort: 8080
          env:
            - name: PRDKIT_JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: prdkit-secrets
                  key: jwt-secret
            - name: PRDKIT_DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: prdkit-secrets
                  key: database-url
            - name: OPENAI_API_KEY
              valueFrom:
                secretKeyRef:
                  name: prdkit-secrets
                  key: openai-api-key
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "1"
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: prdkit-service
  namespace: prdkit
spec:
  selector:
    app: prdkit
  ports:
    - port: 8080
      targetPort: 8080
  type: ClusterIP
```

---

## Security Considerations

### API Key Storage

- **Local mode:** Keys stored in `.env` (gitignored by default)
- **Server mode:** Keys stored in environment variables or encrypted at rest
- **Cloud mode:** Keys encrypted with AES-256; never logged or exposed

### Network Security

| Deployment | Network | Recommendation |
|---|---|---|
| Local | Localhost only | No additional measures needed |
| Self-hosted | Internal network | Use TLS, VPN or zero-trust tunnel |
| Cloud | Public internet | TLS, rate limiting, IP whitelisting |

### Data Encryption

- Blueprints at rest: AES-256-GCM
- Blueprints in transit: TLS 1.3
- API keys in transit: TLS 1.3
- API keys at rest: Encrypted with `PRDKIT_ENCRYPTION_KEY`

### Audit Logging

When running in server or cloud mode, all operations are logged:

| Event | Details Logged |
|---|---|
| Blueprint created | User, timestamp, blueprint name |
| Blueprint edited | User, timestamp, diff |
| Blueprint exported | User, timestamp, formats |
| Blueprint deleted | User, timestamp, blueprint name |
| Configuration changed | User, timestamp, changed fields |
| Login attempts | User, IP, success/failure, timestamp |

---

## Monitoring & Maintenance

### Health Endpoint

```bash
# Server health check
curl https://prdkit.internal.company.com/health

# Response:
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime": 3600,
  "agents": {
    "ready": 5,
    "busy": 2,
    "total": 7
  },
  "database": "connected",
  "cache": "connected"
}
```

### Metrics (Prometheus)

When enabled, PRDKit exports metrics at `/metrics`:

```
# HELP prdkit_agent_calls_total Total agent calls
# TYPE prdkit_agent_calls_total counter
prdkit_agent_calls_total{agent="blueprint-generator",status="success"} 142

# HELP prdkit_agent_duration_seconds Agent call duration
# TYPE prdkit_agent_duration_seconds histogram
prdkit_agent_duration_seconds_bucket{agent="blueprint-generator",le="1"} 95

# HELP prdkit_exports_total Total exports generated
# TYPE prdkit_exports_total counter
prdkit_exports_total{format="openapi"} 85
```

### Backup & Restore

```bash
# Back up all data
npx prdkit backup --output ./prdkit-backup.tar.gz

# Restore from backup
npx prdkit restore --input ./prdkit-backup.tar.gz

# Scheduled backups (self-hosted with cron)
0 2 * * * cd /opt/prdkit-server && npx prdkit backup > /dev/null
```

### Upgrading

```bash
# Self-hosted
docker compose pull prdkit
docker compose up -d

# Local
npm update -g @prdkit/cli

# Verify version
npx prdkit --version
```

Check the [changelog](../CHANGELOG.md) for breaking changes before upgrading between major versions.
