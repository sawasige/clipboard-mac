cask "clipnyx" do
  version "1.1.2"
  sha256 "95ac9645e5994de4d78c65937aec250e02318e6b78373b0c2502a06fc0ab673f"

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
