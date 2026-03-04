cask "clipnyx" do
  version "1.1.0"
  sha256 "242689842d9bd87bc05bc55c1190ebbc9f41c9fcd23cba514af1f8e9d610f7fa"

  url "https://github.com/sawasige/clipboard-mac/releases/download/v#{version}/Clipnyx.dmg"
  name "Clipnyx"
  desc "Clipboard history manager for macOS menu bar"
  homepage "https://github.com/sawasige/clipboard-mac"

  depends_on macos: ">= :sequoia"

  app "Clipnyx.app"

  zap trash: [
    "~/Library/Application Support/Clipnyx",
    "~/Library/Preferences/com.himatsubu.Clipnyx.plist",
  ]
end
