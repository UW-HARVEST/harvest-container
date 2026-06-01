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

# Claude Code refuses --permission-mode bypassPermissions as root unless it is
# told it is running in a recognized sandbox. This image runs as root in an
# ephemeral, isolated T&E container, which is exactly that, so signal it.
export IS_SANDBOX=1

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

# The T&E hands us a parent directory whose actual C project lives in a
# `test_case/` subdirectory, alongside a top-level CMakeLists.txt that only does
# `add_subdirectory(test_case)`, an optional CMakePresets.json, and an optional
# `tests/` harness. HARVEST translates the C project, and its build_config /
# build_project_spec stages look for configuration.json and the
# add_executable/add_library CMakeLists at the root of what they are given -- so
# point them at test_case/. Inputs that already are the project (no test_case/
# child, as in the older corpus) are used unchanged.
src="$1"
clar_cfg=""
if [ -d "$src/test_case" ]; then
    src="$src/test_case"
    echo "translate-wrapper: input has a test_case/ child; translating '$src'." >&2
    # June T&E experiment: if the parent also ships a clar test harness, hand the
    # parent path to the verify stage so it can build and run those tests against
    # the original C as a behavioral oracle (see verify_fix_agentic). The value
    # has no spaces (container temp paths), so the unquoted expansion below is
    # the intended two-argument split.
    if [ -d "$1/tests" ]; then
        clar_cfg="--config tools.verify_fix_agentic.clar_parent_dir=$1"
        echo "translate-wrapper: clar tests present; enabling the verify oracle." >&2
    fi
fi

# shellcheck disable=SC2086
translate --agentic --agentic-verify --agentic-agent claude $clar_cfg -f -o "$2" "$src"
chown -R "$newuid:$newgid" "$2"/*
