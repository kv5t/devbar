# Changelog

All notable changes to DevBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-12

### Added

- **Port detection** — Auto-detect dev servers via `lsof` port scanning
  - Column-format lsof parsing with batch CWD/start-time resolution
  - Filters system ports (< 1024) and ephemeral ports (>= 49152)
  - Deduplication by port number
  - Process name, git root, and file-based project detection
- **Cloudflare tunnels** — One-click tunnel creation via `cloudflared`
  - Automatic binary detection (bundled, PATH, Homebrew)
  - SHA-256 checksum verification for bundled binaries
  - Live URL capture from cloudflared stdout/stderr
  - Auto-copy public URL to clipboard
  - Process lifecycle management with proper cleanup
- **Docker support** — Detect running containers and create tunnels
- **Git integration** — Show current branch for each detected server
- **Start at Login** — Auto-launch on startup via `SMAppService`
- **Dark menu bar** — Clean, minimal design with `#0d0d0d` theme
- **Header controls** — Server/tunnel counters, Stop tunnels, Kill all, Settings
- **Server row actions** — Flare, Open, Kill with hover reveal
- **Tunnel cards** — Status indicators, uptime, public URL display
- **Settings popover** — Scan interval (2s/5s/10s/30s), Start at Login, diagnostics
- **Sleep/wake handling** — Pause polling on sleep, resume on wake
- **Startup cleanup** — Kill orphaned cloudflared processes on launch
- **App icon** — White thunder bolt on dark rounded square
- **21 unit tests** — lsof parsing, URL extraction, server type detection, Docker
- **GitHub Actions CI/CD** — Build + test on PR, DMG + release on tag

### Technical Details

- Swift 5.9+, SwiftUI, macOS 14+
- `MenuBarExtra` with `.window` style
- `@Observable` macro for state management
- `os.Logger` structured logging
- Universal binary (Apple Silicon + Intel)
- App Sandbox disabled for process/network access
- Zero external dependencies

[0.1.0]: https://github.com/kv5t/devbar/releases/tag/v0.1.0
