cask "clipnyx" do
  version "1.1.4"
  sha256 "3dc3d056d65a4bf723d5b4766f41bb0f077d218e2f8f863783fd116b3671315e"

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
