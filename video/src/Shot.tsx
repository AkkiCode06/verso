import React from "react";
import { AbsoluteFill, OffthreadVideo, staticFile, interpolate, useCurrentFrame } from "remotion";
import { V, FPS, CHROME_ZOOM } from "./theme";

/**
 * One clip, trimmed and captioned.
 *
 * The recordings are of a whole desktop, so they carry the menu bar and dock.
 * A small scale-up pushes both outside the frame -- cropping instead would
 * change the aspect and letterbox the result.
 */
export const Shot: React.FC<{
  src: string;
  /** Seconds into the source clip to begin at. */
  from: number;
  durationInFrames: number;
  caption?: string;
  sub?: string;
  /** Where the caption sits, so it never lands on the lyric it is describing. */
  align?: "top" | "bottom";
}> = ({ src, from, durationInFrames, caption, sub, align = "bottom" }) => {
  const frame = useCurrentFrame();

  // Cross-fade at both ends; every cut in this piece is a dissolve, which
  // suits footage this slow far better than a hard cut.
  const fade = Math.min(
    interpolate(frame, [0, 12], [0, 1], { extrapolateRight: "clamp" }),
    interpolate(frame, [durationInFrames - 12, durationInFrames], [1, 0], {
      extrapolateLeft: "clamp",
    })
  );

  // A slow push in, so a held shot never feels frozen.
  const zoom = CHROME_ZOOM + interpolate(frame, [0, durationInFrames], [0, 0.05]);

  const capIn = interpolate(frame, [8, 26], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const capOut = interpolate(frame, [durationInFrames - 16, durationInFrames - 4], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const capLift = interpolate(capIn, [0, 1], [16, 0]);

  return (
    <AbsoluteFill style={{ opacity: fade, backgroundColor: "#000" }}>
      <AbsoluteFill style={{ transform: `scale(${zoom})` }}>
        <OffthreadVideo
          src={staticFile(src)}
          startFrom={Math.round(from * FPS)}
          muted
          style={{ width: "100%", height: "100%", objectFit: "cover" }}
        />
      </AbsoluteFill>

      {caption && (
        <>
          <AbsoluteFill
            style={{
              opacity: Math.min(capIn, capOut) * 0.85,
              background:
                align === "bottom"
                  ? "linear-gradient(to top, rgba(9,2,17,.9) 0%, rgba(9,2,17,.5) 15%, rgba(9,2,17,0) 32%)"
                  : "linear-gradient(to bottom, rgba(9,2,17,.9) 0%, rgba(9,2,17,.5) 15%, rgba(9,2,17,0) 32%)",
            }}
          />
        <AbsoluteFill
          style={{
            justifyContent: align === "bottom" ? "flex-end" : "flex-start",
            alignItems: "center",
            padding: align === "bottom" ? "0 0 92px" : "92px 0 0",
          }}
        >
          <div
            style={{
              opacity: Math.min(capIn, capOut),
              transform: `translateY(${capLift}px)`,
              textAlign: "center",
            }}
          >
            <div
              style={{
                fontFamily: "'Avenir Next', -apple-system, sans-serif",
                fontWeight: 700,
                fontSize: 54,
                letterSpacing: -0.5,
                color: V.cream,
                textShadow: "0 4px 40px rgba(0,0,0,.75)",
              }}
            >
              {caption}
            </div>
            {sub && (
              <div
                style={{
                  marginTop: 12,
                  fontFamily: "'Avenir Next', -apple-system, sans-serif",
                  fontWeight: 500,
                  fontSize: 27,
                  color: V.orchid,
                  textShadow: "0 3px 26px rgba(0,0,0,.8)",
                }}
              >
                {sub}
              </div>
            )}
          </div>
        </AbsoluteFill>
        </>
      )}
    </AbsoluteFill>
  );
};
