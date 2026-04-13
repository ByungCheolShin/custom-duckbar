cask "duckbar" do
  version "0.4.5"
  sha256 "c8f2dea7b5965dbc4e926c897eef644f751e3bd98385a957f03b918f28551c45"

  url "https://github.com/rofeels/duckbar/releases/download/v#{version}/DuckBar-#{version}.zip"
  name "DuckBar"
  desc "macOS menu bar app for monitoring Claude Code sessions"
  homepage "https://github.com/rofeels/duckbar"

  depends_on macos: ">= :sonoma"

  app "DuckBar.app"

  zap trash: [
    "~/Library/Preferences/com.munbbok.duckbar.plist",
  ]
end
