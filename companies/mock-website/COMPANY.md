---
name: "Mock Website"
schema: "agentcompanies/v1"
slug: "mock-website"
---

Benchmark fixture — not a real company. Exists so TF-Devflow config changes can be measured against a frozen baseline task. The product lives at `fixture-repo/` and is rsynced to a scratch path before each run so every benchmark starts from the same state.

Do not add real work here. If the config needs to change, that change IS the benchmark variant.
