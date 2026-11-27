@echo off
rem Hosts a Brelm fellowship with no player of its own, in a window that manages the server.
rem Its settings (name, port, password and more) are in the window, and kept in server.cfg.
rem Friends join at this computer's address, UDP port 24600. See HOSTING.txt for opening the port.
start "" "%~dp0Brelm.exe" -- server
