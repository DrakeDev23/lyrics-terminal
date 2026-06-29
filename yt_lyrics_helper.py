
import sys
import time
import textwrap
import re

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

def clean_title(title):
    """Remove common YouTube noise from titles."""
    noise = [
        r'\(Official.*?\)', r'\[Official.*?\]',
        r'\(Lyrics.*?\)', r'\[Lyrics.*?\]',
        r'\(Audio.*?\)', r'\[Audio.*?\]',
        r'\(Video.*?\)', r'\[Video.*?\]',
        r'\(feat\..*?\)', r'\(ft\..*?\)',
        r'【.*?】', r'｜.*$',
        r'MV', r'M/V', r'HD', r'HQ',
        r'4K', r'Official',
    ]
    for pattern in noise:
        title = re.sub(pattern, '', title, flags=re.IGNORECASE)
    return title.strip()

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
    """Display synced lyrics scrolling with timing."""
    if not lrc_lines:
        return

    start_time = time.time()
    displayed = set()
    window = 5  

    print(f"\n{DIM}  ─── Synced Lyrics ────────────────────────────────────{RESET}\n")

    try:
        while True:
            elapsed = time.time() - start_time
            current_idx = 0

            for i, (ts, _) in enumerate(lrc_lines):
                if ts <= elapsed:
                    current_idx = i

            start = max(0, current_idx - 2)
            end = min(len(lrc_lines), current_idx + window)

            print("\033[H\033[J", end="")  
            print(f"\n{CYAN}{BOLD}  ♪ YT-Karaoke — ASCII Terminal Lyrics ♪{RESET}\n")
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

            time.sleep(0.5)
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

def main():
    if len(sys.argv) < 2:
        print("Usage: yt_lyrics_helper.py <song title>")
        sys.exit(1)

    raw_title = " ".join(sys.argv[1:])
    title = clean_title(raw_title)

    print(f"\n{CYAN}  Searching for:{RESET} {BOLD}{title}{RESET}")

    try:
        lrc = syncedlyrics.search(title, allow_plain_format=True)
        if lrc:
            if '[' in lrc and ']:' in lrc or re.search(r'\[\d+:\d+', lrc):
                parsed = parse_lrc(lrc)
                if parsed:
                    print(f"  {GREEN}✓ Synced lyrics found! Starting karaoke mode...{RESET}")
                    time.sleep(1)
                    display_synced(parsed)
                    return
            print(f"  {GREEN}✓ Lyrics found!{RESET}\n")
            display_plain(lrc)
        else:
            print(f"  {MAGENTA}✗ No lyrics found for: {title}{RESET}")
            print(f"  {DIM}  Try searching manually: https://genius.com{RESET}")
    except Exception as e:
        print(f"  {MAGENTA}✗ Error fetching lyrics: {e}{RESET}")

if __name__ == "__main__":
    main()