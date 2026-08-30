import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { V } from "./theme";

/**
 * A drifting violet field, drawn rather than filmed.
 *
 * The hook lines used dimmed footage behind them, which meant the shot's own
 * lyrics were still faintly legible under the question being asked -- two
 * pieces of text competing before the viewer has been told what any of it is.
 * This gives the opening a ground of its own.
 *
 * Blobs move on incommensurable periods so the field never visibly loops,
 * which matters when it is on screen for seven seconds at the very start.
 */
export const GlowField: React.FC<{ seed?: number }> = ({ seed = 0 }) => {
  const frame = useCurrentFrame();
  const t = frame / 30;

  const blobs = [
    { hue: V.violet, x: 26, y: 34, rx: 44, ry: 40, sx: 0.061, sy: 0.043, a: 0.62 },
    { hue: V.grape,  x: 74, y: 62, rx: 50, ry: 44, sx: 0.047, sy: 0.037, a: 0.55 },
    { hue: V.orchid, x: 58, y: 22, rx: 34, ry: 30, sx: 0.079, sy: 0.055, a: 0.34 },
    { hue: V.ink,    x: 34, y: 76, rx: 46, ry: 42, sx: 0.035, sy: 0.067, a: 0.58 },
  ];

  return (
    <AbsoluteFill style={{ backgroundColor: "#0B0316", overflow: "hidden" }}>
      {blobs.map((b, i) => {
        const x = b.x + Math.sin(t * b.sx * 6.283 + seed + i * 1.7) * 13;
        const y = b.y + Math.cos(t * b.sy * 6.283 + seed + i * 2.3) * 10;
        // A slow breath, so the field is never quite still.
        const swell = 1 + Math.sin(t * 0.21 + i * 1.1) * 0.09;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: `${x - b.rx * swell}%`,
              top: `${y - b.ry * swell}%`,
              width: `${b.rx * 2 * swell}%`,
              height: `${b.ry * 2 * swell}%`,
              borderRadius: "50%",
              background: `radial-gradient(closest-side, ${b.hue} 0%, ${b.hue}00 72%)`,
              opacity: b.a,
              filter: "blur(52px)",
            }}
          />
        );
      })}

      {/* Pulls the corners down so the type sits in the calmest part. */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 50%, rgba(0,0,0,0) 34%, rgba(6,1,12,.72) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};
