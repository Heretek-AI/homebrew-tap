# AMD RDNA3 (gfx1100/gfx1101/gfx1102) on Linux.
# Usage: brew bundle --file=Brewfiles/rdna3.Brewfile

tap "heretek-ai/tap", trusted: { formulae: [
  "hipfire",
  "nib",
  "project-maya",
  "rocm-runtime",
  "rocmfpx",
  "stable-diffusion-cpp",
  "strata",
  "zinc",
] }

brew "rocm-runtime"

brew "hipfire", args: ["with-gfx1100"]
brew "nib"
brew "project-maya"
brew "rocmfpx"
brew "stable-diffusion-cpp", args: ["with-rocm"]
brew "strata"
brew "zinc"
