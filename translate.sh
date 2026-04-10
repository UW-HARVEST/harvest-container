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
EOF

translate -f -o $2 $1
chown -R $newuid:$newgid $2/*
