#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_HELPER="$SCRIPT_DIR/yt_lyrics_helper.py"

# Set YT_LYRICS_DEBUG=1 to see what window/title detection is doing
DEBUG="${YT_LYRICS_DEBUG:-0}"

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;226m'
MAGENTA='\033[38;5;207m'
GREEN='\033[38;5;82m'
DIM='\033[2m'
BLUE='\033[38;5;75m'

debug() {
  if [[ "$DEBUG" == "1" ]]; then
    echo -e "${DIM}  [debug] $1${RESET}" >&2
  fi
}

HAVE_PLAYERCTL=0

check_dependencies() {
  local missing=()
  command -v python3 >/dev/null 2>&1 || missing+=("python3")

  if command -v playerctl >/dev/null 2>&1; then
    HAVE_PLAYERCTL=1
  else
    missing+=("playerctl")
  fi

  # xdotool/wmctrl are now just a fallback for X11, not required
  if ! command -v xdotool >/dev/null 2>&1 && ! command -v wmctrl >/dev/null 2>&1; then
    debug "Neither xdotool nor wmctrl found — window-title fallback unavailable"
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${MAGENTA}  ✗ Missing required tools: ${missing[*]}${RESET}"
    echo -e "${DIM}    Install with: sudo apt install ${missing[*]}${RESET}"
    echo ""
  fi

  if [[ "$HAVE_PLAYERCTL" == "0" ]]; then
    echo -e "${MAGENTA}  ⚠ playerctl not found — this is the recommended detection${RESET}"
    echo -e "${MAGENTA}    method, especially on Wayland. Falling back to window-title${RESET}"
    echo -e "${MAGENTA}    detection, which does NOT work on Wayland sessions.${RESET}"
    echo ""
  fi
}

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

get_youtube_title_playerctl() {
  # MPRIS works over D-Bus, independent of X11/Wayland. Most browsers (Chrome,
  # Brave, Firefox, Edge) register a media player session when audio/video is
  # playing on a page — including YouTube.
  local status
  status=$(playerctl status 2>/dev/null)
  debug "playerctl status: '$status'"

  if [[ "$status" != "Playing" ]]; then
    return
  fi

  local player_title player_artist
  player_title=$(playerctl metadata title 2>/dev/null)
  player_artist=$(playerctl metadata artist 2>/dev/null)
  debug "playerctl metadata: title='$player_title' artist='$player_artist'"

  if [[ -z "$player_title" ]]; then
    return
  fi

  # If the title already looks like "Artist - Song" (common for "Lyrics" /
  # "Audio" upload videos), don't prepend the channel-name artist field too —
  # that just produces "ChannelName - Artist - Song" garbage.
  if [[ "$player_title" == *" - "* ]]; then
    debug "Title already contains ' - ', using as-is (ignoring artist field '$player_artist')"
    echo "$player_title"
  elif [[ -n "$player_artist" ]]; then
    echo "${player_artist} - ${player_title}"
  else
    echo "$player_title"
  fi
}

get_youtube_title_x11() {
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
      debug "xdotool matched browser '$browser' window: '$found'"
      title=$(echo "$found" | \
        sed "s/ - ${pattern}//" | \
        sed 's/ - YouTube//' | \
        sed 's/ | YouTube//' | \
        sed 's/YouTube - //')
      break
    fi
  done

  if [[ -z "$title" ]]; then
    debug "xdotool found nothing, falling back to wmctrl"
    local wm_match
    wm_match=$(wmctrl -l 2>/dev/null | grep -i "youtube" | head -1)
    debug "wmctrl raw match: '$wm_match'"
    title=$(echo "$wm_match" | \
      awk '{$1=$2=$3=""; print $0}' | \
      sed 's/^ *//' | \
      sed 's/ - YouTube//' | \
      sed 's/ | YouTube//' | \
      sed 's/YouTube - //')
  fi

  echo "$title"
}

get_youtube_title() {
  local title=""

  if [[ "$HAVE_PLAYERCTL" == "1" ]]; then
    title=$(get_youtube_title_playerctl)
  fi

  if [[ -z "$title" ]] && (command -v xdotool >/dev/null 2>&1 || command -v wmctrl >/dev/null 2>&1); then
    title=$(get_youtube_title_x11)
  fi

  if [[ -z "$title" ]]; then
    debug "No YouTube title found via playerctl or window-title detection"
  else
    debug "Resolved title: '$title'"
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
  YT_LYRICS_DEBUG="$DEBUG" python3 "$PYTHON_HELPER" "$song_title"
}

main() {
  show_banner
  check_dependencies

  local session_type="${XDG_SESSION_TYPE:-unknown}"
  echo -e "${DIM}  Session: ${session_type} | Watching all browsers for YouTube...${RESET}"
  echo -e "${DIM}  (Ctrl+C to quit)${RESET}"
  if [[ "$DEBUG" == "1" ]]; then
    echo -e "${DIM}  Debug mode: ON${RESET}"
  fi
  echo ""

  if [[ "$session_type" == "wayland" && "$HAVE_PLAYERCTL" == "0" ]]; then
    echo -e "${MAGENTA}  ⚠ Wayland session detected without playerctl — xdotool/wmctrl${RESET}"
    echo -e "${MAGENTA}    can't see window titles under Wayland, so detection will${RESET}"
    echo -e "${MAGENTA}    likely never work. Install playerctl: sudo apt install playerctl${RESET}"
    echo ""
  elif [[ "$session_type" == "wayland" ]]; then
    echo -e "${DIM}  Wayland session — using playerctl (MPRIS) for detection.${RESET}"
    echo ""
  fi

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