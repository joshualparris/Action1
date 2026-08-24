#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Installing Python 3..."
  sudo dnf install -y python3
fi

if ! python3 - <<'PY' >/dev/null 2>&1
import tkinter
PY
then
  echo "Installing Tk support for Python..."
  sudo dnf install -y python3-tkinter
fi

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"

cat > "$HOME/.local/bin/dadlan" <<EOF
#!/usr/bin/env bash
exec python3 "$SCRIPT_DIR/dadlan.py" "\$@"
EOF
chmod +x "$HOME/.local/bin/dadlan"

cat > "$HOME/.local/share/applications/dadlan.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=DadLAN Command Centre
Comment=Read-only Action1 fleet dashboard
Exec=$HOME/.local/bin/dadlan
Terminal=false
Categories=System;Network;
EOF

echo "DadLAN installed for this user."
echo "Run: $HOME/.local/bin/dadlan"
echo "Or launch 'DadLAN Command Centre' from the Fedora app menu."
