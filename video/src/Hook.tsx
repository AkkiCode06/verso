import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { V } from "./theme";
import { GlowField } from "./GlowField";

/**
 * A hook line, set large over dimmed footage.
 *
 * The opening question has to land before anyone has decided to keep
 * watching, so it is the loudest thing on screen: the footage is pushed well
 * back and the type carries the frame.
 */
export const Hook: React.FC<{
  durationInFrames: number;
  line: string;
  /** Word to lift out of the line, the way the app lifts a held lyric. */
  accent?: string;
  /** Offsets the field, so two consecutive hooks do not look identical. */
  seed?: number;
}> = ({ durationInFrames, line, accent, seed = 0 }) => {
  const frame = useCurrentFrame();

  const fade = Math.min(
    interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" }),
    interpolate(frame, [durationInFrames - 9, durationInFrames], [1, 0], {
      extrapolateLeft: "clamp",
    })
  );
  const rise = interpolate(frame, [2, 16], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const words = line.split(" ");

  return (
    <AbsoluteFill style={{ opacity: fade, backgroundColor: "#000" }}>
      <GlowField seed={seed} />

      <AbsoluteFill
        style={{ justifyContent: "center", alignItems: "center", padding: "0 180px" }}
      >
        <div
          style={{
            opacity: rise,
            transform: `translateY(${interpolate(rise, [0, 1], [22, 0])}px)`,
            textAlign: "center",
            fontFamily: "'Avenir Next', -apple-system, sans-serif",
            fontWeight: 700,
            fontSize: 78,
            lineHeight: 1.14,
            letterSpacing: -1.4,
            color: V.cream,
          }}
        >
          {words.map((w, i) => {
            const bare = w.replace(/[?.,!]/g, "");
            const lit = accent && bare.toLowerCase() === accent.toLowerCase();
            return (
              <span key={i} style={{ color: lit ? V.violet : V.cream }}>
                {w}
                {i < words.length - 1 ? " " : ""}
              </span>
            );
          })}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** The "introducing" beat: one word, then the mark. */
export const Introducing: React.FC<{ durationInFrames: number }> = ({ durationInFrames }) => {
  const frame = useCurrentFrame();
  const fade = interpolate(frame, [durationInFrames - 17, durationInFrames - 7], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const word = interpolate(frame, [0, 10], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ opacity: fade, backgroundColor: "#0A0210" }}>
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <div
          style={{
            opacity: word,
            letterSpacing: interpolate(word, [0, 1], [22, 9]),
            fontFamily: "'Avenir Next', -apple-system, sans-serif",
            fontWeight: 600,
            fontSize: 42,
            textTransform: "uppercase",
            color: V.orchid,
          }}
        >
          Introducing
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
