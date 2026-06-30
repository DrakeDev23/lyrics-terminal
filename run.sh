
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$1" == "--debug" || "$1" == "-d" ]]; then
  export YT_LYRICS_DEBUG=1
fi

exec "$SCRIPT_DIR/src/yt_karaoke.sh"