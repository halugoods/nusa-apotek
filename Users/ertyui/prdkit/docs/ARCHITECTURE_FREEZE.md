# PRDKit V1 Architecture Freeze

## Engine status

Core (always enabled): V1 Domain, V2 Relationships, V5 Modules, V8 Validation, V10 Architecture, V13 Security, V16 Documentation (with V17 Visual merged in)

Optional (feature flag): V3 State Machine, V4 Events, V6 Pages, V7 UI Flows, V9 Tests, V11 Deployment, V12 Observability, V14 AI Agents, V15 Cost & Pricing, V18 Execution, V19 Migration

Postponed: V20 Evolution

## Architecture rules
1. No engine may be added unless another is removed or merged
2. Core engines must produce JSON artifacts
3. Optional engines must be feature-flagged
4. Every engine must produce at least one artifact file
5. Every engine must have a documented output schema

## Engine output artifacts
For each engine, specify: artifact file, format (JSON/markdown/YAML), contents, consumer (what uses this artifact)

V1 Domain → entities.json — { entities: [{ name, fields, enums, ... }] } — consumed by: all downstream engines
V2 Relationships → relations.json — { relations: [{ from, to, type, cardinality, cascade }] } — consumed by: V5 Modules, V7 Flows
V5 Modules → modules.json — { modules: [{ name, entities, capabilities, dependencies }] } — consumed by: V10 Architecture, V13 Security
V8 Validation → validation.json — { rules: [{ entity, field, rule, severity }] } — consumed by: V10 Architecture, V13 Security, V16 Documentation
V10 Architecture → architecture.json — { layers: [{ name, modules, interactions }] } — consumed by: V13 Security, V16 Documentation
V13 Security → security.json — { policies: [{ resource, action, roles, constraints }] } — consumed by: V16 Documentation
V16 Documentation → documentation.md — { overview, entities, relations, architecture, security } — consumed by: end user (rendered output)

### Optional engine artifacts

V3 State Machine → statemachine.json — { machines: [{ entity, states, transitions, guards }] } — consumed by: V7 Flows, V14 AI Agents
V4 Events → events.json — { events: [{ name, source, payload, handlers }] } — consumed by: V5 Modules, V12 Observability
V6 Pages → pages.json — { pages: [{ route, components, dataRequirements }] } — consumed by: V7 Flows, V14 AI Agents
V7 UI Flows → uiflows.json — { flows: [{ trigger, steps, branches, outcomes }] } — consumed by: V6 Pages, V14 AI Agents
V9 Tests → tests.json — { testSuites: [{ entity, scenarios, assertions }] } — consumed by: V11 Deployment
V11 Deployment → deployment.json — { config: [{ service, provider, resources, env }] } — consumed by: V19 Migration
V12 Observability → observability.json — { metrics: [{ name, source, dashboard, alerts }] } — consumed by: V11 Deployment
V14 AI Agents → aiagents.json — { agents: [{ role, tools, knowledge, triggers }] } — consumed by: V6 Pages, V18 Execution
V15 Cost & Pricing → costing.json — { estimates: [{ resource, unit, quantity, cost }] } — consumed by: V11 Deployment
V18 Execution → execution.json — { steps: [{ order, action, inputs, outputs, retry }] } — consumed by: V19 Migration
V19 Migration → migration.json — { phases: [{ from, to, steps, rollback }] } — consumed by: V11 Deployment

## File naming convention
All artifacts go to: /artifacts/{engine-slug}.json
All documentation goes to: /docs/{category}/{filename}.md

## Pipeline flow
```
V1 → V2 → V5 → V8 → V10 → V13 → V16
  ↘     ↘     ↘     ↘     ↘     ↘
  V3    V4    V6    V9    V11   V17
  V7          V12   V14
              V15   V18
                    V19
```
