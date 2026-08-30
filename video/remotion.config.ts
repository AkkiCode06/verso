import { Config } from "@remotion/cli/config";

Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);
// Remotion normally downloads its own Chrome Headless Shell. Pointed at the
// installed Chrome instead, so a render does not depend on that fetch.
Config.setBrowserExecutable(
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
);
