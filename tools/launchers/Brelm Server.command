#!/bin/bash
# Hosts a Brelm fellowship with no player of its own. Friends join at this Mac's address, UDP port 24600.
# See HOSTING.txt for opening the port. Close this window or press Ctrl+C to end the fellowship.
cd "$(dirname "$0")"
exec ./Brelm.app/Contents/MacOS/* --headless -- server port=24600 name="A fellowship of Brelm"
