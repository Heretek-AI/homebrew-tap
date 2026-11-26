cask "hatchlight" do
  arch arm: "aarch64", intel: "x64"

  version "0.7.0"
  sha256 arm:   "e9290fb536fc25c6edd73774763ecf13847d3582bfa3639a452d175246b763ac",
         intel: "3df356eb11acc0ebe9071efe54e8f89dea48ee1ca53cfff62af1de1d50bbd270"

  url "https://github.com/hatchlight/hatchlight/releases/download/v#{version}/Hatchlight_#{version}_#{arch}.dmg"
  name "Hatchlight"
  desc "Compare AI image and video generation models side by side"
  homepage "https://github.com/hatchlight/hatchlight"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on :macos

  app "Hatchlight.app"

  zap trash: [
    "~/Library/Application Support/app.hatchlight.desktop",
    "~/Library/Caches/app.hatchlight.desktop",
    "~/Library/Preferences/app.hatchlight.desktop.plist",
    "~/Library/Saved Application State/app.hatchlight.desktop.savedState",
    "~/Library/WebKit/app.hatchlight.desktop",
  ]
end
