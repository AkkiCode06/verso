import { Composition } from "remotion";
import { Promo, PROMO_FRAMES } from "./Promo";
import { FPS, W, H } from "./theme";

export const RemotionRoot: React.FC = () => (
  <Composition
    id="Promo"
    component={Promo}
    durationInFrames={PROMO_FRAMES}
    fps={FPS}
    width={W}
    height={H}
  />
);
