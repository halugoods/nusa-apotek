# Agent System Architecture

PRDKit's intelligence is powered by a **multi-agent system** — a coordinated team of specialized AI agents that work together to transform product ideas into structured blueprints and export artifacts.

## Overview

Instead of a single monolithic AI call, PRDKit breaks the work into discrete responsibilities handled by specialized agents. Each agent has:

- A **specific role** with a defined scope of responsibility
- A **structured input contract** that governs what it receives
- A **structured output contract** that guarantees what it produces
- An **assigned AI provider and model** (configurable per agent)

This architecture ensures reliability, observability, and composability. Agents can be swapped, upgraded, or replaced independently without affecting the rest of the system.

```
┌─────────────────────────────────────────────────────────┐
│                    PRDKit Agent System                    │
│                                                           │
│  User Input ───▶ Orchestrator ───▶ [Agent Pool] ───▶ Output │
│                      │                                     │
│                      ▼                                     │
│               [Shared Context]                             │
│           (Blueprint AST, Config, State)                   │
└─────────────────────────────────────────────────────────┘
```

## Agent Types and Responsibilities

### 1. Orchestrator Agent

**Role:** The central coordinator. Receives user requests, routes them to the appropriate agents, and assembles final results.

**Responsibilities:**

- Parse user intent (generate, compile, export, refine)
- Determine which agents to invoke and in what order
- Manage conversation state and context
- Handle errors and fallback strategies
- Return structured responses to the user

**Input Contract:**

```typescript
interface OrchestratorInput {
  intent: 'generate' | 'compile' | 'export' | 'refine' | 'edit' | 'template';
  payload: Record<string, any>;
  context?: {
    blueprintName?: string;
    existingBlueprint?: BlueprintAST;
    sessionId?: string;
  };
}
```

**Output Contract:**

```typescript
interface OrchestratorOutput {
  status: 'success' | 'error' | 'needs_clarification';
  result?: any;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  suggestions?: string[];
  metadata: {
    agentsCalled: string[];
    tokensUsed: Record<string, number>;
    duration: number;
  };
}
```

### 2. Blueprint Generator Agent

**Role:** Converts natural language product descriptions into structured PRDL blueprints.

**Responsibilities:**

- Parse and understand free-form product descriptions
- Ask clarifying questions when details are ambiguous
- Generate complete PRDL syntax with proper structure
- Suggest actors, fields, endpoints, and relationships
- Apply domain-specific conventions and best practices

**Specialization:**

The Blueprint Generator has sub-specializations for different domains:

| Sub-agent | Domain | Example Input |
|---|---|---|
| REST Generator | Standard CRUD APIs | "Task management API" |
| Event Generator | Event-driven architectures | "Order processing pipeline" |
| GraphQL Generator | GraphQL APIs | "Content management API" |
| SaaS Generator | Multi-tenant SaaS products | "Subscription billing platform" |

**Input Contract:**

```typescript
interface GeneratorInput {
  idea: string;
  domain?: string;
  actors?: string[];           // User hints about entities
  techStack?: string;          // Preferred technology stack
  existingBlueprint?: BlueprintAST;  // For iterative refinement
  constraints?: {
    maxEndpoints?: number;
    maxActors?: number;
    includeAuth?: boolean;
  };
}
```

**Output Contract:**

```typescript
interface GeneratorOutput {
  blueprint: BlueprintAST;
  confidence: number;          // 0.0 to 1.0
  clarifications?: string[];   // Questions the user should answer
  warnings?: string[];         // Potential issues flagged
  alternatives?: {             // Alternative approaches
    name: string;
    description: string;
    diff?: string;
  }[];
}
```

### 3. Blueprint Validator Agent

**Role:** Analyzes PRDL blueprints for correctness, consistency, and completeness.

**Responsibilities:**

- Validate PRDL syntax and structure
- Check type consistency across fields and endpoints
- Verify relationship integrity (no dangling references)
- Detect naming convention violations
- Identify missing required fields
- Flag potential design issues (N+1 queries, circular dependencies)
- Suggest improvements

**Input Contract:**

```typescript
interface ValidatorInput {
  blueprint: BlueprintAST;
  strictness?: 'low' | 'medium' | 'high';
  rules?: string[];            // Specific rules to apply
  context?: {
    projectConfig?: ProjectConfig;
    existingBlueprints?: BlueprintAST[];
  };
}
```

**Output Contract:**

