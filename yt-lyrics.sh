

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_HELPER="$SCRIPT_DIR/yt_lyrics_helper.py"

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;226m'
MAGENTA='\033[38;5;207m'
GREEN='\033[38;5;82m'
DIM='\033[2m'
BLUE='\033[38;5;75m'

show_banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "  ██████╗ ██████╗  █████╗ ██╗  ██╗ ██████╗ ███╗   ██╗"
  echo "  ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔═══██╗████╗  ██║"
  echo "  ██║  ██║██████╔╝███████║█████╔╝ ██║   ██║██╔██╗ ██║"
  echo "  ██║  ██║██╔══██╗██╔══██║██╔═██╗ ██║   ██║██║╚██╗██║"
  echo "  ██████╔╝██║  ██║██║  ██║██║  ██╗╚██████╔╝██║ ╚████║"
  echo "  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
  echo -e "${RESET}"
  echo -e "${DIM}  ♪ Real-time lyrics from YouTube — ASCII Terminal Edition ♪${RESET}"
  echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"
  echo ""
}

get_youtube_title() {
  local title=""

  declare -A browsers=(
    ["Brave"]="Brave"
    ["Firefox"]="Mozilla Firefox"
    ["Chromium"]="Chromium"
    ["Chrome"]="Google Chrome"
    ["Edge"]="Microsoft Edge"
    ["Opera"]="Opera"
    ["Vivaldi"]="Vivaldi"
    ["Zen"]="Zen Browser"
    ["Waterfox"]="Waterfox"
    ["LibreWolf"]="LibreWolf"
  )

  for browser in "${!browsers[@]}"; do
    local pattern="${browsers[$browser]}"
    local found
    found=$(xdotool search --name "$pattern" getwindowname 2>/dev/null | \
      grep -i "youtube" | head -1)

    if [[ -n "$found" ]]; then
      title=$(echo "$found" | \
        sed "s/ - ${pattern}//" | \
        sed 's/ - YouTube//' | \
        sed 's/ | YouTube//' | \
        sed 's/YouTube - //')
      break
    fi
  done

  if [[ -z "$title" ]]; then
    title=$(wmctrl -l 2>/dev/null | grep -i "youtube" | head -1 | \
      awk '{$1=$2=$3=""; print $0}' | \
      sed 's/^ *//' | \
      sed 's/ - YouTube//' | \
      sed 's/ | YouTube//' | \
      sed 's/YouTube - //')
  fi

  echo "$title"
}

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  while kill -0 "$pid" 2>/dev/null; do
    for i in $(seq 0 9); do
      printf "\r${CYAN}  ${spinstr:$i:1} Fetching lyrics...${RESET}"
      sleep $delay
    done
  done
  printf "\r%-30s\r" " "
}

fetch_and_display_lyrics() {
  local song_title="$1"
  echo -e "${YELLOW}${BOLD}  ♪ Now Searching:${RESET} ${GREEN}${song_title}${RESET}"
  echo ""
  python3 "$PYTHON_HELPER" "$song_title"
}

main() {
  show_banner

  local session_type="${XDG_SESSION_TYPE:-unknown}"
  echo -e "${DIM}  Session: ${session_type} | Watching all browsers for YouTube...${RESET}"
  echo -e "${DIM}  (Ctrl+C to quit)${RESET}"
  echo ""

  local last_title=""

  while true; do
    local current_title
    current_title=$(get_youtube_title)

    if [[ -n "$current_title" && "$current_title" != "$last_title" ]]; then
      last_title="$current_title"
      show_banner
      echo -e "${MAGENTA}  ┌─ DETECTED ────────────────────────────────────────────┐${RESET}"
      echo -e "${MAGENTA}  │${RESET}  ${BOLD}${current_title}${RESET}"
      echo -e "${MAGENTA}  └───────────────────────────────────────────────────────┘${RESET}"
      echo ""
      fetch_and_display_lyrics "$current_title" &
      local fetch_pid=$!
      spinner $fetch_pid
      wait $fetch_pid
    elif [[ -z "$current_title" ]]; then
      printf "\r${DIM}  ♪ No YouTube music detected... waiting${RESET}   "
    fi

    sleep 5
  done
}

main