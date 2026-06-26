# Custom Templates

PRDKit's template engine lets you create custom export templates so you can generate any artifact format your project needs. Templates use [Handlebars](https://handlebarsjs.com/)-inspired syntax with PRDKit-specific helpers and data bindings.

## Template System Overview

Export templates live in the `templates/` directory of your PRDKit workspace:

```
my-first-blueprint/
  ├── templates/
  │   ├── openapi.hbs          # Override default OpenAPI template
  │   ├── graphql-schema.hbs   # Custom GraphQL schema export
  │   ├── readme.hbs           # Auto-generated README template
  │   └── partials/
  │       ├── header.hbs       # Shared header partial
  │       └── footer.hbs       # Shared footer partial
  └── ...
```

Each template corresponds to an export format. When you run `npx prdkit export`, PRDKit:

1. Checks if a custom template exists in `templates/`
2. If yes, uses the custom template instead of the built-in one
3. If no, falls back to the built-in default

## Template Syntax

Templates are plain text files with handlebars-style `{{ }}` expressions.

### Variable Interpolation

Access blueprint data with double curly braces:

```handlebars
# {{blueprint.name}} — {{blueprint.description}}

Version: {{blueprint.version}}
Domain: {{blueprint.domain.name}}

Generated on: {{generatedAt}}
```

### Nested Object Access

Use dot notation to access nested properties:

```handlebars
## Actors

{{#each blueprint.actors}}
### {{@key}}

| Field | Type | Required |
|-------|------|----------|
{{#each fields}}
| {{@key}} | {{type}} | {{#if required}}Yes{{else}}No{{/if}} |
{{/each}}
{{/each}}
```

### Loops

Iterate over arrays with `{{#each}}`:

```handlebars
## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
{{#each blueprint.endpoints}}
| {{method}} | {{path}} | {{#if auth}}🔒{{else}}🔓{{/if}} | {{description}} |
{{/each}}
```

### Conditionals

Use `{{#if}}`, `{{#unless}}`, `{{#else}}` for conditional content:

```handlebars
{{#if blueprint.auth}}
## Authentication

This API uses **{{blueprint.auth.method}}** authentication.
Tokens expire in {{blueprint.auth.expires}}.

{{#unless blueprint.auth.refreshEnabled}}
> ⚠ No refresh token support configured.
{{/unless}}

{{else}}
## Authentication

⚠ No authentication configured for this blueprint.
{{/if}}
```

### Comments

```handlebars
{{!-- This is a comment and won't appear in output --}}
```

## Template Data Model

Templates receive a structured data object with all blueprint information. Here's the complete data model:

```typescript
interface TemplateData {
  blueprint: {
    name: string;
    version: string;
    description: string;
    extends?: string;
    domain: {
      name: string;
      description: string;
    };
    actors: Record<string, Actor>;
    relationships: Relationship[];
    endpoints: Endpoint[];
    auth?: AuthConfig;
    exports?: ExportConfig;
  };
  generatedAt: string;           // ISO timestamp
  generatorVersion: string;       // PRDKit version
  options: Record<string, any>;   // User-provided template options
}

interface Actor {
  description?: string;
  fields: Record<string, Field>;
  auth?: AuthConfig;
}

interface Field {
  type: string;                    // e.g., "String", "UUID", "Email"
  required: boolean;
  unique: boolean;
  primary: boolean;
  default?: string;
  description?: string;
  nullable: boolean;
  isArray: boolean;
  enumValues?: string[];
  // For reference types
  refActor?: string;
  refField?: string;
}

interface Relationship {
  type: 'has_one' | 'has_many' | 'belongs_to';
  source: string;
  target: string;
  through?: string;
  as?: string;
  optional: boolean;
}

interface Endpoint {
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
  description?: string;
  auth: 'public' | 'auth' | 'roles';
  roles?: string[];
  rateLimit?: string;
  request?: {
    body?: Record<string, Field>;
    query?: Record<string, Field>;
    params?: Record<string, Field>;
  };
  response: {
    type: string;
    isArray: boolean;
    fields?: Record<string, Field>;
  };
}
```