```typescript
interface ValidatorOutput {
  valid: boolean;
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
  suggestions: ValidationSuggestion[];
  summary: {
    actorCount: number;
    fieldCount: number;
    endpointCount: number;
    relationshipCount: number;
  };
}

interface ValidationIssue {
  severity: 'error' | 'warning';
  code: string;                // e.g., "TYPE_MISMATCH"
  message: string;
  location: {
    actor?: string;
    field?: string;
    endpoint?: string;
    line?: number;
    column?: number;
  };
  fix?: string;                // Auto-fix suggestion
}
```

### 4. Export Generator Agent

**Role:** Transforms validated blueprints into target-specific artifacts (OpenAPI, TypeScript, Prisma, etc.).

**Responsibilities:**

- Map PRDL types to target language types
- Apply format-specific conventions and best practices
- Generate complete, syntactically valid output files
- Handle format-specific features (e.g., OpenAPI security schemes)
- Optimize output for readability and usability

**Specialization:**

Each export format has a dedicated sub-agent:

| Sub-agent | Format | Key Handling |
|---|---|---|
| OpenAPI Agent | OpenAPI 3.1 | Paths, schemas, security, examples |
| Prisma Agent | Prisma Schema | Models, enums, relations, datasource |
| TypeScript Agent | TypeScript | Interfaces, types, generics, barrel exports |
| Zod Agent | Zod Schemas | Validation chains, refinements, error messages |
| Python Agent | Pydantic | BaseModel, validators, ConfigDict |
| Docker Agent | Docker Compose | Services, volumes, networks, healthchecks |
| Tokens Agent | Design Tokens | Colors, spacing, typography, breakpoints |
| Mermaid Agent | Mermaid Diagrams | ERD, data flow, state machines |
| Markdown Agent | PRD Documentation | Tables, sections, TOC, examples |

**Input Contract:**

```typescript
interface ExportInput {
  blueprint: BlueprintAST;
  format: ExportFormat;
  options?: {
    template?: string;         // Custom template path
    style?: Record<string, any>;  // Format-specific options
    includeExamples?: boolean;
  };
  context?: {
    projectConfig?: ProjectConfig;
    existingFiles?: Record<string, string>;
  };
}
```

**Output Contract:**

```typescript
interface ExportOutput {
  files: GeneratedFile[];
  warnings?: string[];
  metadata: {
    format: string;
    template: string;
    generatedAt: string;
    size: number;
  };
}

interface GeneratedFile {
  path: string;
  content: string;
  language: string;            // For syntax highlighting
  overwrite: boolean;
}
```

### 5. Refinement Agent

**Role:** Suggests improvements and extensions to existing blueprints.

**Responsibilities:**

- Analyze existing blueprints for gaps and opportunities
- Suggest new endpoints, fields, or actors
- Propose alternative data models or relationship patterns
- Recommend security improvements
- Identify performance considerations

**Input Contract:**

```typescript
interface RefinementInput {
  blueprint: BlueprintAST;
  focus?: 'security' | 'performance' | 'completeness' | 'scalability';
  userGoal?: string;           // What the user is trying to achieve
  constraints?: string[];
}
```

**Output Contract:**

```typescript
interface RefinementOutput {
  suggestions: RefinementSuggestion[];
  priority: 'low' | 'medium' | 'high';
}

interface RefinementSuggestion {
  title: string;
  description: string;
  impact: string;
  effort: 'small' | 'medium' | 'large';
  prdlPatch?: string;          // Direct PRDL changes to apply
}
```

## Agent Communication

Agents communicate through a **shared context** — a structured data store that holds the current state of the work being performed.

### Communication Flow

```
                         ┌──────────────────┐
                         │  User Request     │
                         └────────┬─────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │    Orchestrator Agent    │
                    │  (Intent Routing)        │
                    └──┬──────┬───────┬───────┘
                       │      │       │
              ┌────────▼┐ ┌──▼────┐ ┌▼────────┐
              │Generator│ │Validator│ │Exporter │
              │  Agent  │ │ Agent  │ │  Agent  │
              └────┬────┘ └───┬────┘ └────┬────┘
                   │          │            │
                   ▼          ▼            ▼
              ┌─────────────────────────────────────┐
              │          Shared Context              │
              │  (Blueprint AST, Validation Results,  │
              │   Export Files, Conversation History) │
              └─────────────────────────────────────┘
```

### Shared Context Schema

