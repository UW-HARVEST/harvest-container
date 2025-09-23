# HARVEST Docker Container

## Building

```sh
$ docker build -t harvest/harvest .
```

## Features

WIP

This "translation" image does not translation whatsoever. It merely
copies the source project to a `orig` subdirectory in the output, and
initializes an empty Rust/Cargo binary alongside it so the test
infrastructure has _something_ to compile.

## Interface expected by TRACTOR runner:

The TRACTOR runner takes a Docker image name, source and destination
directories on the host and uses these to invoke the translation
pipeline in this container.

The container must expect the following environment:

- A source directory bind-mounted in the container read-only.

- An output directory bind-mounted in the container read-only.

- $newuid and $newgid environment variables denoting the owner user
  and group that the output should belong to.

- A current-working-directory `/usr/c2rust_execution`

The container's entrypoint executable is passed two command-line arguments:

1. The source directory (e.g. `/tmp/src`)

2. The output directory (e.g. `/tmp/out`)
