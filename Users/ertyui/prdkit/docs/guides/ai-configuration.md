# Configuring AI Providers

PRDKit uses AI providers to generate blueprints from natural language, suggest refinements, and assist with editing. This guide covers everything about configuring and managing AI providers.

## Provider Overview

PRDKit supports multiple AI providers, each with different models, pricing, and capabilities:

| Provider | Models | Strengths |
|---|---|---|
| **OpenAI** | GPT-4o, GPT-4o-mini, o3, o4-mini | Strong general-purpose, structured output |
| **Anthropic** | Claude 4 Opus, Claude 4 Sonnet, Claude 3.5 Haiku | Long context, nuanced reasoning |
| **Google Gemini** | Gemini 2.5 Pro, Gemini 2.5 Flash | Large context windows, fast generation |
| **DeepSeek** | DeepSeek-V3, DeepSeek-R1 | Cost-effective, strong reasoning |
| **OpenRouter** | Aggregates 100+ models | Access to any model from one API |
| **Ollama** | Local models (Llama, Mistral, etc.) | Fully offline, no API costs |

## Adding Providers

### During Initialization

When running `npx prdkit init`, you'll be prompted to configure at least one AI provider:

```
┌──────────────────────────────────────────────┐
│         Configure AI Provider                │
│                                              │
│  Select a provider:                          │
│  [1] OpenAI                                  │
│  [2] Anthropic                               │
│  [3] Google Gemini                           │
│  [4] DeepSeek                                │
│  [5] OpenRouter                              │
│  [6] Ollama (local)                          │
│  [7] Skip (configure later)                  │
└──────────────────────────────────────────────┘
```

After selecting, you'll be asked for your API key and any provider-specific configuration.

### Configuration File

All provider configuration is stored in `prdkit.config.json`:

```json
{
  "providers": {
    "openai": {
      "enabled": true,
      "apiKey": "${OPENAI_API_KEY}",
      "defaultModel": "gpt-4o",
      "models": {
        "gpt-4o": { "enabled": true },
        "gpt-4o-mini": { "enabled": true },
        "o3": { "enabled": false },
        "o4-mini": { "enabled": false }
      }
    },
    "anthropic": {
      "enabled": true,
      "apiKey": "${ANTHROPIC_API_KEY}",
      "defaultModel": "claude-sonnet-4-20250514",
      "models": {
        "claude-sonnet-4-20250514": { "enabled": true },
        "claude-opus-4-20250514": { "enabled": true }
      }
    },
    "gemini": {
      "enabled": false,
      "apiKey": "${GEMINI_API_KEY}",
      "defaultModel": "gemini-2.5-pro"
    },
    "deepseek": {
      "enabled": false,
      "apiKey": "${DEEPSEEK_API_KEY}",
      "defaultModel": "deepseek-chat"
    },
    "openrouter": {
      "enabled": false,
      "apiKey": "${OPENROUTER_API_KEY}",
      "defaultModel": "anthropic/claude-sonnet-4"
    },
    "ollama": {
      "enabled": false,
      "baseUrl": "http://localhost:11434",
      "defaultModel": "llama3"
    }
  }
}
```

### Environment Variables

API keys use `${VAR_NAME}` syntax and are resolved from your environment or `.env` file:

```bash
# .env
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIza...
DEEPSEEK_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-...
```

> **Security:** Never commit API keys to version control. The `.env` file is in `.gitignore` by default.

### Using the CLI to Add Providers

```bash
# Add a new provider
npx prdkit providers add openai

# Enable/disable a provider
npx prdkit providers enable anthropic
npx prdkit providers disable gemini

# Set the default model for a provider
npx prdkit providers set-model openai gpt-4o-mini
```

## Model Discovery

PRDKit can discover available models from each provider:

```bash
npx prdkit providers list-models
```

Output:

```
OpenAI (enabled)
  ├── gpt-4o              (default)
  ├── gpt-4o-mini
  ├── o3                  (disabled)
  └── o4-mini             (disabled)

Anthropic (enabled)
  ├── claude-sonnet-4-20250514  (default)
  └── claude-opus-4-20250514

Google Gemini (disabled)
  ├── gemini-2.5-pro
  └── gemini-2.5-flash

DeepSeek (disabled)
  ├── deepseek-chat
  └── deepseek-reasoner
```

For OpenRouter, PRDKit fetches the full model catalog:

```bash
npx prdkit providers list-models --provider openrouter --refresh
```

This pulls the latest list from OpenRouter's API, including community models.

### Testing a Model

Before using a model in production, test it:

