cask "peekmark" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/yourusername/PeekMark/releases/download/v#{version}/PeekMark-#{version}.zip",
      verified: "github.com/yourusername/PeekMark/"
  name "PeekMark"
  desc "Quick Look extension and viewer for Markdown files on macOS"
  homepage "https://github.com/yourusername/PeekMark"

  license MIT

  depends_on macos: ">= :sequoia"

  app "PeekMark.app"

  zap trash: [
    "~/Library/Application Support/com.peekmark.PeekMark",
    "~/Library/Preferences/com.peekmark.PeekMark.plist",
  ]
end