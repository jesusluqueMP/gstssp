#!/bin/bash
set -e

if [ -d "build" ]; then
    rm -rf build
fi

meson setup build
