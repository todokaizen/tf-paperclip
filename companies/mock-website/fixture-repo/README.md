# Mock Website (fixture product)

Tiny static site used as a benchmark target by the TF-Devflow token-efficiency benchmark.

## Outstanding task

Change the Submit button's `background` from `#888` to `#007BFF`:

1. Update `styles.css` — `.submit-button { background: … }`.
2. Update `tests/button.test.js` — the assertion currently expects `#888`; update to `#007BFF`.
3. Run `npm test` — all tests must pass.

## Running tests

```sh
npm test
```

Uses Node's built-in test runner (`node --test`). No dependencies to install.

## Do not edit this checked-in copy during a benchmark run

The benchmark runner `rsync`s this directory to `/tmp/mock-website-current/` before each run. The agent under test works on the scratch copy, not the tree under `companies/mock-website/fixture-repo/`. If you want to change the benchmark, edit here — but realise you have just changed the baseline and your past results may no longer be comparable.
