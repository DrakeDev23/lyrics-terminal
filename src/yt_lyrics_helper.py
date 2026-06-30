import sys
import time
import textwrap
import re
import os
import subprocess

try:
    import syncedlyrics
except ImportError:
    print("  [!] Install syncedlyrics: pip install --user syncedlyrics")
    sys.exit(1)

RESET   = "\033[0m"
BOLD    = "\033[1m"
CYAN    = "\033[38;5;51m"
YELLOW  = "\033[38;5;226m"
MAGENTA = "\033[38;5;207m"
GREEN   = "\033[38;5;82m"
DIM     = "\033[2m"
WHITE   = "\033[97m"
BLUE    = "\033[38;5;75m"

DEBUG = os.environ.get("YT_LYRICS_DEBUG", "") == "1"

def debug(msg):
    if DEBUG:
        print(f"  {DIM}[debug] {msg}{RESET}")

def clean_title(title):
    """Remove common YouTube noise from titles, with word boundaries so we
    don't accidentally chew into real words (e.g. an artist with 'HD' in it)."""
    original = title

    bracket_noise = [
        r'\(Official.*?\)', r'\[Official.*?\]',
        r'\(Lyrics.*?\)', r'\[Lyrics.*?\]',
        r'\(Audio.*?\)', r'\[Audio.*?\]',
        r'\(Video.*?\)', r'\[Video.*?\]',
        r'\(feat\..*?\)', r'\(ft\..*?\)',
        r'【.*?】',
    ]
    for pattern in bracket_noise:
        title = re.sub(pattern, '', title, flags=re.IGNORECASE)

    title = re.sub(r'｜.*$', '', title)

    if re.search(r'Lyrics\s+by', title, flags=re.IGNORECASE) and ' - ' in title:
        prefix, rest = title.split(' - ', 1)
        if len(prefix.split()) <= 5:
            debug(f"clean_title: dropping leading channel tag '{prefix}'")
            title = rest

  
    m = re.search(r'^(.*?)\s+Lyrics\s+by\s+(.*?)(?:\s+Cover)?$', title, flags=re.IGNORECASE)
    if m:
        song_part, artist_part = m.group(1).strip(), m.group(2).strip()
        title = f"{artist_part} {song_part}"
        debug(f"clean_title: matched 'Lyrics by' pattern -> song='{song_part}' artist='{artist_part}'")

    word_noise = [r'MV', r'M/V', r'HD', r'HQ', r'4K', r'Official', r'Cover', r'Lyrics']
    for word in word_noise:
        title = re.sub(rf'\b{word}\b', '', title, flags=re.IGNORECASE)

    title = re.sub(r'\s{2,}', ' ', title)
    title = re.sub(r'^[\s\-\|]+|[\s\-\|]+$', '', title)
    title = title.strip()

    debug(f"clean_title: '{original}' -> '{title}'")
    return title

def normalize_for_search(title):
    """YouTube titles often come as 'Artist - Song' or 'Song - Artist'.
    syncedlyrics works best with simple 'Song Title Artist' style queries,
    so convert the first hyphen into a space rather than leaving it as '-'."""
    normalized = title.replace(' - ', ' ', 1)
    debug(f"normalize_for_search: '{title}' -> '{normalized}'")
    return normalized

def get_player_position():
    """Ask playerctl for the actual current playback position, in seconds.
    Returns None if playerctl isn't available or nothing is playing, so
    callers can fall back to wall-clock timing."""
    try:
        result = subprocess.run(
            ["playerctl", "position"],
            capture_output=True, text=True, timeout=1
        )
        if result.returncode == 0:
            return float(result.stdout.strip())
    except (FileNotFoundError, subprocess.TimeoutExpired, ValueError):
        pass
    return None

def is_player_playing():
    """Check if playerctl reports the player is actively playing (not paused)."""
    try:
        result = subprocess.run(
            ["playerctl", "status"],
            capture_output=True, text=True, timeout=1
        )
        return result.stdout.strip() == "Playing"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None  


def parse_lrc(lrc_text):
    """Parse LRC format into list of (seconds, line) tuples."""
    lines = []
    pattern = re.compile(r'\[(\d+):(\d+)\.(\d+)\](.*)')
    for raw in lrc_text.split('\n'):
        m = pattern.match(raw.strip())
        if m:
            minutes, seconds, centiseconds, text = m.groups()
            total = int(minutes)*60 + int(seconds) + int(centiseconds)/100
            lines.append((total, text.strip()))
    return sorted(lines, key=lambda x: x[0])

