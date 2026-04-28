---
name: "demo"
description: "Benchmark fixture project. Workspace is the rsync'd copy of companies/mock-website/fixture-repo/."
---

Demo project used by the TF-Paperclip token-efficiency benchmark. The workspace at `/tmp/mock-website-current/` is re-staged from `fixture-repo/` before every run, so every benchmark starts from byte-identical source.

The outstanding task is `fix-submit-button-color`: change the Submit button's `background` from `#888` to `#007BFF` and update the corresponding test assertion. See `fixture-repo/README.md` in the staged workspace for more.
