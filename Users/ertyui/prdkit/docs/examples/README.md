# Examples

This directory contains example PRDL blueprints, export configurations, and template files demonstrating various PRDKit features.

## Available Examples

### `examples/basics/`

| File | Description |
|---|---|
| `hello-world.prdl` | Minimal blueprint — a single actor with one endpoint. Best starting point for learning PRDL syntax. |
| `rest-api.prdl` | Standard REST API blueprint with CRUD operations, authentication, and pagination. Demonstrates fields, enums, and endpoint annotations. |
| `full-stack-app.prdl` | Complete full-stack application specification including frontend routes, backend endpoints, database models, and deployment config. |

### `examples/domains/`

| File | Description |
|---|---|
| `e-commerce.prdl` | E-commerce platform blueprint with Product, Order, Cart, Customer, Payment actors. Demonstrates complex relationships (has_many, belongs_to, has_one) and multi-step workflows. |
| `social-media.prdl` | Social network blueprint with User, Post, Comment, Like, Follow. Shows feed generation, notification patterns, and real-time event handling. |
| `saas-billing.prdl` | SaaS subscription platform with Subscription, Plan, Invoice, Team, RBAC. Demonstrates tiered billing, usage metering, and webhook integration. |
| `healthcare.prdl` | HIPAA-compliant healthcare application with Patient, Doctor, Appointment, MedicalRecord, Prescription. Shows audit logging, data classification, and compliance annotations. |

### `examples/advanced/`

| File | Description |
|---|---|
| `event-driven.prdl` | Event-driven microservice architecture with message brokers, event schemas, and async handlers. Demonstrates the `events` block. |
| `graphql-api.prdl` | GraphQL API blueprint with schema types, resolvers, subscriptions, and dataloader hints. Shows GraphQL-specific export annotations. |
| `multi-tenant.prdl` | Multi-tenant SaaS blueprint with tenant isolation, shared vs. dedicated resources, and tenant-aware middleware. |
| `real-time.prdl` | Real-time application with WebSocket connections, rooms, presence detection, and message streaming. |

### `examples/infrastructure/`

| File | Description |
|---|---|
| `docker-compose-advanced.yml` | Advanced Docker Compose configuration generated from a blueprint, including separate build stages, health checks, and service mesh annotations. |
| `kubernetes-manifest.prdl` | Blueprint that exports Kubernetes manifests (Deployment, Service, Ingress, ConfigMap, HPA) alongside application code. |
| `ci-cd-pipeline.prdl` | Blueprint that generates CI/CD configuration (GitHub Actions, GitLab CI) from the product specification. |

### `examples/templates/`

| File | Description |
|---|---|
| `custom-graphql.hbs` | Custom template that generates a GraphQL schema from PRDL blueprints. Demonstrates conditionals, loops, and type mapping helpers. |
| `terraform.hbs` | Template that generates Terraform infrastructure-as-code from blueprint domain definitions. |
| `react-hooks.hbs` | Template that generates React Query hooks and TypeScript types from API endpoint definitions. |
| `openapi-extended.hbs` | Extended OpenAPI template with custom security schemes, rate limiting docs, and examples. |
| `sdk-client.hbs` | Template for generating multi-language SDK client code from a blueprint. |

### `examples/configs/`

| File | Description |
|---|---|
| `prdkit.minimal.json` | Minimal configuration file with one provider and two export formats. |
| `prdkit.full.json` | Full configuration demonstrating every option — all providers, per-agent assignments, budgets, custom templates, and environment overrides. |
| `prdkit.multi-provider.json` | Configuration with multiple AI providers and fallback chains for high availability. |
| `prdkit.team.json` | Team-oriented configuration with shared model quotas, audit logging, and export review workflows. |

### `examples/workflows/`

| File | Description |
|---|---|
| `blueprint-lifecycle.sh` | Bash script demonstrating the full blueprint lifecycle: generate → compile → iterate → export → version bump → re-export. |
| `from-idea-to-prd.sh` | End-to-end workflow showing how to go from a raw idea to a published PRD document using PRDKit's AI generation pipeline. |
| `batch-export.sh` | Script that exports multiple blueprints in parallel with different format combinations, useful for monorepo setups. |

## Running an Example

```bash
# Navigate to your PRDKit workspace
cd my-first-blueprint

# Copy an example blueprint
cp /path/to/prdkit/examples/basics/rest-api.prdl blueprints/

# Compile and validate
npx prdkit compile blueprints/rest-api.prdl

# Export all formats
npx prdkit export blueprints/rest-api.prdl --all

# Try a custom template
npx prdkit export blueprints/rest-api.prdl \
  --template examples/templates/custom-graphql.hbs
```

## Creating Your Own Examples

We welcome contributions! If you build something interesting with PRDKit, consider submitting it as an example. See the [contributing guide](../CONTRIBUTING.md) for guidelines on example submissions.

> **Note:** These examples are designed to work with PRDKit v1.0.0+. Some features may require specific export formats or AI provider configurations.
