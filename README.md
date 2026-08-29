<p align="center">
  <img src="docs/hero.png" alt="Wavelength" width="100%">
</p>

<h1 align="center">Wavelength</h1>

<p align="center">
  <b>Your desktop becomes the song.</b><br>
  <sub>Word-synced Apple Music lyrics as living typography · 100% Swift + Metal · Free forever</sub>
</p>

<p align="center">
  <a href="https://github.com/AkkiCode06/wavelength/releases/latest"><img src="https://img.shields.io/github/v/release/AkkiCode06/wavelength?style=flat-square&color=007AFF&label=download" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-26+-000?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Apple_silicon-000?style=flat-square" alt="Apple silicon">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0_+_Commons_Clause-blue?style=flat-square" alt="License"></a>
  <a href="https://github.com/AkkiCode06/wavelength/stargazers"><img src="https://img.shields.io/github/stars/AkkiCode06/wavelength?style=flat-square&color=f0c000" alt="Stars"></a>
</p>

<p align="center">
  <a href="https://github.com/AkkiCode06/wavelength/releases/latest"><b>⬇︎ Download</b></a> ·
  <a href="#install"><b>Security warning?</b></a> ·
  <a href="#how-it-works"><b>How it works</b></a> ·
  <a href="#contributing"><b>Contribute</b></a>
</p>

---

## What is Wavelength?

Wavelength turns your **desktop wallpaper** into a live lyric display. It reads
what Apple Music is playing and sets the words across your screen **as they are
sung** — word by word, not line by line — over one of **25 GPU effects**, drawn
in colours pulled from the album cover.

There is no window. It lives in the menu bar and draws straight onto the
desktop, underneath your icons.