```bash
npx prdkit providers test openai gpt-4o-mini \
  --prompt "Generate a simple task management API blueprint"
```

PRDKit returns a sample blueprint and a cost estimate for that specific model.

## Provider Selection Per Agent

PRDKit's multi-agent system lets you assign different providers to different agents.

### Default Assignment

By default, all agents use the primary provider (the first one configured). You can change this:

```bash
npx prdkit providers set-default anthropic
```

### Per-Agent Assignment

In `prdkit.config.json`, configure agents individually:

```json
{
  "agents": {
    "blueprint-generator": {
      "provider": "openai",
      "model": "gpt-4o",
      "temperature": 0.3
    },
    "blueprint-validator": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "temperature": 0.1
    },
    "export-generator": {
      "provider": "deepseek",
      "model": "deepseek-chat",
      "temperature": 0.2
    },
    "refinement-advisor": {
      "provider": "gemini",
      "model": "gemini-2.5-flash",
      "temperature": 0.5
    }
  }
}
```

### Agent-to-Provider Mapping

| Agent | Recommended Provider | Reason |
|---|---|---|
| **Blueprint Generator** | OpenAI GPT-4o or Claude Opus | Strong structured output, best for initial PRDL generation |
| **Blueprint Validator** | Anthropic Claude Sonnet | Excellent at catching edge cases and inconsistencies |
| **Export Generator** | DeepSeek or GPT-4o-mini | Cost-effective for template-based generation |
| **Refinement Advisor** | Gemini 2.5 Flash | Low latency for interactive refinement |
| **Template Renderer** | (local/rule-based) | No AI needed — pure template execution |

### Per-Command Overrides

Override provider on a per-command basis:

```bash
npx prdkit generate "chat app" --provider anthropic
npx prdkit compile --provider openai
npx prdkit export --provider deepseek
```

## Cost Management

PRDKit tracks AI provider usage and provides cost estimates and budgets.

### Viewing Usage & Costs

```bash
npx prdkit providers usage
```

Output:

```
Provider Usage (this session)
┌────────────┬──────────┬──────────────┬────────────┐
│ Provider   │ Tokens   │ Est. Cost    │ Requests   │
├────────────┼──────────┼──────────────┼────────────┤
│ OpenAI     │  142,350 │ $0.0285      │        12  │
│ Anthropic  │   89,200 │ $0.0446      │         6  │
│ DeepSeek   │   45,000 │ $0.0014      │         5  │
├────────────┼──────────┼──────────────┼────────────┤
│ Total      │  276,550 │ $0.0745      │        23  │
└────────────┴──────────┴──────────────┴────────────┘

All-time usage: npx prdkit providers usage --all-time
```

### Setting Budget Limits

Configure monthly budgets in `prdkit.config.json`:

```json
{
  "providers": {
    "budget": {
      "monthly": 10.00,
      "warnAt": 8.00,
      "perProject": 2.00
    }
  }
}
```

PRDKit will warn when approaching limits and enforce hard caps:

```
⚠ Warning: You've used $8.50 of your $10.00 monthly budget.
  Remaining: $1.50
```

### Choosing Cost-Effective Models

For everyday work, use cheaper models and reserve expensive ones for complex tasks:

```bash
# Quick generation with cheaper model
npx prdkit generate "simple todo list" --provider openai --model gpt-4o-mini

# Complex blueprint with best model
npx prdkit generate "multi-tenant SaaS with billing, RBAC, webhooks" \
  --provider anthropic --model claude-opus-4-20250514
```

### Cost-Saving Strategies

1. **Use local models (Ollama)** for initial drafts — zero API cost
2. **Switch to cheaper models** for iterative refinement after the initial generation
3. **Cache frequent generations** — PRDKit caches identical prompts by default
4. **Set per-agent budgets** to control how much each agent can spend
5. **Monitor with `npx prdkit providers usage --export csv`** for spreadsheet analysis

## Troubleshooting

### API Key Issues

```bash
# Verify a provider is correctly configured
npx prdkit providers check openai
```

If you see authentication errors, ensure your API key is set in `.env` and the provider is enabled.

### Rate Limiting

```bash
# Configure rate limits per provider
npx prdkit providers set-rate-limit openai 100/minute
```

### Provider Not Responding

```bash
# Test connectivity
npx prdkit providers ping openai

# Switch to fallback provider
npx prdkit providers fallback anthropic
```

PRDKit can be configured to automatically fall back to a secondary provider if the primary is unavailable:

```json
{
  "providers": {
    "openai": {
      "enabled": true,
      "fallback": "anthropic"
    }
  }
}
```
