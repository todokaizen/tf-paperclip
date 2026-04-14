import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const cssPath = join(here, "..", "styles.css");
const css = readFileSync(cssPath, "utf8");

const submitBlockMatch = css.match(/\.submit-button\s*\{([^}]*)\}/);

test("submit button block exists in styles.css", () => {
  assert.ok(submitBlockMatch, ".submit-button { ... } block not found in styles.css");
});

test("submit button uses the expected brand background colour", () => {
  const expected = "#888";
  const block = submitBlockMatch?.[1] ?? "";
  assert.match(
    block,
    new RegExp(`background\\s*:\\s*${expected}\\b`, "i"),
    `expected .submit-button background to be ${expected}; this assertion must be updated when the button color is changed`,
  );
});
