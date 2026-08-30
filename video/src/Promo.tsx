import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { Shot } from "./Shot";
import { Hook, Introducing } from "./Hook";
import { TitleCard, EndCard } from "./Cards";
import { bars, beats } from "./theme";

/** Source clips, named for what is actually on screen in each. */
const MOTION = "2026-08-30_08-45-36.mov";   // animated cover + constellation
const SILK = "2026-08-30_08-47-01.mov";     // silk backdrop; Settings open 11-24s
const BOKEH = "2026-08-30_10-22-12.mov";    // orbs; menu bar panel 8-12s
const EMBER = "2026-08-30_10-22-53.mov";    // warm orbs, echo composition

/**
 * The cut, measured in bars rather than seconds.
 *
 * Two bars is the working unit: long enough to read a line, short enough that
 * nothing outstays its welcome, and it puts every join on a downbeat. Set
 * `BPM` in theme.ts and the whole edit re-times onto the track.
 */
const BEATS: { len: number; el: (n: number) => React.ReactNode }[] = [
  // --- the hook: a problem, a turn, a name -------------------------------
  {
    len: bars(2),
    el: (n) => (
      <Hook durationInFrames={n} seed={0}
        line="Bored of the same Apple Music lyric screen?" accent="Bored" />
    ),
  },
  {
    len: bars(2),
    el: (n) => (
      <Hook durationInFrames={n} seed={2.4}
        line="What if your whole desktop was the lyric screen?" accent="whole" />
    ),
  },
  { len: bars(1), el: (n) => <Introducing durationInFrames={n} /> },
  { len: bars(2), el: (n) => <TitleCard durationInFrames={n} /> },

  // --- what it does ------------------------------------------------------
  {
    len: bars(2),
    el: (n) => (
      <Shot src={MOTION} from={6} durationInFrames={n}
        caption="Your desktop becomes the song" align="bottom" />
    ),
  },
  {
    len: bars(2),
    el: (n) => (
      <Shot src={SILK} from={2} durationInFrames={n}
        caption="Every word, in time" sub="Word by word, not line by line" align="bottom" />
    ),
  },
  {
    len: bars(2),
    el: (n) => (
      <Shot src={EMBER} from={4} durationInFrames={n}
        caption="Four typographic compositions"
        sub="Scattered · Constellation · Echo · Editorial" align="top" />
    ),
  },
  {
    len: bars(2),
    el: (n) => (
      <Shot src={BOKEH} from={2} durationInFrames={n}
        caption="25 GPU effects" sub="In colours pulled from the album art" align="top" />
    ),
  },
  {
    len: bars(2),
    el: (n) => (
      <Shot src={MOTION} from={26} durationInFrames={n}
        caption="Apple Music animated covers"
        sub="When an album has one, it takes the whole screen" align="bottom" />
    ),
  },
  {
    // Settings is open between 11s and 24s in this clip.
    len: bars(2),
    el: (n) => (
      <Shot src={SILK} from={19} durationInFrames={n}
        caption="Or pin exactly what you want" align="bottom" />
    ),
  },
  {
    // The menu bar panel is up between 8s and 12s here.
    len: bars(2),
    el: (n) => (
      <Shot src={BOKEH} from={8.4} durationInFrames={n}
        caption="Lives in the menu bar" sub="No window. The desktop is the window." align="top" />
    ),
  },

  { len: bars(3), el: () => <EndCard /> },
];

/**
 * Shots overlap by half a beat, and the overlap is added to the *end* of each
 * shot rather than subtracted from the next one's start.
 *
 * Subtracting it -- the obvious way to write this -- moves every shot earlier
 * than its slot and the error accumulates, so by the last cut nothing is on a
 * downbeat any more. Each shot now starts exactly on the grid and simply runs
 * half a beat past it, which is what the dissolve happens across.
 */
const OVERLAP = beats(0.5);

let cursor = 0;
const PLACED = BEATS.map((b) => {
  const from = cursor;
  cursor += b.len;
  return { from, len: b.len + OVERLAP, el: b.el(b.len + OVERLAP) };
});

export const PROMO_FRAMES = cursor;

export const Promo: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: "#000" }}>
    {PLACED.map((b, i) => (
      <Sequence key={i} from={b.from} durationInFrames={b.len}>
        {b.el}
      </Sequence>
    ))}
  </AbsoluteFill>
);
