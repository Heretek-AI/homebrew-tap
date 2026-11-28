cask "kokon" do
  version "0.13.0"
  sha256 "a3b8dc70591bdefea63d3e4a46cf5db222bdf4d404b3550e400499df0c5315e7"

  url "https://github.com/GabrieleLozupone/kokon/releases/download/v#{version}/Kokon_#{version}_aarch64.dmg"
  name "Kokon"
  desc "Local AI photo editor that runs on your own GPU"
  homepage "https://github.com/GabrieleLozupone/kokon"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Kokon.app"

  zap trash: [
    "~/Library/Application Support/app.kokon.desktop",
    "~/Library/Caches/app.kokon.desktop",
    "~/Library/Preferences/app.kokon.desktop.plist",
    "~/Library/Saved Application State/app.kokon.desktop.savedState",
    "~/Library/WebKit/app.kokon.desktop",
  ]
end