## Built-in Helpers

PRDKit provides several helpers for common template operations:

### Format Helpers

```handlebars
{{!-- Uppercase --}}
{{uppercase blueprint.name}}

{{!-- Lowercase --}}
{{lowercase blueprint.name}}

{{!-- Capitalize first letter --}}
{{capitalize description}}

{{!-- Snake case --}}
{{snakeCase "My Field Name"}}    {{!-- "my_field_name" --}}

{{!-- Camel case --}}
{{camelCase "my_field_name"}}    {{!-- "myFieldName" --}}

{{!-- Pascal case --}}
{{pascalCase "my_field_name"}}   {{!-- "MyFieldName" --}}

{{!-- Kebab case --}}
{{kebabCase "my_field_name"}}    {{!-- "my-field-name" --}}

{{!-- Pluralize --}}
{{pluralize "task"}}             {{!-- "tasks" --}}
{{pluralize "status"}}           {{!-- "statuses" --}}

{{!-- Singularize --}}
{{singularize "tasks"}}          {{!-- "task" --}}
```

### Type Mapping Helpers

```handlebars
{{!-- Map PRDL type to TypeScript type --}}
{{tsType "Email"}}              {{!-- "string" --}}
{{tsType "UUID"}}               {{!-- "string" --}}
{{tsType "DateTime"}}           {{!-- "string" --}}
{{tsType "Integer"}}            {{!-- "number" --}}

{{!-- Map PRDL type to Python type --}}
{{pyType "Email"}}              {{!-- "EmailStr" --}}
{{pyType "UUID"}}               {{!-- "UUID" --}}
{{pyType "DateTime"}}           {{!-- "datetime" --}}

{{!-- Map PRDL type to Prisma type --}}
{{prismaType "Email"}}          {{!-- "String" --}}
{{prismaType "Text"}            {{!-- "String" --}}

{{!-- Map PRDL type to OpenAPI type --}}
{{oapiType "Email"}}            {{!-- "string", format: "email" --}}
```

### Structural Helpers

```handlebars
{{!-- Indent content --}}
{{indent 4 "some text"}}

{{!-- Join array --}}
{{join enumValues ", "}}

{{!-- Check if value is defined --}}
{{#defined field.default}}
  Default: {{field.default}}
{{/defined}}

{{!-- Format date --}}
{{formatDate generatedAt "YYYY-MM-DD"}}

{{!-- Include a partial --}}
{{> header}}
```

## Creating a Custom Template: Step by Step

### Step 1: Create the Template File

Create `templates/graphql-schema.hbs`:

```handlebars
{{!-- GraphQL Schema Generator --}}
{{!-- Generated by PRDKit on {{generatedAt}} --}}

type Query {
{{#each blueprint.endpoints}}
{{#if (eq method "GET")}}
  {{camelCase path}}(): {{response.type}}{{#if response.isArray}}[{{response.type}}]{{/if}}
{{/if}}
{{/each}}
}

type Mutation {
{{#each blueprint.endpoints}}
{{#if (ne method "GET")}}
  {{camelCase path}}({{#if request.body}}
    {{#each request.body}}
    {{@key}}: {{tsType type}}{{#unless required}}!{{/unless}}
    {{/each}}
  {{/if}}): {{response.type}}{{#if response.isArray}}[{{response.type}}]{{/if}}
{{/if}}
{{/each}}
}

{{#each blueprint.actors}}
type {{@key}} {
  {{#each fields}}
  {{@key}}: {{tsType type}}{{#unless required}}!{{/unless}}
  {{/each}}
}
{{/each}}
```

### Step 2: Register the Template

In `prdkit.config.json`, add your custom format:

