/**
 * Desktop "webview" GUI: starts the embedded server on localhost and opens the
 * web GUI in a chromeless browser window (Chromium/Chrome/Edge "--app" mode),
 * falling back to the system browser. No GUI toolkit dependency is required.
 */
module uim.myfiori.presentation.gui;

@safe:

import std.process : environment, spawnProcess, Config, ProcessException;
import vibe.core.log;

/// Candidate webview launchers in order of preference.
string[][] webviewCommands(string url) {
  string[][] cmds;
  auto custom = environment.get("GDPR_WEBVIEW", null);   // e.g. "/usr/bin/surf"
  if (custom.length) cmds ~= [custom, url];
  foreach (browser; ["chromium", "chromium-browser", "google-chrome", "google-chrome-stable", "microsoft-edge", "brave-browser"])
    cmds ~= [browser, "--app=" ~ url, "--new-window", "--window-size=1400,900"];
  version (OSX) cmds ~= ["open", url];
  else version (Windows) cmds ~= ["cmd", "/c", "start", "", url];
  else cmds ~= ["xdg-open", url];
  return cmds;
}

/// Opens the URL in the first available webview; returns false if none could be started.
bool openWebView(string url) @trusted {
  foreach (cmd; webviewCommands(url)) {
    try {
      spawnProcess(cmd, null, Config.detached | Config.suppressConsole);
      logInfo("Opened GUI with %s", cmd[0]);
      return true;
    } catch (ProcessException) {
      continue;
    }
  }
  logWarn("No webview/browser found. Open %s manually.", url);
  return false;
}
