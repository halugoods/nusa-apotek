# PRDKit Engine Feature Flags

Feature flag system configuration:

```javascript
const ENGINE_FLAGS = {
  // Core — always enabled
  domain: true,
  relationships: true,
  modules: true,
  validation: true,
  architecture: true,
  security: true,
  documentation: true,

  // Optional — feature flagged
  stateMachine: false,
  events: false,
  pages: false,
  uiFlows: false,
  tests: false,
  deployment: false,
  observability: false,
  aiAgents: false,
  costPricing: false,
  execution: false,
  migration: false,

  // Postponed
  evolution: false,
};
```

Each flag controls:
1. Whether the engine runs in the pipeline
2. Whether its artifacts are generated
3. Whether its section appears in the prompt
4. Whether its UI appears in the result page
