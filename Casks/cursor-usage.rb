cask "cursor-usage" do
  version "3.1.6"
  sha256 "ebeb8bf5688e225e3f0b5df889e1d6aa575eb00fc511e7874cdfe5176e000906"

  url "https://github.com/r-eiras/cursor-usage/releases/download/v#{version}/CursorUsage-#{version}-macOS-arm64.zip"
  name "Cursor Usage"
  desc "Menu-bar app for spending, history and remaining allowance in Cursor"
  homepage "https://github.com/r-eiras/cursor-usage"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Cursor Usage.app"

  caveats <<~EOS
    Cursor Usage is ad hoc signed and not notarized.
    macOS may require an explicit user decision on first launch.
    Connect your Cursor account after opening the app from Applications.
  EOS
end
