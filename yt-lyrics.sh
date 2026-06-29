
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
  echo "  ██╗  ██╗████████╗    ██╗  ██╗ █████╗ ██╗██╗  ██╗███████╗"
  echo "  ╚██╗██╔╝╚══██╔══╝    ██║ ██╔╝██╔══██╗██║██║ ██╔╝██╔════╝"
  echo "   ╚███╔╝    ██║       █████╔╝ ███████║██║█████╔╝ ███████╗ "
  echo "   ██╔██╗    ██║       ██╔═██╗ ██╔══██║██║██╔═██╗ ╚════██║ "
  echo "  ██╔╝ ██╗   ██║       ██║  ██╗██║  ██║██║██║  ██╗███████║ "
  echo "  ╚═╝  ╚═╝   ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝"
  echo -e "${RESET}"
  echo -e "${DIM}  ♪ Real-time lyrics from YouTube — ASCII Terminal Edition ♪${RESET}"
  echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"
  echo ""
}

get_youtube_title() {
  local title=""

  title=$(xdotool search --name "Mozilla Firefox" getwindowname 2>/dev/null | \
    grep -i "youtube" | head -1 | sed 's/ - Mozilla Firefox//' | sed 's/ - YouTube//')

  if [[ -z "$title" ]]; then
    title=$(xdotool search --name "Chromium" getwindowname 2>/dev/null | \
      grep -i "youtube" | head -1 | sed 's/ - Chromium//' | sed 's/ - YouTube//')
  fi

  if [[ -z "$title" ]]; then
    title=$(xdotool search --name "Google Chrome" getwindowname 2>/dev/null | \
      grep -i "youtube" | head -1 | sed 's/ - Google Chrome//' | sed 's/ - YouTube//')
  fi

  echo "$title"
}

draw_box() {
  local text="$1"
  local width=60
  local border="${BLUE}$(printf '─%.0s' $(seq 1 $width))${RESET}"
  echo -e "${BLUE}╭${border}╮${RESET}"
  echo "$text" | while IFS= read -r line; do
    echo "$line" | fold -s -w $((width - 2)) | while IFS= read -r wrapped; do
      printf "${BLUE}│${RESET} %-*s ${BLUE}│${RESET}\n" $((width - 2)) "$wrapped"
    done
  done
  echo -e "${BLUE}╰${border}╯${RESET}"
}

fetch_and_display_lyrics() {
  local song_title="$1"
  echo -e "${YELLOW}${BOLD}  ♪ Now Searching:${RESET} ${GREEN}${song_title}${RESET}"
  echo ""

  python3 "$PYTHON_HELPER" "$song_title"
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

main() {
  show_banner

  local last_title=""

  echo -e "${DIM}  Watching for YouTube music... (Ctrl+C to quit)${RESET}"
  echo ""

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