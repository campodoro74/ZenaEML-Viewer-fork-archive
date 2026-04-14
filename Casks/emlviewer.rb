cask "emlviewer" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/noma4i/emlviewer/releases/download/v#{version}/EMLViewer.app.zip"
  name "EMLViewer"
  desc "Minimalist .eml viewer for macOS"
  homepage "https://github.com/noma4i/emlviewer"

  depends_on macos: ">= :ventura"

  app "EMLViewer.app"

  zap trash: [
    "~/Library/Preferences/com.noma4i.EMLViewer.plist",
    "~/Library/Application Support/EMLViewer",
    "~/Library/Caches/com.noma4i.EMLViewer",
    "~/Library/Saved Application State/com.noma4i.EMLViewer.savedState",
  ]
end
