#!/bin/sh
#
# Entry point for the agentic Claude translation path.
#
# Invoked as: translate-wrapper <source-dir> <output-dir>
#
# Required environment:
#   ANTHROPIC_API_KEY  Claude authenticates against the Anthropic API with this
#                      key (no interactive login). Provided to the container by
#                      the T&E runner.
#   newuid / newgid    Owner the output should belong to (set by the runner).

# Claude reads ANTHROPIC_API_KEY from the environment; fail fast if it is absent
# rather than dropping into an interactive login that cannot succeed headless.
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "translate-wrapper: ANTHROPIC_API_KEY is not set; the agentic Claude" \
         "path cannot authenticate." >&2
    exit 1
fi

# The agent (cargo, claude config, HARVEST config) needs a writable HOME, and
# cando2's AF_UNIX socket path is capped at 108 bytes, so keep TMPDIR short.
export HOME="${HOME:-/tmp/harvest-home}"
export TMPDIR=/tmp
mkdir -p "$HOME"

# Deployment config: give the agentic agents a T&E-sized budget. ~100 kloc
# inputs can run for many hours, so override the modest in-repo defaults (2h
# translate / 90m verify). These are plain config keys read by harvest_translate.
mkdir -p "$HOME/.config/harvest"
cat > "$HOME/.config/harvest/translate.toml" <<EOF
[tools.translate_agentic]
timeout_secs = 43200   # 12h

[tools.verify_fix_agentic]
timeout_secs = 28800   # 8h
EOF

translate --agentic --agentic-verify --agentic-agent claude -f -o "$2" "$1"
chown -R "$newuid:$newgid" "$2"/*
