<div align="center">

# Wavelength

**Your desktop becomes the song.**

Live, word-synced lyrics set as typography across your wallpaper, over GPU
backgrounds drawn from the album's own colours — in time with Apple Music.

[![Download](https://img.shields.io/badge/Download-Wavelength%200.1.0-1c1c1e?style=for-the-badge)](../../releases/latest)
&nbsp;
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-1c1c1e?style=for-the-badge)
&nbsp;
![Apple silicon](https://img.shields.io/badge/Apple%20silicon-1c1c1e?style=for-the-badge)

</div>

---

Wavelength is a desktop wallpaper that reads what Apple Music is playing and
sets the lyrics across your screen as they are sung — word by word, not line by
line. Behind them, one of 25 GPU effects runs in colours pulled from the album
cover, matched to the character of the track.

It is inspired by the [Cotodama Lyric
Speaker](https://lyric-speaker.com/) — a speaker whose entire front face is a
display that composes the lyrics as they play.

There is no window. It runs in the menu bar and draws directly onto the
desktop, underneath your icons.

## Install

1. **[Download the latest `.dmg`](../../releases/latest)**
2. Drag **Wavelength** onto **Applications**
3. **Right-click the app and choose Open** — not a double-click. See below.

### The security warning, and why it appears

The first time you open Wavelength, macOS will refuse:

> *"Apple could not verify Wavelength is free of malware that may harm your Mac
> or compromise your privacy."*

**This is expected, and it is not a statement about this app.** macOS shows it
for *every* application that has not been signed with a paid Apple Developer
certificate — currently **$99 a year**. Wavelength is free, so it isn't signed.
The warning means "Apple has not been paid to vouch for this", not "this
software is dangerous".

You can read every line of what you're running in this repository, which is
rather more than a signature would tell you.

**To open it:**

<table>
<tr><td><b>Easiest</b></td><td>

In **Applications**, **right-click** (or Control-click) Wavelength → **Open** →
**Open** in the dialog.

You only do this once. After that it launches normally.

</td></tr>
<tr><td><b>If there's no Open option</b></td><td>

**System Settings → Privacy & Security**, scroll down to **Security**, and click
**"Open Anyway"** next to the message about Wavelength.

</td></tr>
<tr><td><b>Terminal</b></td><td>

```bash
xattr -dr com.apple.quarantine /Applications/Wavelength.app
```

This strips the quarantine flag macOS attaches to downloaded files. Only run
this on software you've decided to trust.

</td></tr>
</table>

On first launch Wavelength asks permission to control Music. It needs this to
read the current track and playback position. **Nothing leaves your Mac** except
lyric lookups (see [Privacy](#privacy)).

## What it does

**Word-synced lyrics.** Not line-at-a-time. Each word lights as it is sung, with
a karaoke sweep across the glyphs, and held notes swell letter by letter as the
singer leans on them.

**Emphasis from the singing, not from a hash.** Which words are set large is
decided by how long each is *held*, measured against the line's own average — so
a fast rap verse and a ballad are each judged on their own terms. Function words
never take the weight, however long someone leans on *"the"*.

**Four compositions.** How a line is arranged on screen:

| | |
|---|---|
| **Scattered** | Words set loose across the line |
| **Constellation** | Fragments linked by hairlines, like a star chart |
| **Echo** | The phrase repeated at many sizes, some mirrored |
| **Editorial** | Two typefaces in one line, set like a magazine spread |

**25 GPU backgrounds**, tinted from the album artwork — plasma, aurora, nebula,
voronoi, silk, marble, and closed-form 3D pieces like ripple, orbit, wormhole,
vortex and galaxy.

**It matches the music.** Left automatic, the typeface, composition and
background are all chosen from the track's character. See
[below](#matching-a-track-to-a-look) for how.

**Apple Music animated covers**, on the albums that have them — the app steps
out of the way and shows the artwork instead.

**Any Google Font**, downloaded and registered at runtime, with a scrollable
preview of the whole catalogue.

## How it works

Some of this is more interesting than it needed to be, because macOS closes off
the obvious routes.

### There is no audio to analyse

A visualiser wants a spectrum. macOS gives no application access to another
app's audio stream, and `MediaRemote` — the private framework that used to
report now-playing state — has been gated behind an entitlement check in
`mediaremoted` since **macOS 15.4**. Both doors are shut.

So Wavelength reads Music through its public AppleScript dictionary, and takes
everything else from the lyric timeline.

### Tempo, recovered from the words

Music reports `bpm` as **0** for streamed tracks — verified, not assumed — so
the tag is no help for the case that matters.

But sung words land on or near the beat far more often than not. Take the gaps
between word onsets, take the **median** (held notes and long rests are
outliers, and they move a mean but not a middle), then fold that into 70–170bpm.
The result is a beat period good enough to keep time by.

The point of a *period*, rather than the onsets themselves, is that it keeps
ticking where the lyrics say nothing — through intros, solos, breakdowns and
run-outs.

### Never multiply absolute time by a changing rate

The clock behind every effect integrates:

```swift
phase += dt * rate
```

The obvious alternative, `t * rate`, looks fine until the rate moves.
`timeIntervalSinceReferenceDate` is around **7.9 × 10⁸**, so nudging the
multiplier by a few percent shifts the result by *millions of seconds* and the
pattern teleports to an unrelated point in its cycle. Speeding the visuals up on
a beat read as the animation resetting.

Integrating makes rate a true velocity: changing it alters speed while position
stays continuous. The rate is then eased toward its target over ~2 seconds,
because continuous is not the same as gradual — a beat can take the envelope
from 0 to 1 between two frames.

### Closed-form 3D instead of raymarching

The first pass at 3D marched signed-distance fields — up to 90 steps per pixel,
plus six more field evaluations to estimate each surface normal. On an
integrated GPU driving a Retina display, that is the difference between idling
and running the fans.

Most of the 3D effects now intersect a plane or a sphere in **closed form**: one
solve, and the normal falls out of the algebra rather than costing six extra
samples. Measured on an M-series MacBook against a 39% idle baseline:

| Effect | GPU load over idle |
|---|---|
| Helix *(raymarched)* | **+59** |
| Waves *(raymarched)* | +31 |
| Grid, Dunes *(closed-form)* | +14 |
| **Ripple** *(closed-form)* | **+9** |

Same sense of space, a sixth of the cost.

Each effect also declares a cost tier, so battery and Low Power Mode can narrow
the library to the cheap ones instead of dropping effects altogether.

### Matching a track to a look

Every effect declares where it sits on three axes — **energy**, **density**
(busy effects fight the lyrics) and **organic** (0 = machine-made and geometric,
1 = played by hand). The track is described on the same three, from genre, lyric
cadence and how saturated the cover is.

Energy alone can't tell techno from bluegrass at the same tempo. That's what the
organic axis is for.

The track then picks from the **four best-fitting** effects, seeded by title and
artist so a song always looks like itself. Not the single nearest — sweeping the
plausible mood space showed that a handful of effects sit closest to almost
every point real music occupies, and taking only the winner left **20 of 25
effects unreachable**. Four brings coverage to 24 of 25 while every candidate is
still a close match.

## Settings

In the menu bar → **Settings**. Five panes: **Typeface**, **Composition**,
**Background**, **Behaviour**, and per-composition **Advanced** controls.

The Composition pane previews live — not a mock-up, but the same view the
wallpaper uses, playing a sample line, so what you see is what you get.

**Behaviour** covers launch at login, what to do when a track has no lyrics, and
how much to ease off the GPU on battery or in Low Power Mode.

## Privacy

Wavelength sends **no analytics, no telemetry, and no personal data** anywhere.

It makes network requests for exactly three things:

- **Lyrics** — song title, artist, album and duration, to the providers below
- **Album artwork** — the iTunes Search API, only when Music has no local copy
- **Fonts** — Google Fonts, only when you pick one

Track metadata and playback position are read from Music locally, over
AppleScript, and never transmitted.

## Lyrics

Wavelength does not host lyrics. It queries public providers in order and uses
the first that answers:

1. **[KPoe](https://github.com/Prjkt-La/lyricsplus)** — Apple's own syllable-level timings, the best source
2. **NetEase Cloud Music** — word-level `yrc` timings
3. **[LRCLIB](https://lrclib.net/)** — line-level synced lyrics
4. **LRCLIB plain** — unsynced text as a last resort

**Lyrics are copyrighted works.** These services are free to query, which is not
the same as the words being unlicensed. Wavelength displays them on your own
machine for personal use, the way any lyrics app does, and stores nothing. If
you plan to build on this, that distinction is worth understanding properly.

## Build from source

```bash
brew install xcodegen
git clone https://github.com/AkkiCode06/wavelength.git
cd wavelength
xcodegen generate
open Wavelength.xcodeproj
```

The `.xcodeproj` is generated and deliberately not committed — `project.yml` is
the source of truth.

To produce a distributable disk image:

```bash
./Scripts/release.sh
```

Requires **Xcode 26+** and **macOS 26+**.

### Layout

```
Sources/
├─ Lyrics/      provider chain, timing model, musical dynamics
├─ NowPlaying/  AppleScript bridge to Music, artwork, motion covers
├─ UI/          lyric typography, compositions, Metal shaders
├─ Settings/    preferences, panes, onboarding, Google Fonts
└─ Desktop/     the wallpaper windows and menu bar panel
```

The interesting files are `Sources/UI/Shaders.metal` (25 effects, ~875 lines of
Metal), `Sources/UI/ScatteredLyricText.swift` (the typography) and
`Sources/Lyrics/MusicDynamics.swift` (tempo recovery).

## Known limitations

- **Apple Music only.** Spotify has no equivalent public scripting interface.
- **Not notarized.** Hence the install dance above.
- **Instrumental tracks** have no lyric timeline to infer tempo from, so the
  background drifts at a resting pace rather than keeping time.
- **macOS 26+**, Apple silicon. Earlier versions are untested.

## Credits

Inspired by the [Cotodama Lyric Speaker](https://lyric-speaker.com/). The Lyric
Speaker sets its type in Morisawa's **Role** super-family, which is a commercial
licence and cannot be shipped here — each role is carried by the closest
available face instead: Avenir Next Condensed, Charter, Rockwell and SF Rounded.
Manrope is the default, fetched from Google Fonts.

Wavelength is not affiliated with or endorsed by Cotodama or Apple.

## Licence

**[GPL-3.0 with Commons Clause](LICENSE)** © 2026 Akshat Barjatya

Free to use, study, modify and share. **You may not sell it** — the Commons
Clause removes that right specifically. Contributions are welcome; profiting
off someone else's work is not.
