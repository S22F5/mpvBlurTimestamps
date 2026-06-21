# mpvBlurTimestamps

### Usage (Linux/Windows WSL)
1. move playLinux.sh into the same folder as your video.
2. create a .blurs file in the same folder (example provided).
3. use the script on the video to blur.

### Command Line Options
- -v: videofile
- -b: blurfile
- -f: ignore errors

### .blurs Format
- Line 1: **Info** about file.
- Line 2: **Playtime** in seconds e.g. 5623.720s.
- Line 3: **Resolution** in format WidthxHeight e.g. 1920x1080.
- Line 4-X: **Blurs** in HH:MM:SS.MS HH:MM:SS.MS BlurWidth BlurHeight BlurOffsetX BlurOffsetY (when no width, height, offsets provided blur is fullscreen).
