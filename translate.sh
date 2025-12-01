#!/bin/sh

mkdir -p ~/.config/harvest
cat > ~/.config/harvest/translate.toml <<EOF
[tools.raw_source_to_cargo_llm]
address = ""
api_key = "$OPEN_ROUTER_API_KEY"
backend = "openrouter"
model = "x-ai/grok-code-fast-1"
max_tokens = 10000
EOF

translate -f -o $2 $1
chown -R $newuid:$newgid $2/*