```typescript
interface SharedContext {
  session: {
    id: string;
    startedAt: string;
    userId?: string;
  };
  blueprint?: {
    ast: BlueprintAST;
    prdl: string;              // Raw PRDL source
    filePath?: string;
  };
  validation?: ValidatorOutput;
  exports?: Record<string, ExportOutput>;
  conversation: {
    messages: ChatMessage[];
    currentAgent: string;
    history: AgentCall[];
  };
  project?: ProjectConfig;
}
```

### Inter-Agent Contracts

Agents do not call each other directly. Instead, they:

1. **Read** from the shared context to understand the current state
2. **Write** their output to the shared context
3. **Signal** completion via status flags

This decoupling means agents can be developed, tested, and deployed independently.

### Error Propagation

When an agent fails, the Orchestrator determines the recovery strategy:

| Error Type | Recovery Strategy |
|---|---|
| **Provider unavailable** | Fall back to secondary AI provider |
| **Rate limited** | Retry with exponential backoff |
| **Invalid input** | Return to user with clarification |
| **Validation failure** | Pass validation details to Refinement Agent |
| **Timeout** | Use cached or degraded output |

## Output Format Contracts

Every agent produces output that conforms to a strict contract. Contracts ensure:

- **Predictability** — Downstream consumers know exactly what to expect
- **Composability** — Agents can be chained without glue code
- **Testability** — Each agent can be tested in isolation

### Contract Enforcement

Contracts are enforced at the system boundary:

```typescript
// Each agent's output is validated against its schema
function validateAgentOutput<T>(output: any, schema: ZodSchema<T>): T {
  const result = schema.safeParse(output);
  if (!result.success) {
    throw new AgentContractError({
      agent: agentName,
      errors: result.error.issues,
      raw: output
    });
  }
  return result.data;
}
```

### Blueprint AST (the central data model)

```typescript
interface BlueprintAST {
  name: string;
  version: string;
  description?: string;
  extends?: string;
  domain: {
    name: string;
    description?: string;
  };
  actors: Record<string, ActorDef>;
  relationships?: RelationshipDef[];
  endpoints: EndpointDef[];
  events?: EventDef[];
  auth?: AuthDef;
  exports?: Record<string, ExportConfig>;
  metadata?: {
    createdBy?: string;
    createdAt?: string;
    updatedAt?: string;
    tags?: string[];
  };
}
```

## Custom Agents via Plugin System

PRDKit's agent system is extensible via a plugin architecture. You can add custom agents for domain-specific tasks.

### Plugin Structure

```
my-prdkit-plugin/
  ├── package.json          # npm package with prdkit-agent type
  ├── src/
  │   ├── index.ts          # Plugin entry point
  │   ├── agent.ts          # Agent implementation
  │   └── contracts.ts      # Input/output contracts
  └── README.md
```

### Creating a Custom Agent

```typescript
// my-prdkit-plugin/src/agent.ts
import { Agent, AgentContext, AgentOutput } from '@prdkit/agent-sdk';

export class ComplianceAgent implements Agent {
  name = 'compliance-checker';
  version = '1.0.0';
  description = 'Checks blueprints for regulatory compliance (HIPAA, GDPR, SOC2)';

  async execute(input: ComplianceInput, ctx: AgentContext): Promise<ComplianceOutput> {
    const { blueprint } = input;

    // Read shared context
    const projectConfig = ctx.get('project.config');

    // Use configured AI provider
    const result = await ctx.ai.generate({
      provider: ctx.config.provider,
      model: ctx.config.model,
      prompt: this.buildPrompt(blueprint, input.regulations),
      temperature: 0.1,
    });

    // Write to shared context
    ctx.set('compliance.result', result);

    return {
      compliant: result.passed,
      regulations: result.details,
      violations: result.violations,
      recommendations: result.recommendations,
    };
  }

  private buildPrompt(blueprint: any, regulations: string[]): string {
    return `Analyze this blueprint for ${regulations.join(', ')} compliance:\n${JSON.stringify(blueprint, null, 2)}`;
  }
}
```

### Registering a Plugin

```typescript
// my-prdkit-plugin/src/index.ts
import { Plugin } from '@prdkit/agent-sdk';
import { ComplianceAgent } from './agent';

export default {
  name: '@myorg/prdkit-compliance',
  version: '1.0.0',
  agents: [new ComplianceAgent()],
  hooks: {
    // Run compliance check after blueprint validation
    afterValidation: async (ctx) => {
      const agent = new ComplianceAgent();
      await agent.execute({
        blueprint: ctx.get('blueprint.ast'),
        regulations: ctx.get('project.compliance.regulations'),
      }, ctx);
    },
  },
} satisfies Plugin;
```

