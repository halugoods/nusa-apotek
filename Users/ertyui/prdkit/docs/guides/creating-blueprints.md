# Creating Blueprints

Blueprints are the core artifact in PRDKit. Each blueprint is a structured product specification written in **PRDL** (Product Requirements Definition Language). This guide covers all the ways to create, edit, and manage them.

## From a Natural Language Idea

The fastest way to create a blueprint is to describe your idea in plain English and let the AI build the PRDL for you.

### Using the Interactive Studio

```bash
npx prdkit dev
```

Select **Create Blueprint from Idea** (option 1). The AI agent will:

1. Ask you to describe your product idea
2. Ask clarifying questions about actors, endpoints, data models
3. Generate a complete PRDL blueprint
4. Open it in the editor for review

### Using the CLI Directly

```bash
npx prdkit generate "A real-time chat API with rooms, users, and message history"
```

Flags you can use:

| Flag | Description |
|---|---|
| `--name` | Set the blueprint name explicitly |
| `--domain` | Specify the domain context (e.g., `communication`) |
| `--tech-stack` | Hint at the target tech stack (e.g., `node,postgres,websockets`) |
| `--output, -o` | Output file path (default: `blueprints/<name>.prdl`) |
| `--provider` | AI provider to use (overrides config) |

### Interactive Refinement

After generation, the AI will offer to refine the blueprint:

```
Would you like to:
  [1] Add more endpoints
  [2] Add more fields to an actor
  [3] Change data types
  [4] Add relationships
  [5] Done — I'm happy with it
```

## From PRDL Directly

If you know the PRDL syntax, writing blueprints by hand gives you full control.

### Anatomy of a PRDL File

```prdl
blueprint TaskFlow {
  version "1.0.0"
  description "Task management API"
  extends "base-api"

  domain {
    name "project-management"
    description "Project and task organization"
  }

  actors {
    User {
      fields {
        id: UUID @primary
        email: Email @unique
        name: String @required
        avatar: URL?
        role: Enum<admin, member> @default("member")
      }
      auth {
        method JWT
        expires "24h"
      }
    }
  }

  relationships {
    User has_many Project
    Project has_many Task
    Task belongs_to User as "assignee"?
  }

  endpoints {
    POST /auth/register -> User @public
    POST /auth/login -> { token: String } @public
    GET /users/me -> User @auth
  }

  exports {
    openapi { version "3.1.0" }
    prisma { provider "postgresql" }
    typescript { strict true }
  }
}
```

### PRDL Syntax Reference

| Construct | Description |
|---|---|
| `blueprint <name> { }` | Root blueprint definition |
| `version "x.y.z"` | Semantic version of the blueprint |
| `extends "<name>"` | Inherit from another blueprint |
| `domain { }` | Domain context and categorization |
| `actors { }` | Define entities, their fields, and auth rules |
| `relationships { }` | Define relationships between actors |
| `endpoints { }` | Define API endpoints and contracts |
| `exports { }` | Configure which export formats to generate |

### Field Annotations

| Annotation | Meaning |
|---|---|
| `@primary` | Primary identifier field |
| `@unique` | Unique constraint |
| `@required` | Non-nullable field |
| `@default("value")` | Default value |
| `@relation("name")` | Named relationship |
| `?` suffix | Optional/nullable field |
| `Array<Type>` | Array of the specified type |

### Endpoint Annotations

| Annotation | Meaning |
|---|---|
| `@public` | No authentication required |
| `@auth` | Requires valid authentication |
| `@roles [admin]` | Restrict to specific roles |
| `@rate_limit("100/h")` | Rate limit configuration |

### Built-in Types

`String`, `Integer`, `Float`, `Boolean`, `UUID`, `Email`, `URL`, `DateTime`, `Date`, `Text`, `Enum<...>`, `Reference<Actor>`, `Array<Type>`, `Map<Key, Value>`

## From Templates

PRDKit ships with built-in templates and supports custom templates.

### Listing Available Templates

```bash
npx prdkit list-templates
```

You'll see output like:

```
Available templates:
  ┌────────────────────┬──────────────────────────────────┐
  │ Template           │ Description                      │
  ├────────────────────┼──────────────────────────────────┤
  │ rest-api           │ Standard REST API blueprint       │
  │ graphql-api        │ GraphQL API with schema types     │
  │ event-driven       │ Event-driven / microservice spec │
  │ crud-app           │ Full CRUD application             │
  │ cli-tool           │ Command-line interface spec       │
  │ mobile-backend     │ Mobile app backend with auth      │
  │ saas-product       │ SaaS product with billing         │
  │ custom             │ Empty blueprint — start fresh     │
  └────────────────────┴──────────────────────────────────┘
```

### Creating from a Template

```bash
npx prdkit create my-blueprint --template rest-api
```

This creates `blueprints/my-blueprint.prdl` pre-populated with the template's structure. You can then edit it to fit your specific needs.

### Template Variables

Some templates accept variables:

```bash
npx prdkit create my-api --template rest-api \
  --var name="MyAPI" \
  --var description="My custom API" \
  --var auth="jwt"
```

## Editing and Iterating

### Opening a Blueprint for Edit

```bash
npx prdkit edit blueprints/my-blueprint.prdl
```

This opens the blueprint in the interactive editor where you can:

- Add, modify, or remove actors and their fields
- Add, update, or delete endpoints
- Adjust data types and annotations
- Add relationships between actors
- Modify export configurations

### Making Bulk Changes

For larger changes, edit the PRDL file directly with your preferred editor, then recompile:

```bash
npx prdkit compile blueprints/my-blueprint.prdl
```

The compiler will report any issues introduced by your changes.

### Validating After Edit

Always validate after significant edits:

```bash
npx prdkit validate blueprints/my-blueprint.prdl
```

This runs all validation checks without generating exports.

## Version Management

PRDKit supports semantic versioning for your blueprints.

### Setting a Version

Each blueprint has a `version` field in its PRDL:

```prdl
blueprint TaskFlow {
  version "1.0.0"
  ...
}
```

### Bumping Versions

```bash
# Patch bump (1.0.0 → 1.0.1)
npx prdkit version bump blueprints/my-blueprint.prdl --patch

# Minor bump (1.0.0 → 1.1.0)
npx prdkit version bump blueprints/my-blueprint.prdl --minor

# Major bump (1.0.0 → 2.0.0)
npx prdkit version bump blueprints/my-blueprint.prdl --major
```

### Version History

PRDKit maintains a changelog for each blueprint in `blueprints/<name>.changelog.md`:

```markdown
# TaskFlow Changelog

## 1.1.0 (2025-06-18)
- Added `labels` field to Task
- Added `priority` enum to Task
- Added PATCH /tasks/:id endpoint

## 1.0.1 (2025-06-15)
- Fixed UUID type on Project.id
- Added unique constraint on User.email

## 1.0.0 (2025-06-10)
- Initial blueprint
```

### Diff Between Versions

```bash
npx prdkit diff my-blueprint.prdl --from 1.0.0 --to 1.1.0
```

Outputs a structured diff showing what changed between versions, useful for code review and team communication.

### Committing Blueprints (Git Integration)

PRDKit blueprints are plain-text files designed for version control:

```bash
git add blueprints/
git commit -m "feat: add label and priority support to TaskFlow"
```

We recommend `.gitignore` entries for `exports/` and `.env` but tracking all `.prdl` files.
