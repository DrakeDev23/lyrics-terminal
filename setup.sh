
set -e

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;5;51m'
GREEN='\033[38;5;82m'
MAGENTA='\033[38;5;207m'
DIM='\033[2m'

echo -e "${CYAN}${BOLD}  YT Lyrics — Setup${RESET}"
echo -e "${DIM}  ─────────────────────────────────${RESET}"
echo ""

if command -v playerctl >/dev/null 2>&1; then
  echo -e "${GREEN}  ✓ playerctl already installed${RESET}"
else
  echo -e "  Installing playerctl..."
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm playerctl
  elif command -v apt >/dev/null 2>&1; then
    sudo apt install -y playerctl
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y playerctl
  elif command -v brew >/dev/null 2>&1; then
    brew install playerctl
  else
    echo -e "${MAGENTA}  ✗ Couldn't detect your package manager.${RESET}"
    echo -e "${MAGENTA}    Please install 'playerctl' manually, then re-run this script.${RESET}"
    exit 1
  fi
fi

echo ""
echo -e "  Installing Python dependencies..."
PIP_FLAGS="--user"
if pip install --help 2>&1 | grep -q "break-system-packages"; then
  PIP_FLAGS="$PIP_FLAGS --break-system-packages"
fi
pip install $PIP_FLAGS -r "$(dirname "${BASH_SOURCE[0]}")/requirements.txt"

echo ""
echo -e "${GREEN}  ✓ Setup complete!${RESET}"
echo -e "  Run it with: ${BOLD}./run.sh${RESET}"