```json
{
  "exports": {
    "formats": ["openapi", "prisma", "graphql", "typescript"],
    "graphql": {
      "enabled": true,
      "template": "graphql-schema.hbs"
    }
  }
}
```

### Step 3: Export with Your Template

```bash
npx prdkit export blueprints/app.prdl --format graphql
```

Output: `exports/schema.graphql`

## Partials (Reusable Snippets)

Partials let you reuse template fragments across multiple templates.

### Creating Partials

Create `templates/partials/header.hbs`:

```handlebars
{{!--
  Header partial — used by multiple export templates
--}}
// {{blueprint.name}} v{{blueprint.version}}
// Generated by PRDKit {{generatorVersion}}
// Do not edit directly — change the blueprint and re-export

import { z } from 'zod';
```

Create `templates/partials/footer.hbs`:

```handlebars
// End of generated types for {{blueprint.name}}
```

### Using Partials

```handlebars
{{> header}}

export const {{pascalCase blueprint.name}}Config = {
  version: "{{blueprint.version}}",
  domain: "{{blueprint.domain.name}}",
};

{{> footer}}
```

### Partial Resolution Order

PRDKit looks for partials in this order:

1. `templates/partials/<name>.hbs`
2. `templates/<name>.hbs`
3. PRDKit's built-in partials

## Template Inheritance

Templates can extend other templates using the `{{#extends}}` directive:

```handlebars
{{!-- templates/my-zod.hbs — extends the built-in zod template --}}
{{#extends "zod"}}

{{!-- Add custom validation after the default content --}}
{{#each blueprint.actors}}
export const {{@key}}Validator = {{@key}}Schema;
{{/each}}
{{/extends}}
```

## Variables from the CLI

Pass variables to templates at export time:

```bash
npx prdkit export blueprints/app.prdl --template my-template.hbs \
  --var namespace="MyApp" \
  --var includeTests=true
```

Access these in your template:

```handlebars
{{#if options.includeTests}}
// Tests included per export options
{{/if}}

namespace {{options.namespace}};
```

## Testing Templates

Validate your template against a blueprint:

```bash
npx prdkit template test templates/my-template.hbs \
  --blueprint blueprints/app.prdl
```

PRDKit will render the template and show any errors with line numbers.

## Sharing Templates Across Projects

### Template Packages

Templates can be packaged and shared via npm:

```bash
npx prdkit template package templates/my-template.hbs \
  --name @myorg/prdkit-templates \
  --version 1.0.0
```

This creates a `package.json` and `templates/` directory ready for publishing.

### Installing Templates from npm

```bash
npx prdkit template install @myorg/prdkit-templates
```

This installs the package's templates into your local `templates/` directory.

### Template Directory as a Git Repo

You can also version-control your templates independently:

```bash
cd templates
git init
git add .
git commit -m "Initial template set"
git remote add origin https://github.com/myorg/prdkit-templates.git
git push
```

Then on another machine:

```bash
cd my-first-blueprint
git submodule add https://github.com/myorg/prdkit-templates.git templates
```

## Built-in Template Reference

PRDKit ships with the following built-in templates (all customizable by creating a `.hbs` file of the same name in your `templates/` directory):

| Template File | Default Format | Description |
|---|---|---|
| `openapi.hbs` | OpenAPI 3.1 | Full API specification |
| `prisma.hbs` | Prisma Schema | Database schema |
| `typescript.hbs` | TypeScript Types | Type definitions |
| `zod.hbs` | Zod Schemas | Runtime validation |
| `python.hbs` | Python Models | Pydantic models |
| `markdown.hbs` | Markdown PRD | Human-readable docs |
| `docker.hbs` | Docker Compose | Container orchestration |
| `tokens.hbs` | Design Tokens | Design system values |
| `mermaid-entity.hbs` | ERD | Entity relationship diagram |
| `mermaid-flow.hbs` | Data Flow | Data flow diagram |
| `mermaid-state.hbs` | State Machine | State machine diagram |
