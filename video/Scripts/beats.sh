#!/bin/bash
#
# Measures the tempo of an audio file, so the cut can be set to it rather than
# guessed. Prints the BPM to paste into src/theme.ts, and the bar length in
# seconds so the edit's shape can be sanity-checked against the track.
#
set -euo pipefail
AUDIO="${1:?usage: beats.sh <audio file>}"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO")
echo "==> $(basename "$AUDIO")  ${DUR}s"

# Onset strength over time, then autocorrelation: the lag with the strongest
# correlation is the beat period. Crude next to a real beat tracker, but it
# only has to land within a bpm or two for cuts to sit on the grid.
ffmpeg -v error -i "$AUDIO" -ac 1 -ar 22050 -f f32le - 2>/dev/null | python3 -c '
import sys, numpy as np
x = np.frombuffer(sys.stdin.buffer.read(), dtype=np.float32)
sr, hop = 22050, 256
frames = len(x) // hop
env = np.array([np.abs(x[i*hop:(i+1)*hop]).mean() for i in range(frames)])
env = np.maximum(np.diff(env, prepend=env[0]), 0)      # onset strength
env -= env.mean()

fps_env = sr / hop
best = (0, 0)
for bpm in np.arange(70, 181, 0.25):
    lag = int(round(60 / bpm * fps_env))
    if lag < 2 or lag >= len(env) // 2: continue
    c = float(np.dot(env[:-lag], env[lag:]) / (len(env) - lag))
    if c > best[1]: best = (bpm, c)

bpm = best[0]
print(f"    BPM  {bpm:.2f}")
print(f"    beat {60/bpm:.3f}s   bar {4*60/bpm:.3f}s")
print()
print("    Paste into src/theme.ts:")
print(f"        export const BPM = {bpm:.2f};")
'
