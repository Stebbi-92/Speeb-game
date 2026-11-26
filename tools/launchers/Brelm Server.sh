#!/bin/bash
# Hosts a Brelm fellowship with no player of its own. Friends join at this computer's address, UDP port 24600.
# See HOSTING.txt for opening the port, and for server.cfg, which holds the settings.
# Type help for commands; quit saves and stops. Ctrl+C ends it without saving.
cd "$(dirname "$0")"
exec ./Brelm.x86_64 --headless -- server
