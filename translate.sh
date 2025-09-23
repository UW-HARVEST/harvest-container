#!/bin/sh

cp -R $1 $2/orig

mkdir $2/src
cat <<EOF > $2/src/main.rs
fn main() {
   println!("Hello World");
}
EOF

cat <<EOF > $2/Cargo.toml
[package]
name = "t"
version = "0.1.0"
edition = "2024"

[dependencies]
EOF


chown -R $newuid:$newgid $2/*
