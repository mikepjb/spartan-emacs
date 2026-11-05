#!/usr/bin/env bash
#
# Creates a desktop launcher for envs like GNOME in Arch Linux.

cat > "$HOME/.local/share/applications/emacs.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Emacs
Comment=Edit text with GNU Emacs
Exec="$HOME/.local/bin/emacs" %F
TryExec=$HOME/.local/bin/emacs
Icon=emacs
Terminal=false
Categories=Development;TextEditor;
MimeType=text/plain;
StartupWMClass=Emacs
EOF

