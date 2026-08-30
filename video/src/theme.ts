/** Verso's palette, sampled from the app icon. */
export const V = {
  blush: "#FDD3C9",
  orchid: "#D78FE8",
  violet: "#C36BFA",
  grape: "#9D4DD7",
  ink: "#3E1860",
  midnight: "#240940",
  cream: "#F1EFE8",
} as const;

export const FPS = 30;
export const W = 1920;
export const H = 1080;

/** Recordings include the menu bar and dock; a slight zoom hides both. */
export const CHROME_ZOOM = 1.07;

/**
 * Tempo of the backing track, in beats per minute.
 *
 * Every cut length in `Promo` is expressed in beats rather than seconds, so
 * setting this correctly is the whole of "cut it to the music" -- change the
 * number and every join moves onto the grid. `Scripts/beats.sh` measures it
 * from an audio file rather than leaving it to be guessed.
 */
export const BPM = 138;

/** Seconds per beat, and per bar of four. */
export const BEAT = 60 / BPM;
export const BAR = BEAT * 4;

/** Frames for a number of beats. */
export const beats = (n: number) => Math.round(n * BEAT * FPS);
/** Frames for a number of bars. */
export const bars = (n: number) => beats(n * 4);
