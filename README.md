# HARVEST Docker Container

## Building

```sh
$ docker build -t harvest/harvest .
```

## Features

This image runs HARVEST's agentic translation pipeline, driving Claude
(via the Anthropic API) to translate the C source project to Rust and
then verify and repair the result. HARVEST is pinned to a specific
commit and built from source against a pinned nixpkgs (see
`default.nix`), and the `claude` CLI and a Rust toolchain are provided
on the agent's PATH so it can build and test the translated crate.

## Authentication

Claude runs headless against the Anthropic API; there is no interactive
login. Provide the API key as an environment variable:

- `ANTHROPIC_API_KEY` -- required. The entry point exits immediately if
  it is unset.

## Interface expected by TRACTOR runner:

The TRACTOR runner takes a Docker image name, source and destination
directories on the host and uses these to invoke the translation
pipeline in this container.

The container must expect the following environment:

- A source directory bind-mounted in the container read-only.

- An output directory bind-mounted in the container read-only.

- $newuid and $newgid environment variables denoting the owner user
  and group that the output should belong to.

- `ANTHROPIC_API_KEY` set to a key with enough rate/usage headroom for a
  multi-hour run (a ~100 kloc translation can take many hours).

- A current-working-directory `/usr/c2rust_execution`

The container's entrypoint executable is passed two command-line arguments:

1. The source directory (e.g. `/tmp/src`)

2. The output directory (e.g. `/tmp/out`)
