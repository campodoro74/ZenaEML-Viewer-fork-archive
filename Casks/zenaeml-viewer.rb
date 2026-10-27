cask "zenaeml-viewer" do
  version "1.1.0"
  sha256 "93520c04e2177f6f495fa86037d7ad0ebe6eceecf06387508e9d08f7130e8468"

  url "https://github.com/campodoro74/ZenaEML-Viewer/releases/download/v#{version}/ZenaEML-Viewer.dmg"
  name "ZenaEML Viewer"
  desc "ZenaConsult viewer for .eml and .msg files with Finder Quick Look"
  homepage "https://github.com/campodoro74/ZenaEML-Viewer"

  depends_on macos: ">= :sonoma"

  app "ZenaEML Viewer.app"

  zap trash: [
    "~/Library/Preferences/it.zenaconsult.ZenaEMLViewer.plist",
    "~/Library/Caches/it.zenaconsult.ZenaEMLViewer",
    "~/Library/Saved Application State/it.zenaconsult.ZenaEMLViewer.savedState",
  ]
end