def display_synced(lrc_lines):
    """Display synced lyrics, tracking the ACTUAL playback position via
    playerctl rather than wall-clock time since script start. This means
    the line shown on screen lines up with what's actually playing, even
    if the script started mid-song, or the user pauses/seeks."""
    if not lrc_lines:
        return

    window = 5
    fallback_start = time.time()
    use_playerctl = get_player_position() is not None
    debug(f"display_synced: using {'playerctl position' if use_playerctl else 'wall-clock fallback'}")

    print(f"\n{DIM}  ─── Synced Lyrics ────────────────────────────────────{RESET}\n")

    try:
        while True:
            if use_playerctl:
                pos = get_player_position()
                if pos is None:
                    time.sleep(0.3)
                    continue
                elapsed = pos
            else:
                elapsed = time.time() - fallback_start

            current_idx = 0
            for i, (ts, _) in enumerate(lrc_lines):
                if ts <= elapsed:
                    current_idx = i

            start = max(0, current_idx - 2)
            end = min(len(lrc_lines), current_idx + window)

            print("\033[H\033[J", end="")
            print(f"\n{CYAN}{BOLD}  YT Karaoke  ASCII Terminal Lyrics {RESET}\n")
            print(f"{DIM}  ─────────────────────────────────────────────────{RESET}\n")

            for i in range(start, end):
                ts, line = lrc_lines[i]
                if not line:
                    continue
                if i == current_idx:
                    print(f"  {YELLOW}{BOLD}▶  {line}{RESET}")
                elif i < current_idx:
                    print(f"  {DIM}   {line}{RESET}")
                else:
                    print(f"  {BLUE}   {line}{RESET}")

            print(f"\n{DIM}  ─────────────────────────────────────────────────{RESET}")
            print(f"{DIM}  Press Ctrl+C to stop{RESET}")

            if current_idx >= len(lrc_lines) - 1:
                break

            time.sleep(0.3 if use_playerctl else 0.5)
    except KeyboardInterrupt:
        print(f"\n{DIM}  Stopped.{RESET}")

def display_plain(lyrics_text):
    """Display plain lyrics with ASCII box formatting."""
    print(f"\n{DIM}  ─── Lyrics ───────────────────────────────────────────{RESET}\n")
    width = 58
    border = f"{BLUE}{'─' * width}{RESET}"

    print(f"  {BLUE}╭{border}╮{RESET}")
    for line in lyrics_text.split('\n'):
        if not line.strip():
            print(f"  {BLUE}│{RESET}{' ' * width}  {BLUE}│{RESET}")
            continue
        wrapped = textwrap.wrap(line, width - 2)
        for wl in wrapped:
            print(f"  {BLUE}│{RESET}  {WHITE}{wl:<{width-4}}{RESET}  {BLUE}│{RESET}")
    print(f"  {BLUE}╰{border}╯{RESET}")

def try_search(query):
    """Run syncedlyrics.search and report what came back, for debugging.
    syncedlyrics has changed its search() signature across versions
    (old: allow_plain_format=True, new: plain_only/synced_only kwargs),
    so try the current API first and fall back gracefully."""
    debug(f"Searching syncedlyrics for: '{query}'")
    try:
        try:
            result = syncedlyrics.search(query)
        except TypeError as e:
            debug(f"search() call failed ({e}); retrying with allow_plain_format")
            result = syncedlyrics.search(query, allow_plain_format=True)
    except Exception as e:
        debug(f"syncedlyrics.search raised: {e}")
        return None
    if result is None:
        debug("syncedlyrics.search returned None (no match from any provider)")
    else:
        debug(f"syncedlyrics.search returned {len(result)} chars")
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage: yt_lyrics_helper.py <song title>")
        print("       YT_LYRICS_DEBUG=1 yt_lyrics_helper.py <song title>   (for debug output)")
        sys.exit(1)

    raw_title = " ".join(sys.argv[1:])
    debug(f"Raw title from argv: '{raw_title}'")

    title = clean_title(raw_title)

    print(f"\n{CYAN}  Searching for:{RESET} {BOLD}{title}{RESET}")

    if not title:
        print(f"  {MAGENTA} Title became empty after cleaning  nothing to search for.{RESET}")
        print(f"  {DIM}  Try running with YT_LYRICS_DEBUG=1 to see why.{RESET}")
        return

    try:
        lrc = try_search(title)

        if not lrc and ' - ' in title:
            alt_query = normalize_for_search(title)
            lrc = try_search(alt_query)

        if not lrc:
            debug("Falling back to raw (uncleaned) title")
            lrc = try_search(raw_title)

        if lrc:
            looks_synced = ('[' in lrc and ']:' in lrc) or re.search(r'\[\d+:\d+', lrc)
            if looks_synced:
                parsed = parse_lrc(lrc)
                if parsed:
                    print(f"  {GREEN} Synced lyrics found! Starting karaoke mode...{RESET}")
                    time.sleep(1)
                    display_synced(parsed)
                    return
                else:
                    debug("Looked synced but parse_lrc returned no lines falling back to plain display")
            print(f"  {GREEN}Lyrics found!{RESET}\n")
            display_plain(lrc)
        else:
            print(f"  {MAGENTA}No lyrics found for: {title}{RESET}")
            print(f"  {DIM}  Try searching manually: https://genius.com{RESET}")
            print(f"  {DIM}  Or rerun with YT_LYRICS_DEBUG=1 for details.{RESET}")
    except Exception as e:
        print(f"  {MAGENTA}Error fetching lyrics: {e}{RESET}")
        if DEBUG:
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    main()