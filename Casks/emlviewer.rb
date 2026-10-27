cask "zenaeml-viewer" do
  version "1.1.0"
  sha256 :no_check

  url "https://github.com/campodoro74/ZenaEML-Viewer/releases/download/v#{version}/EMLViewer.app.zip"
  name "ZenaEML Viewer"
  desc "ZenaConsult .eml / .msg viewer with Finder Quick Look"
  homepage "https://github.com/campodoro74/ZenaEML-Viewer"

  depends_on macos: ">= :sonoma"

  app "EMLViewer.app"

  zap trash: [
    "~/Library/Preferences/it.zenaconsult.ZenaEMLViewer.plist",
    "~/Library/Application Support/EMLViewer",
    "~/Library/Caches/it.zenaconsult.ZenaEMLViewer",
    "~/Library/Saved Application State/it.zenaconsult.ZenaEMLViewer.savedState",
  ]
end
