# Getting Started with PRDKit

## What is PRDKit?

PRDKit is a universal AI-powered Product Blueprint Studio by **Halu Goods**. It lets you describe any product idea in natural language, craft it into a structured Product Requirements Document using the **PRDL** (Product Requirements Definition Language), and then export that blueprint into production-ready artifacts — TypeScript types, Python models, OpenAPI specs, Prisma schemas, Docker Compose files, design tokens, and more. PRDKit uses a multi-agent AI system to guide you from raw idea to executable specification, with full version management and template support baked in.

## Prerequisites

Before you begin, make sure your environment meets the following requirements:

- **Node.js 20+** — PRDKit requires Node.js 20 or later. Check your version:
  ```bash
  node --version
  ```
- **pnpm** — PRDKit uses pnpm for package management. Install it if you don't have it:
  ```bash
  npm install -g pnpm
  ```
- A terminal or command prompt (Git Bash, PowerShell, or any POSIX-compatible shell)

## Installation

Install PRDKit globally via npm and initialize your first workspace:

```bash
npx @prdkit/cli init
```

This command will:

1. **Prompt you for a project name** — Enter something like `my-first-blueprint`
2. **Ask about your default AI provider** — Choose from OpenAI, Anthropic, Gemini, DeepSeek, or skip
3. **Create a workspace folder** with the following structure:

```
my-first-blueprint/
  ├── prdkit.config.json       # Project configuration
  ├── blueprints/              # Your PRDL blueprint files
  │   └── example.prdl         # A sample blueprint to get started
  ├── exports/                 # Generated export artifacts
  ├── templates/               # Custom export templates
  └── .env                     # API keys (if you configured a provider)
```

4. **Install dependencies** — PRDKit's core and any provider SDKs you selected.

Once complete, you'll see a success message like:

```
✔ Initialized PRDKit workspace in my-first-blueprint/
✔ Example blueprint created at blueprints/example.prdl
✔ Run `npx prdkit dev` to start the interactive studio
```

## Your First Blueprint

Follow these steps to create a blueprint from scratch.

### Step 1: Open the Interactive Studio

```bash
cd my-first-blueprint
npx prdkit dev
```

This launches the PRDKit Studio — a terminal-based interactive environment. You'll see a welcome panel:

```
┌──────────────────────────────────────────────┐
│            PRDKit Studio v1.0.0              │
│     Universal AI Product Blueprint Studio    │
│                                              │
│  [1] Create Blueprint from Idea              │
│  [2] Create Blueprint from PRDL              │
│  [3] Open Existing Blueprint                 │
│  [4] Export Blueprint                        │
│  [5] Configure AI Providers                  │
│  [6] Exit                                    │
│                                              │
│  Choose an option (1-6):                     │
└──────────────────────────────────────────────┘
```

### Step 2: Describe Your Idea

Select option **1** (Create Blueprint from Idea). The AI agent will prompt you:

```
Describe your product idea in natural language.
Be as detailed or as brief as you like — the AI will ask
clarifying questions to fill in the gaps.

> A task management API with user authentication,
  projects, tasks with labels and due dates,
  and a kanban board view.
```

The AI will then ask a few clarifying questions:

```
Product name:  [TaskFlow]
Primary users: [developers, project managers]
Tech stack:    [Node.js, PostgreSQL, React]
```

After answering, the AI generates a complete PRDL blueprint.

### Step 3: Review the Generated PRDL

The blueprint opens in the editor view. You'll see the structured PRDL:

```prdl
blueprint TaskFlow {
  version "1.0.0"
  description "A task management API with kanban board support"

  domain {
    name "project-management"
    description "Project and task organization"
  }

  actors {
    User {
      fields {
        id: UUID
        email: Email
        name: String
        avatar: URL?
      }
      auth {
        method JWT
        roles [admin, member]
      }
    }

    Project {
      fields {
        id: UUID
        name: String
        description: Text?
        owner: Reference<User>
        created_at: DateTime
      }
    }

    Task {
      fields {
        id: UUID
        title: String
        description: Text?
        status: Enum<backlog, todo, in_progress, review, done>
        priority: Enum<low, medium, high, critical>
        labels: Array<String>
        due_date: Date?
        assignee: Reference<User>?
        project: Reference<Project>
        position: Integer
      }
    }
  }

  endpoints {
    POST /auth/register -> User
    POST /auth/login -> { token: String }
    GET /projects -> Array<Project>
    POST /projects -> Project
    GET /projects/:id -> Project
    PUT /projects/:id -> Project
    DELETE /projects/:id -> void
    GET /projects/:id/tasks -> Array<Task>
    POST /projects/:id/tasks -> Task
    PUT /tasks/:id -> Task
    DELETE /tasks/:id -> void
    PUT /tasks/:id/position -> { position: Integer }
  }

  exports {
    openapi true
    prisma true
    typescript true
    python true
  }
}
```

### Step 4: Compile and Validate

Save the blueprint and compile it:

```bash
npx prdkit compile blueprints/taskflow.prdl
```

You'll see output like:

```
ℹ Compiling blueprint: TaskFlow v1.0.0
✔ PRDL syntax valid
✔ Domain context resolved
✔ Actor relationships validated
✔ Endpoint contracts verified
✔ 0 errors, 2 warnings
```

Warnings might include missing descriptions or optional fields — these are non-blocking.

### Step 5: Export Artifacts

Now export your blueprint into real code and documentation:

```bash
npx prdkit export blueprints/taskflow.prdl --formats openapi,prisma,typescript
```

This generates the following files in `exports/`:

```
exports/
  ├── openapi.yaml          # OpenAPI 3.1 specification
  ├── schema.prisma         # Prisma data model
  ├── types.ts              # TypeScript type definitions
  ├── index.ts              # Barrel exports
  └── taskflow.prd.md       # Full PRD documentation in Markdown
```

Alternatively, export everything at once:

```bash
npx prdkit export blueprints/taskflow.prdl --all
```

## The PRDL → Compile → Export Flow

PRDKit's core workflow follows three stages:

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  PRDL    │ ──▶ │ Compile  │ ──▶ │  Export  │
│ (Write)  │     │ (Verify) │     │ (Generate)│
└──────────┘     └──────────┘     └──────────┘
```

1. **Write PRDL** — Define your product in the Product Requirements Definition Language. You can write it by hand, use the AI to generate it from natural language, or start from a template.

2. **Compile** — The PRDKit compiler validates syntax, resolves references, checks domain consistency, and verifies endpoint contracts. Errors are reported with line numbers for quick fixes.

3. **Export** — Generate production-ready artifacts from your validated blueprint. Choose individual formats or export all at once. Each export format has its own template that you can customize.

## Next Steps

Now that you've created your first blueprint, here's where to go next:

| Topic | Description |
|---|---|
| **Creating Blueprints** | Learn how to create blueprints from ideas, PRDL, or templates. |
| **AI Configuration** | Configure OpenAI, Anthropic, Gemini, and other providers. |
| **Export Formats** | Deep dive into each export format and its options. |
| **Custom Templates** | Build your own export templates with PRDKit's template engine. |
| **Architecture** | Understand the multi-agent system powering PRDKit. |
| **Deployment** | Deploy PRDKit locally, self-hosted, or in the cloud. |

> **Tip:** Run `npx prdkit --help` anytime to see all available commands and options.
