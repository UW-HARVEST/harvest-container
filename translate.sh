#!/bin/sh

mkdir -p ~/.local/share/kiro-cli/
wget -O ~/.local/share/kiro-cli/data.sqlite3 "$KIRO_CREDENTIAL_FILE"

mkdir -p ~/.config/harvest
cat > ~/.config/harvest/translate.toml <<EOF
[tools.raw_source_to_cargo_llm]
address = ""
api_key = "$OPEN_ROUTER_API_KEY"
backend = "openrouter"
model = "openai/gpt-5.3-codex"
max_tokens = 16384

[tools.modular_translation_llm]
address = ""
api_key = "$OPEN_ROUTER_API_KEY"
backend = "openrouter"
model = "openai/gpt-5.3-codex"
max_tokens = 16384

[tools.fix_declarations_llm]
address = ""
api_key = "$OPEN_ROUTER_API_KEY"
backend = "openrouter"
model = "openai/gpt-5.3-codex"
max_tokens = 16384

# The T&E runs against a much larger, unknown codebase (~100 kloc); a ~75 kloc
# translation took roughly 7 hours. The in-repo defaults (2h translate / 90m
# verify) are sized for small benchmarks, so the agentic agents need a far more
# generous wall-clock budget here. These are the external-timeout caps in
# seconds; overshooting is preferable to a premature kill.
[tools.translate_agentic]
timeout_secs = 43200   # 12h

[tools.verify_fix_agentic]
timeout_secs = 28800   # 8h
EOF

translate -f -o $2 $1
chown -R $newuid:$newgid $2/*
