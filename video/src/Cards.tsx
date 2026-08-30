import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { V } from "./theme";

/** The icon's gradient, used as the ground for both cards. */
const Ground: React.FC = () => (
  <AbsoluteFill
    style={{
      background: `linear-gradient(165deg, ${V.blush} 0%, ${V.orchid} 24%, ${V.violet} 46%, ${V.grape} 66%, ${V.ink} 86%, ${V.midnight} 100%)`,
    }}
  />
);

/** The flower from the wordmark's "o", drawn rather than imported. */
const Flower: React.FC<{ size: number; color: string }> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 100 100" style={{ display: "block" }}>
    {[0, 60, 120, 180, 240, 300].map((deg) => (
      <ellipse
        key={deg}
        cx="50" cy="27" rx="15" ry="26" fill={color}
        transform={`rotate(${deg} 50 50)`}
      />
    ))}
  </svg>
);

const Wordmark: React.FC<{ scale?: number }> = ({ scale = 1 }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 4 * scale }}>
    <span
      style={{
        fontFamily: "'Avenir Next', -apple-system, sans-serif",
        fontWeight: 800,
        fontSize: 128 * scale,
        letterSpacing: -3 * scale,
        color: V.cream,
        lineHeight: 1,
      }}
    >
      vers
    </span>
    <Flower size={92 * scale} color={V.cream} />
  </div>
);

/** Opening card. */
export const TitleCard: React.FC<{ durationInFrames: number }> = ({ durationInFrames }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const rise = spring({ frame, fps, config: { damping: 200, mass: 0.7 } });
  // Cleared quickly, and finished a little before the card's own end.
  //
  // A slow fade here overlapped the incoming shot while that shot was also
  // fading its own caption up, so the wordmark and a lyric were dissolving
  // through each other -- which reads as debris on screen rather than as a
  // transition. The card is gone before anything else becomes legible.
  const out = interpolate(frame, [durationInFrames - 17, durationInFrames - 7], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const subIn = interpolate(frame, [14, 34], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ opacity: out }}>
      <Ground />
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <div
          style={{
            transform: `translateY(${interpolate(rise, [0, 1], [26, 0])}px)`,
            opacity: rise,
          }}
        >
          <Wordmark />
        </div>
        <div
          style={{
            marginTop: 26,
            transform: `translateY(${interpolate(subIn, [0, 1], [12, 0])}px)`,
            fontFamily: "'Avenir Next', -apple-system, sans-serif",
            fontWeight: 500,
            fontSize: 34,
            color: V.cream,
            opacity: subIn * 0.86,
          }}
        >
          Live lyrics for your macOS desktop
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** Closing card. */
export const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const rise = spring({ frame, fps, config: { damping: 200, mass: 0.7 } });

  const line = (delay: number) =>
    interpolate(frame, [delay, delay + 20], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });

  return (
    <AbsoluteFill>
      <Ground />
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <div style={{ opacity: rise, transform: `scale(${interpolate(rise, [0, 1], [0.94, 1])})` }}>
          <Wordmark scale={0.82} />
        </div>

        <div
          style={{
            marginTop: 30,
            opacity: line(16),
            fontFamily: "'Avenir Next', -apple-system, sans-serif",
            fontWeight: 600,
            fontSize: 31,
            color: V.cream,
            letterSpacing: 0.4,
          }}
        >
          Free · Open source · macOS 14+
        </div>

        <div
          style={{
            marginTop: 46,
            opacity: line(30),
            fontFamily: "'SF Mono', ui-monospace, monospace",
            fontWeight: 500,
            fontSize: 28,
            color: V.midnight,
            background: "rgba(255,255,255,.82)",
            padding: "13px 26px",
            borderRadius: 10,
          }}
        >
          github.com/AkkiCode06/verso
        </div>

        <div
          style={{
            marginTop: 34,
            opacity: line(42) * 0.6,
            fontFamily: "'Avenir Next', -apple-system, sans-serif",
            fontSize: 21,
            color: V.cream,
            textAlign: "center",
            lineHeight: 1.55,
          }}
        >
          Apple Music · Inspired by the Cotodama Lyric Speaker
          <br />
          {/* The beat is a free type beat: the producers ask for credit in
              return for the licence, so it goes on screen, not in a caption
              that a repost would drop. */}
          Music: “RINGTONE” — prod. Klein &amp; Tybdrums
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
