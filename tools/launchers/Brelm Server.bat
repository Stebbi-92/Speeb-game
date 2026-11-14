@echo off
rem Hosts a Brelm fellowship with no player of its own, in a small window that shows who comes and goes.
rem Friends join at this computer's address, UDP port 24600. See HOSTING.txt for opening the port.
start "" "%~dp0Brelm.exe" -- server port=24600 name="A fellowship of Brelm"