### Installing a Plugin

```bash
npm install @myorg/prdkit-compliance
```

Then enable it in `prdkit.config.json`:

```json
{
  "plugins": {
    "@myorg/prdkit-compliance": {
      "enabled": true,
      "regulations": ["hipaa", "gdpr"]
    }
  }
}
```

### Plugin Hooks

Plugins can hook into the agent pipeline at these points:

| Hook | Timing | Use Case |
|---|---|---|
| `beforeGeneration` | Before blueprint generation | Inject domain-specific context |
| `afterGeneration` | After blueprint generation | Apply post-processing or enrichment |
| `beforeValidation` | Before validation | Add custom validation rules |
| `afterValidation` | After validation | Trigger compliance checks |
| `beforeExport` | Before export generation | Inject format-specific transforms |
| `afterExport` | After export generation | Post-process exports (formatting, linting) |
| `beforeRefinement` | Before refinement suggestions | Add contextual constraints |
| `afterRefinement` | After refinement suggestions | Filter or rank suggestions |

### Agent SDK

The `@prdkit/agent-sdk` package provides:

- `Agent` base class with lifecycle methods
- `AgentContext` for reading/writing shared state
- `AIProvider` client with built-in retry and fallback
- `ContractValidator` for I/O validation
- `Logger` with structured logging

## Agent Configuration Reference

Full agent configuration in `prdkit.config.json`:

```json
{
  "agents": {
    "orchestrator": {
      "provider": "openai",
      "model": "gpt-4o",
      "temperature": 0.3,
      "timeout": 30000
    },
    "blueprint-generator": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "temperature": 0.3,
      "subAgents": {
        "rest": { "provider": "openai", "model": "gpt-4o" },
        "event": { "provider": "anthropic", "model": "claude-sonnet-4-20250514" },
        "saas": { "provider": "gemini", "model": "gemini-2.5-pro" }
      }
    },
    "blueprint-validator": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "temperature": 0.1
    },
    "export-generator": {
      "provider": "deepseek",
      "model": "deepseek-chat",
      "temperature": 0.2,
      "subAgents": {
        "openapi": { "provider": "openai", "model": "gpt-4o-mini" },
        "prisma": { "provider": "openai", "model": "gpt-4o-mini" },
        "typescript": { "provider": "deepseek", "model": "deepseek-chat" },
        "python": { "provider": "deepseek", "model": "deepseek-chat" }
      }
    },
    "refinement-advisor": {
      "provider": "gemini",
      "model": "gemini-2.5-flash",
      "temperature": 0.5
    }
  }
}
```

## Performance and Caching

### Agent Response Caching

PRDKit caches agent responses to avoid redundant API calls:

```json
{
  "agents": {
    "cache": {
      "enabled": true,
      "ttl": 3600,
      "maxSize": 100,
      "strategies": {
        "blueprint-generator": "lru",
        "blueprint-validator": "exact"
      }
    }
  }
}
```

### Parallel Execution

Independent agents run in parallel for performance:

```
User Request
    │
    ▼
Orchestrator
    │
    ├──▶ Generator Agent ──────┐
    │                          │
    ├──▶ Validator Agent ──────┤──▶ Orchestrator ──▶ Output
    │                          │    (Merge & Format)
    └──▶ Refinement Agent ─────┘
```

### Fallback Chains

If the primary agent fails, fallback chains ensure continuity:

```json
{
  "agents": {
    "blueprint-generator": {
      "provider": "openai",
      "fallbacks": [
        { "provider": "anthropic", "model": "claude-sonnet-4-20250514" },
        { "provider": "deepseek", "model": "deepseek-chat" }
      ]
    }
  }
}
```

## Observability

Each agent call produces structured telemetry:

```typescript
interface AgentTelemetry {
  agent: string;
  provider: string;
  model: string;
  duration: number;
  tokensUsed: { input: number; output: number; total: number };
  cost: number;
  cacheHit: boolean;
  error?: string;
  inputSize: number;
  outputSize: number;
}
```

View agent telemetry:

```bash
npx prdkit telemetry agents --session latest
```

## Summary

The multi-agent architecture provides:

- **Separation of concerns** — Each agent focuses on one task
- **Configurable intelligence** — Assign models per agent based on capability and cost
- **Extensibility** — Add custom agents via the plugin system
- **Reliability** — Fallback chains and parallel execution
- **Observability** — Full telemetry on every agent interaction
- **Testability** — Agents tested in isolation with contract enforcement
