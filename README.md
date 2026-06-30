# YT Lyrics

Real-time, word-synced lyrics in your terminal for whatever's currently
playing on YouTube in your browser. Detects playback via `playerctl`
(MPRIS over D-Bus), which works on both X11 and Wayland.

## Quick start (recommended — run on your host)

```bash
git clone <this-repo>
cd yt-lyrics
./setup.sh      
./run.sh        
```

That's it — no env vars, no flags. Play a song on YouTube and the lyrics
will appear automatically.

Need verbose output for troubleshooting? `./run.sh --debug`

## Project structure