#!/bin/bash
# Starts Brelm on the simpler OpenGL renderer, for older graphics cards.
cd "$(dirname "$0")"
exec ./Brelm.x86_64 --rendering-method gl_compatibility
