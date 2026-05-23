# Unwatermark

Native macOS SwiftUI app that wraps the open-source [remove-ai-watermarks](https://github.com/wiltodelta/remove-ai-watermarks) Python CLI to strip AI watermarks (Gemini sparkle, SynthID, metadata) from images via drag-and-drop.

## Stack

- **Swift 6.2 / SwiftUI** with `@Observable` + `@MainActor` (no Combine, no `@StateObject`)
- **macOS only**, Apple Silicon first-class
- **Xcode project:** `Unwatermark.xcodeproj` — open with `open Unwatermark.xcodeproj`
- **Build:** `xcodebuild -project Unwatermark.xcodeproj -scheme Unwatermark build`
- **App Sandbox and Hardened Runtime are DISABLED** — the app needs to spawn arbitrary CLI tools (`uv`, `pipx`, `remove-ai-watermarks`) and read user-selected image paths. Do not re-enable them without rethinking the install flow.

## Architecture

Phase-based routing driven by `AppState.phase` (`.probing` → `.needsSetup` / `.ready`):

```
UnwatermarkApp ──► RootView ──┬─► ProbingView      (looking for CLI)
                              ├─► SetupView        (install wizard: uv | pipx)
                              └─► MainView ──► DropZoneView + ProcessingListView
```

### Files (`Unwatermark/`)

| File | Role |
|------|------|
| `UnwatermarkApp.swift` | `@main` scene, injects `AppState` via `.environment` |
| `AppState.swift` | Observable root state: `phase`, `cliPath`, `mode`, `jobs`, `hasWarnedAllMode`. Persists CLI path / mode / warning flag to `UserDefaults` |
| `RootView.swift` | Switches on `app.phase`. Calls `app.probe()` on first appear |
| `MainView.swift` | Header + segmented mode picker + drop zone + job list. Owns the `AllModeWarningSheet` (one-time confirmation before enabling `.all`) |
| `SetupView.swift` | Install wizard. Bootstraps `uv` (or `pipx`), then `uv tool install remove-ai-watermarks`. Streams stdout into a log pane |
| `DropZoneView.swift` | Animated drag-and-drop target, accepts image URLs |
| `ProcessingListView.swift` | Scrolling list of `ImageJob` rows with thumbnails, status badges, reveal-in-Finder |
| `ImageJob.swift` | Observable per-image record: `source`, `output`, `status` (`.queued / .processing / .done / .failed(String)`), timestamps |
| `WatermarkService.swift` | Serial job queue. Builds CLI args, runs `CLIRunner`, mutates `ImageJob` |
| `CLIRunner.swift` | `Process` wrapper. Streams merged stdout+stderr as `AsyncThrowingStream<String, Error>`. `run(...)` collects to completion |
| `CLIProbe.swift` | Locates `remove-ai-watermarks` in `~/.local/bin`, `~/.local/share/uv/tools/.../bin`, `/opt/homebrew/bin`, etc. Exports `augmentedPATH` for child processes. Detects Apple Silicon |
| `Theme.swift` | Gradient + easing design tokens (`Theme.accentGradient`, `Theme.smoothEase`) |

### Processing modes (`ProcessingMode` in `WatermarkService.swift`)

| Mode | CLI subcommand | Notes |
|------|----------------|-------|
| `.visible` | `remove-ai-watermarks visible <in> -o <out>` | Fast, CPU-only. Strips Gemini sparkle + metadata. **No `--device` flag** |
| `.all` | `remove-ai-watermarks all <in> -o <out> [--device mps]` | Diffusion-backed (visible + invisible + metadata). First run downloads a ~2 GB model. `--device mps` is appended only on Apple Silicon |

**Gotcha:** `--device` only exists on diffusion subcommands (`all`, `invisible`). Passing it to `visible` makes the CLI error out. Keep the `if chosenMode == .all` guard in `WatermarkService.process(...)`.

### Output naming

`uniqueOutputURL(for:)` writes `<stem>-unwatermarked.<ext>` next to the source. On collision, appends ` 2`, ` 3`, … before the extension. `WatermarkService.outputSuffix` is the shared constant.

### Child-process environment

`CLIRunner` injects `PATH = CLIProbe.augmentedPATH` and `HOME` into every spawned process. GUI-launched macOS apps inherit a minimal PATH, so this is required for `uv tool install` to find `python`, and for installed entry points to find their venv shim.

## Conventions

- **State:** `@Observable` classes injected via `.environment(...)`. Read with `@Environment(AppState.self)`. Mutate inside `@MainActor`-isolated methods.
- **Async:** Use `async` / `AsyncThrowingStream`. No `DispatchQueue`. No `Combine`.
- **Persistence:** `UserDefaults` for tiny flags only (CLI path, last mode, warning ack). No CoreData / SwiftData.
- **No external Swift packages.** Pure Foundation + SwiftUI + AppKit (for `NSImage` thumbnails).
- **Animations:** Use `Theme.smoothEase` for state transitions; gradient accent via `Theme.accentGradient`.

## Common tasks

- **Add a new processing mode:** extend `ProcessingMode` enum, set `cliSubcommand` / `displayName` / `summary`, decide whether `--device` applies, update the `MainView` picker copy.
- **Change CLI search paths:** edit `CLIProbe.searchPaths`. Remember to add the same path to `augmentedPATH` (it already concatenates `searchPaths`).
- **Tweak setup wizard:** `SetupView.swift` holds `SetupModel` (phases: idle → installingBootstrap → installingTool → verifying → done/failed). Logs cap at 400 lines.

---

# context-mode — MANDATORY routing rules

You have context-mode MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any Bash command containing `curl` or `wget` is intercepted and replaced with an error message. Do NOT retry.
Instead use:
- `ctx_fetch_and_index(url, source)` to fetch and index web pages
- `ctx_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any Bash command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` is intercepted and replaced with an error message. Do NOT retry with Bash.
Instead use:
- `ctx_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

### WebFetch — BLOCKED
WebFetch calls are denied entirely. The URL is extracted and you are told to use `ctx_fetch_and_index` instead.
Instead use:
- `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` to query the indexed content

## REDIRECTED tools — use sandbox equivalents

### Bash (>20 lines output)
Bash is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `ctx_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `ctx_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### Read (for analysis)
If you are reading a file to **Edit** it → Read is correct (Edit needs content in context).
If you are reading to **analyze, explore, or summarize** → use `ctx_execute_file(path, language, code)` instead. Only your printed summary enters context. The raw file content stays in the sandbox.

### Grep (large results)
Grep results can flood context. Use `ctx_execute(language: "shell", code: "grep ...")` to run searches in sandbox. Only your printed summary enters context.

## Tool selection hierarchy

1. **GATHER**: `ctx_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results. ONE call replaces 30+ individual calls.
2. **FOLLOW-UP**: `ctx_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `ctx_execute(language, code)` | `ctx_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `ctx_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Subagent routing

When spawning subagents (Agent/Task tool), the routing block is automatically injected into their prompt. Bash-type subagents are upgraded to general-purpose so they have access to MCP tools. You do NOT need to manually instruct subagents about context-mode.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `ctx_search(source: "label")` later.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call the `ctx_stats` MCP tool and display the full output verbatim |
| `ctx doctor` | Call the `ctx_doctor` MCP tool, run the returned shell command, display as checklist |
| `ctx upgrade` | Call the `ctx_upgrade` MCP tool, run the returned shell command, display as checklist |
