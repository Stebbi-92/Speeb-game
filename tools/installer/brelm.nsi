; The Windows installer for Brelm: The Hermit of Nine Visions.
; Build:  makensis -DVERSION=0.3.0 -DSRC=build -DOUT=dist/Brelm-Setup.exe tools/installer/brelm.nsi
; Installs for the current user only (no administrator prompt), into a folder the game can write
; to, with Start menu and desktop shortcuts and an entry in Settings > Apps for uninstalling.
; Saves live in %APPDATA%\Godot\app_userdata and are kept on uninstall unless the player asks.

Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel user

!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!ifndef SRC
  !define SRC "build"
!endif
!ifndef OUT
  !define OUT "Brelm-Setup.exe"
!endif
!define NAME "Brelm"
!define FULLNAME "Brelm: The Hermit of Nine Visions"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Brelm"
!define SAVES "$APPDATA\Godot\app_userdata\Brelm- The Hermit of Nine Visions"

!include "MUI2.nsh"
!include "FileFunc.nsh"

Name "${FULLNAME}"
OutFile "${OUT}"
InstallDir "$LOCALAPPDATA\Programs\Brelm"
InstallDirRegKey HKCU "Software\Brelm" "InstallDir"
BrandingText "Brelm alpha ${VERSION}"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${FULLNAME}"
VIAddVersionKey "FileDescription" "${FULLNAME} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}-alpha"
VIAddVersionKey "LegalCopyright" "Speeb"

!define MUI_ICON "brelm.ico"
!define MUI_UNICON "brelm.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Brelm: The Hermit of Nine Visions"
!define MUI_WELCOMEPAGE_TEXT "This will install Brelm alpha ${VERSION}.$\r$\n$\r$\nThe game keeps itself current: when a new version is out, the title screen offers it.$\r$\n$\r$\nClose Brelm before going on."
!define MUI_FINISHPAGE_RUN "$INSTDIR\Brelm.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Begin the pilgrimage"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_COMPONENTS
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Brelm (required)" SecGame
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "${SRC}\Brelm.exe"
  File "${SRC}\Brelm (compatibility mode).bat"
  File "${SRC}\Brelm Server.bat"
  File "..\..\README.txt"
  File "..\..\HOSTING.txt"
  File "..\..\THIRD-PARTY-NOTICES.txt"
  File "brelm.ico"
  WriteUninstaller "$INSTDIR\Uninstall Brelm.exe"

  CreateDirectory "$SMPROGRAMS\Brelm"
  CreateShortcut "$SMPROGRAMS\Brelm\Brelm.lnk" "$INSTDIR\Brelm.exe" "" "$INSTDIR\brelm.ico"
  CreateShortcut "$SMPROGRAMS\Brelm\Brelm (compatibility mode).lnk" "$INSTDIR\Brelm (compatibility mode).bat" "" "$INSTDIR\brelm.ico"
  CreateShortcut "$SMPROGRAMS\Brelm\Brelm Server.lnk" "$INSTDIR\Brelm Server.bat" "" "$INSTDIR\brelm.ico"
  CreateShortcut "$SMPROGRAMS\Brelm\Uninstall Brelm.lnk" "$INSTDIR\Uninstall Brelm.exe"

  WriteRegStr HKCU "Software\Brelm" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${FULLNAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}-alpha"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "Speeb"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\brelm.ico"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall Brelm.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout" "https://github.com/Stebbi-92/Speeb-game"
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"

  ; A fresh install supersedes any update the game fetched for itself
  Delete "${SAVES}\update\Brelm.pck"
  Delete "${SAVES}\update\version.txt"
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\Brelm.lnk" "$INSTDIR\Brelm.exe" "" "$INSTDIR\brelm.ico"
SectionEnd

Section "un.Brelm" SecUnGame
  SectionIn RO
  Delete "$INSTDIR\Brelm.exe"
  Delete "$INSTDIR\Brelm (compatibility mode).bat"
  Delete "$INSTDIR\Brelm Server.bat"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\HOSTING.txt"
  Delete "$INSTDIR\THIRD-PARTY-NOTICES.txt"
  Delete "$INSTDIR\brelm.ico"
  Delete "$INSTDIR\Uninstall Brelm.exe"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\Brelm.lnk"
  RMDir /r "$SMPROGRAMS\Brelm"
  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\Brelm"
  RMDir /r "${SAVES}\update"
SectionEnd

Section /o "un.Also forget my worlds, characters and progress" SecSaves
  RMDir /r "${SAVES}"
SectionEnd
