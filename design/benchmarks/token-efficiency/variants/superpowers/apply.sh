#!/usr/bin/env bash
# Install the patched or unpatched session-start hook into the live
# superpowers plugin directory. Used by ab.sh to flip variants.
#
#   apply.sh patched     → install the PAPERCLIP_RUN_ID skip hook
#   apply.sh unpatched   → install the original (always-inject) hook
#
# The superpowers version directory is discovered dynamically; the newest
# numbered subdir under plugins/cache/claude-plugins-official/superpowers/
# wins, which matches where Claude Code's plugin loader actually reads from.
set -euo pipefail

usage() { echo "usage: $0 patched|unpatched" >&2; exit 1; }

[[ $# -eq 1 ]] || usage
variant="$1"
case "$variant" in patched|unpatched) ;; *) usage ;; esac

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/session-start.$variant"
[[ -f "$src" ]] || { echo "❌ missing source: $src" >&2; exit 1; }

plugin_root="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
[[ -d "$plugin_root" ]] || { echo "❌ superpowers plugin dir not found at $plugin_root" >&2; exit 1; }

# Pick the version directory with the highest sort order (lexicographic works
# for semver-ish 5.0.6 / 5.0.7; if superpowers ever ships 5.0.10 this needs
# `sort -V`, but we're fine for now).
version="$(ls -1 "$plugin_root" | sort -V | tail -1)"
[[ -n "$version" ]] || { echo "❌ no version dir under $plugin_root" >&2; exit 1; }

dst="$plugin_root/$version/hooks/session-start"
[[ -f "$dst" ]] || { echo "❌ hook target not found: $dst" >&2; exit 1; }

cp "$src" "$dst"
chmod +x "$dst"
echo "✅ installed superpowers $version $variant hook → $dst"
