"""Packages the exported builds into the Windows, macOS and Linux zips. Run from the project root after exporting.
Usage: python3 tools/package.py <out_dir>"""
import glob
import sys, zipfile, os
out = sys.argv[1]
readme = open("README.txt").read()
mac_note = """MACOS
  Unzip, then drag "Brelm.app" to Applications (or run it where it is).
  Works on Apple Silicon and Intel Macs, macOS 10.12 or later.
  The game is not notarized by Apple, so the first launch is blocked:
    1. Double-click Brelm.app, and dismiss the warning.
    2. Open System Settings > Privacy & Security, scroll down, and click
       "Open Anyway" next to Brelm. Confirm once more.
  Or, in Terminal:  xattr -dr com.apple.quarantine /Applications/Brelm.app
  Fullscreen: F11, Alt+Enter, or Ctrl+Cmd+F.

"""
def text_info(name):
    zi = zipfile.ZipInfo(name, (2026, 10, 29, 12, 0, 0)); zi.external_attr = 0o100644 << 16; zi.create_system = 3
    zi.compress_type = zipfile.ZIP_DEFLATED; return zi
with zipfile.ZipFile(os.path.join(out, "Brelm-Windows.zip"), "w", zipfile.ZIP_DEFLATED) as z:
    z.write("build/Brelm.exe", "Brelm.exe")
    z.write("build/Brelm (compatibility mode).bat", "Brelm (compatibility mode).bat")
    z.write("build/Brelm Server.bat", "Brelm Server.bat")
    for lib in sorted(glob.glob("build/*.dll")):   # the WebRTC plugin, for co-op through any router
        z.write(lib, os.path.basename(lib))
    z.writestr(text_info("HOSTING.txt"), open("HOSTING.txt").read())
    z.writestr(text_info("README.txt"), readme)
    z.writestr(text_info("THIRD-PARTY-NOTICES.txt"), open("THIRD-PARTY-NOTICES.txt").read())
src = zipfile.ZipFile("build-mac/Brelm.zip")
with zipfile.ZipFile(os.path.join(out, "Brelm-macOS.zip"), "w", zipfile.ZIP_DEFLATED) as z:
    for i in src.infolist():
        parts = i.filename.split("/", 1)
        ni = zipfile.ZipInfo("Brelm.app/" + parts[1], i.date_time)
        ni.external_attr = i.external_attr; ni.create_system = i.create_system; ni.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(ni, src.read(i.filename))
    z.writestr(text_info("README.txt"), readme.replace("RUNNING\n", mac_note + "RUNNING (WINDOWS)\n", 1))
    hosting = open("HOSTING.txt").read().replace("Windows may ask whether Brelm may use the network. Allow it, on private\n   networks at least.", "macOS may ask whether Brelm may accept incoming network connections.\n   Allow it.")
    z.writestr(text_info("HOSTING.txt"), hosting)
    si = zipfile.ZipInfo("Brelm Server.command", (2026, 10, 31, 12, 0, 0)); si.external_attr = 0o100755 << 16; si.create_system = 3
    z.writestr(si, open("build-mac/Brelm Server.command").read())
    z.writestr(text_info("THIRD-PARTY-NOTICES.txt"), open("THIRD-PARTY-NOTICES.txt").read())
print("ok")
linux_note = """LINUX AND STEAM DECK
  Unzip anywhere and run Brelm.x86_64 (it is already marked as a program).
  If the screen stays black on an older graphics card, run
  "Brelm (compatibility mode).sh" instead.
  Steam Deck: in Desktop Mode, add Brelm.x86_64 to Steam as a non-Steam game,
  then play it from Game Mode. The controller works everywhere.

"""
def exe_info(name):
    zi = text_info(name); zi.external_attr = 0o100755 << 16; return zi
with zipfile.ZipFile(os.path.join(out, "Brelm-Linux.zip"), "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr(exe_info("Brelm.x86_64"), open("build-linux/Brelm.x86_64", "rb").read())
    for lib in sorted(glob.glob("build-linux/*.so")):
        z.writestr(exe_info(os.path.basename(lib)), open(lib, "rb").read())
    z.writestr(exe_info("Brelm Server.sh"), open("build-linux/Brelm Server.sh").read())
    z.writestr(exe_info("Brelm (compatibility mode).sh"), open("build-linux/Brelm (compatibility mode).sh").read())
    z.writestr(text_info("README.txt"), readme.replace("RUNNING\n", linux_note + "RUNNING (WINDOWS)\n", 1))
    hosting = open("HOSTING.txt").read().replace("Windows may ask whether Brelm may use the network. Allow it, on private\n   networks at least.", "If a firewall is on (ufw, firewalld), allow UDP port 24600.")
    z.writestr(text_info("HOSTING.txt"), hosting)
    z.writestr(text_info("THIRD-PARTY-NOTICES.txt"), open("THIRD-PARTY-NOTICES.txt").read())
print("linux ok")
