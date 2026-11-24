#!/bin/bash
# Hosts a Brelm fellowship with no player of its own. Friends join at this computer's address, UDP port 24600.
# See HOSTING.txt for opening the port. Press Ctrl+C to end the fellowship.
cd "$(dirname "$0")"
exec ./Brelm.x86_64 --headless -- server port=24600 name="A fellowship of Brelm"
