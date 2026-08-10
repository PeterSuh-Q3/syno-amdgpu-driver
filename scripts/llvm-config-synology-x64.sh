#!/usr/bin/env bash
# Host-executable llvm-config facade for x86_64 Synology cross builds.
exec "$(dirname "$0")/llvm-config-epyc7002.sh" "$@"
