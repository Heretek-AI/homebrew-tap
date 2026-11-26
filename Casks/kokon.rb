cask "kokon" do
  version "0.12.1"
  sha256 "6fdff646145e53301e76aada296172cd2cdaf114719e980b07b090e6be769d3b"

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