Inspired by the [Cotodama Lyric Speaker](https://lyric-speaker.com/) — a speaker
whose entire front face is a display that composes lyrics as they play.

---

## The backgrounds move

Twenty-five effects, every one written in Metal and tinted from the artwork.
Most are **closed-form 3D** — a plane or a sphere solved analytically rather
than a distance field marched step by step, which is what keeps real depth
affordable on an integrated GPU.

<table>
  <tr>
    <td width="50%"><img src="docs/bg-ripple.gif" alt="Ripple"></td>
    <td width="50%"><img src="docs/bg-orbit.gif" alt="Orbit"></td>
  </tr>
  <tr>
    <td align="center"><b>Ripple</b><br><sub>Interfering wave trains, Fresnel water, sun glitter</sub></td>
    <td align="center"><b>Orbit</b><br><sub>Real spheres — ray/sphere intersection, real silhouettes</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/bg-wormhole.gif" alt="Wormhole"></td>
    <td width="50%"><img src="docs/bg-galaxy.gif" alt="Galaxy"></td>
  </tr>
  <tr>
    <td align="center"><b>Wormhole</b><br><sub>Inverse-radial projection, twisting with depth</sub></td>
    <td align="center"><b>Galaxy</b><br><sub>Logarithmic spiral arms seen at a tilt</sub></td>
  </tr>
</table>

<sub>Plus plasma, aurora, nebula, voronoi, silk, marble, kaleidoscope, fractal, waves, helix, mirror, prism, rings, vortex, bubbles, clouds, curtains, ribbons, strata and more.</sub>

---

## Words, not lines

Each word lights **as it is sung**, with a karaoke sweep across the glyphs.
Held notes swell **letter by letter** as the singer leans on them.

Which words are set large comes from **how long each is held**, measured against
that line's own average — so a fast rap verse and a ballad are each judged on
their own terms. Function words never take the weight, however long someone
drags out *"the"*.

### Four compositions

<table>
  <tr>
    <td width="50%"><img src="docs/comp-scattered.png" alt="Scattered"></td>
    <td width="50%"><img src="docs/comp-constellation.png" alt="Constellation"></td>
  </tr>
  <tr>
    <td align="center"><b>Scattered</b><br><sub>Words set loose across the line</sub></td>
    <td align="center"><b>Constellation</b><br><sub>Fragments linked by hairlines, like a star chart</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/comp-echo.png" alt="Echo"></td>
    <td width="50%"><img src="docs/comp-editorial.png" alt="Editorial"></td>
  </tr>
  <tr>
    <td align="center"><b>Echo</b><br><sub>The phrase repeated at many sizes, some mirrored</sub></td>
    <td align="center"><b>Editorial</b><br><sub>Two typefaces in one line, set like a spread</sub></td>
  </tr>
</table>

---

## It matches the music

Left automatic, the **typeface**, **composition** and **background** are all
chosen from the track's own character — genre, lyric cadence, and how saturated
the cover is. Or pin any of them yourself.

- **Apple Music animated covers** on the albums that have them
- **Any Google Font**, downloaded and registered at runtime, with the whole catalogue previewable
- Launch at login, per-composition advanced controls, and power behaviour

---

## Install

**[⬇︎ Download the latest `.dmg`](https://github.com/AkkiCode06/wavelength/releases/latest)** → drag Wavelength onto Applications → **right-click the app and choose Open**.

> [!IMPORTANT]
> ### "Apple could not verify Wavelength is free of malware"
>
> **This is expected, and it is not a statement about this app.**
>
> macOS shows that warning for *every* application not signed with a paid Apple
> Developer certificate — **$99 a year**. Wavelength is free, so it isn't
> signed. The warning means *"Apple has not been paid to vouch for this"*, not
> *"this software is dangerous"*.
>
> Every line of it is readable in this repository, which is rather more than a
> signature would tell you.

**To open it — any one of these:**

| | |
|---|---|
| **Easiest** | In **Applications**, **right-click** (or Control-click) Wavelength → **Open** → **Open**. Once only; it launches normally after that. |
| **No Open option?** | **System Settings → Privacy & Security**, scroll to **Security**, click **"Open Anyway"**. |
| **Terminal** | `xattr -dr com.apple.quarantine /Applications/Wavelength.app` |

On first launch Wavelength asks permission to control Music, so it can read the
track and playback position. **Nothing leaves your Mac** except lyric and
artwork lookups.

---

## How it works

Some of this is more interesting than it needed to be, because macOS closes off
the obvious routes.

<details>
<summary><b>There is no audio to analyse</b></summary>
<br>

A visualiser wants a spectrum. macOS gives no application access to another
app's audio stream, and `MediaRemote` — the private framework that used to
report now-playing state — has been gated behind an entitlement check in
`mediaremoted` since **macOS 15.4**. Both doors are shut.

So Wavelength reads Music through its public AppleScript dictionary, and takes
everything else from the lyric timeline.

</details>

<details>
<summary><b>Tempo, recovered from the words</b></summary>
<br>

Music reports `bpm` as **0** for streamed tracks — verified, not assumed — so
the tag is no help for the case that matters.

But sung words land on or near the beat far more often than not. Take the gaps
between word onsets, take the **median** (held notes and long rests are
outliers, and they move a mean but not a middle), then fold that into 70–170bpm.
The result is a beat period good enough to keep time by.

The point of a *period*, rather than the onsets themselves, is that it keeps
ticking where the lyrics say nothing — through intros, solos and run-outs.

</details>

<details>
<summary><b>Never multiply absolute time by a changing rate</b></summary>
<br>

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
stays continuous.

</details>

<details>
<summary><b>Closed-form 3D instead of raymarching</b></summary>
<br>

The first pass at 3D marched signed-distance fields — up to 90 steps per pixel,
plus six more field evaluations to estimate each surface normal. On an
integrated GPU driving a Retina display, that is the difference between idling
and running the fans.

Most 3D effects now intersect a plane or a sphere in **closed form**: one solve,
and the normal falls out of the algebra rather than costing six extra samples.
Measured on an M-series MacBook against a 39% idle baseline:

| Effect | GPU load over idle |
|---|---|
| Helix *(raymarched)* | **+59** |
| Waves *(raymarched)* | +31 |
| Dunes *(closed-form)* | +14 |
| **Ripple** *(closed-form)* | **+9** |

Same sense of space, a sixth of the cost. Each effect also declares a cost tier,
so battery and Low Power Mode narrow the library to the cheap ones instead of
dropping effects altogether.

</details>

<details>
<summary><b>Matching a track to a look</b></summary>
<br>

Every effect declares where it sits on three axes — **energy**, **density**
(busy effects fight the lyrics) and **organic** (0 = machine-made and geometric,
1 = played by hand). The track is described on the same three.

Energy alone can't tell techno from bluegrass at the same tempo. That's what the
organic axis is for.

The track then picks from the **four best-fitting** effects, seeded by title and
artist so a song always looks like itself. Not the single nearest — sweeping the
plausible mood space showed a handful of effects sit closest to almost every
point real music occupies, leaving **20 of 25 unreachable**. Four brings
coverage to 24 of 25 while every candidate is still a close match.

</details>

---

## Contributing

**Contributions are the whole point of this being open.** Issues, ideas and pull
requests all welcome — especially:

- **New Metal effects** — `Sources/UI/Shaders.metal`. Keep them cheap; see the cost tiers in `ShaderBackgroundView.swift`
- **New compositions** — `Sources/UI/LyricComposition.swift`
- **Lyric providers** — the chain in `Sources/Lyrics/` tries each in order
- **Bugs**, especially anything misbehaving on Intel or older macOS

```bash
brew install xcodegen
git clone https://github.com/AkkiCode06/wavelength.git
cd wavelength
xcodegen generate
open Wavelength.xcodeproj
```

The `.xcodeproj` is generated and deliberately not committed — `project.yml` is
the source of truth. To build a distributable disk image: `./Scripts/release.sh`

Requires **Xcode 26+** and **macOS 26+**.

<details>
<summary><b>Project layout</b></summary>
<br>

```
Sources/
├─ Lyrics/      provider chain, timing model, musical dynamics
├─ NowPlaying/  AppleScript bridge to Music, artwork, motion covers
├─ UI/          lyric typography, compositions, Metal shaders
├─ Settings/    preferences, panes, onboarding, Google Fonts
└─ Desktop/     the wallpaper windows and menu bar panel
```

The interesting files are `UI/Shaders.metal` (25 effects, ~875 lines of Metal),
`UI/ScatteredLyricText.swift` (the typography) and `Lyrics/MusicDynamics.swift`
(tempo recovery).

</details>

---

## Privacy

**No analytics, no telemetry, no tracking.** Network requests are made for
exactly three things:

- **Lyrics** — title, artist, album and duration, to the providers below
- **Album artwork** — the iTunes Search API, only when Music has no local copy
- **Fonts** — Google Fonts, only when you pick one

Track metadata and playback position are read from Music locally, over
AppleScript, and never transmitted.

## Lyrics

Wavelength hosts no lyrics. It queries public providers in order and uses the
first that answers:

1. **[KPoe](https://github.com/Prjkt-La/lyricsplus)** — Apple's own syllable-level timings, the best source
2. **NetEase Cloud Music** — word-level `yrc` timings
3. **[LRCLIB](https://lrclib.net/)** — line-level synced lyrics
4. **LRCLIB plain** — unsynced text as a last resort

**Lyrics are copyrighted works.** These services are free to query, which is not
the same as the words being unlicensed. Wavelength displays them on your own
machine for personal use, the way any lyrics app does, and stores nothing.

## Known limitations

- **Apple Music only** — Spotify has no equivalent public scripting interface
- **Not notarized** — hence the install step above
- **Instrumental tracks** have no lyric timeline to infer tempo from, so the background drifts at a resting pace rather than keeping time
- **macOS 26+, Apple silicon** — earlier versions untested

## Credits

Inspired by the [Cotodama Lyric Speaker](https://lyric-speaker.com/), which sets
its type in Morisawa's **Role** super-family — a commercial licence that cannot
be shipped here, so each role is carried by the closest available face instead:
Avenir Next Condensed, Charter, Rockwell and SF Rounded. Manrope is the default,
fetched from Google Fonts.

Not affiliated with or endorsed by Cotodama or Apple.

## Licence

**[GPL-3.0 with Commons Clause](LICENSE)** © 2026 Akshat Barjatya

Free to use, study, modify and share. **You may not sell it** — the Commons
Clause removes that right specifically. Contributions welcome; profiting off
someone else's work is not.
