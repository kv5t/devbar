<div align="center">

# DevBar

**A native macOS menu bar app for dev servers.**

Detect running dev servers via port scanning, expose them through Cloudflare tunnels, and manage Docker containers — all from your menu bar.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-15%2B-blue.svg)](https://developer.apple.com/xcode/)

</div>

---

## Features

- **Auto-detect dev servers** — Scans TCP ports and identifies Node.js, Python, Ruby, Go, Rust, and more
- **Cloudflare tunnels** — One-click tunnel creation with `cloudflared` for instant public URLs
- **Docker support** — Detects running containers and creates tunnels for exposed ports
- **Git integration** — Shows current branch for each detected server
- **Start at Login** — Launch DevBar automatically on startup via `SMAppService`
- **Dark menu bar** — Clean, minimal design that stays out of your way
- **Zero dependencies** — Pure SwiftUI, no third-party packages

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** (16.0+ recommended)
- **[cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)** — Auto-installed on first use (or via `brew install cloudflared`)

## Installation

### Via Homebrew (Recommended)

```bash
brew tap kv5t/tap
brew trust kv5t/tap
brew install --cask devbar
```

### From Release

1. Go to [Releases](https://github.com/kv5t/devbar/releases)
2. Download the latest `DevBar.dmg`
3. Open the DMG and drag DevBar to Applications
4. Launch DevBar from Applications or Spotlight

### From Source

```bash
# Clone the repository
git clone https://github.com/kv5t/devbar.git
cd devbar/DevBar

# Build
xcodebuild -scheme DevBar -configuration Release build

# The app will be in: build/Build/Products/Release/DevBar.app
# Copy it to your Applications folder
```

### First Launch

On macOS, you may need to allow the app in **System Settings > Privacy & Security**.

## Usage

1. **Launch DevBar** — The icon appears in your menu bar
2. **Start a dev server** — DevBar automatically detects it
3. **Flare a server** — Hover over a server and click "Flare" to create a Cloudflare tunnel
4. **Copy the public URL** — The tunnel URL is automatically copied to your clipboard
5. **Kill a server** — Hover and click "Kill" to terminate a process

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Copy server URL | Right-click → "Copier l'URL" |
| Open in browser | Right-click → "Ouvrir dans le navigateur" |
| Create tunnel | Right-click → "Creer un tunnel" |

### Settings

Click the `...` button in the header to access:

- **Scan interval** — 2s, 5s, 10s, or 30s
- **Start at Login** — Auto-launch on startup
- **Copy diagnostic** — Copy diagnostic info for bug reports

## How It Works

### Port Detection

DevBar uses `lsof -iTCP -sTCP:LISTEN -n -P` to find all TCP ports in LISTEN state. It then:

1. Filters out system ports (< 1024) and ephemeral ports (≥ 49152)
2. Deduplicates by port number
3. Resolves CWD and start time via batch `lsof` and `ps` calls
4. Identifies git repos and project names
5. Filters out non-dev processes using a whitelist

### Cloudflare Tunnels

When you click "Flare", DevBar:

1. Locates the `cloudflared` binary (bundled, PATH, or Homebrew)
2. Launches `cloudflared tunnel --no-autoupdate --url http://localhost:PORT`
3. Captures the trycloudflare.com URL from stdout/stderr
4. Displays the tunnel with live status
5. Copies the public URL to your clipboard

### Process Detection

DevBar identifies dev servers by:

- **Process name** — node, python, ruby, go, cargo, etc.
- **Git root** — Falls back to directory name if in a git repo
- **File detection** — Checks for package.json, Gemfile, requirements.txt, etc.

## Architecture

```
DevBar/
├── Config/              # App configuration & enums
│   ├── Config.swift     # UserDefaults + SMAppService
│   └── Enums.swift      # ServerType, TunnelStatus, ContainerStatus
├── Models/              # Data models
│   ├── DevServer.swift  # Detected dev server
│   ├── Tunnel.swift     # Active Cloudflare tunnel
│   └── Container.swift  # Docker container
├── Services/            # Core business logic
│   ├── PortScanner.swift              # lsof-based port detection
│   ├── TunnelManager.swift            # Cloudflare tunnel lifecycle
│   ├── CloudflaredBundler.swift       # cloudflared binary locator
│   ├── CloudflaredProcessCleaner.swift # Startup orphan cleanup
│   └── ContainerScanner.swift         # Docker container detection
├── ViewModels/
│   └── PortStore.swift  # @Observable state management
├── Views/               # SwiftUI views
│   ├── DevBarViews.swift     # Header, server rows, states
│   ├── TunnelSectionView.swift  # Tunnel cards & animations
│   └── ContainerSectionView.swift # Docker container UI
├── DevBarApp.swift      # App entry (MenuBarExtra)
├── Logging.swift        # os.Logger setup
└── AppDelegate.swift    # NSApplicationDelegate
```

## Supported Servers

DevBar detects these dev server processes:

| Category | Processes |
|----------|-----------|
| **JavaScript/TypeScript** | node, npm, bun, deno, vite, webpack-dev-server |
| **Python** | python, python3, gunicorn, uvicorn, flask, django |
| **Ruby** | ruby, puma, rails, air |
| **Go** | go |
| **Rust** | cargo |
| **Elixir** | elixir, erl, mix |
| **Java** | java |
| **PHP** | php |
| **.NET** | dotnet |
| **Swift** | swift |
| **Static servers** | http-server, serve, parcel, gatsby, ember |

## Scripts

The `scripts/` directory contains:

| Script | Description |
|--------|-------------|
| `install-cloudflared.sh` | Downloads and installs cloudflared with SHA-256 verification |
| `verify-cloudflared.sh` | Validates installed cloudflared binary and checksums |
| `build-universal.sh` | Builds universal binary (Apple Silicon + Intel) and bundles cloudflared |

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

DevBar is inspired by:

- [port-menu](https://github.com/wieandteduard/port-menu) — Port detection architecture
- [tunnelbar](https://github.com/tony-roslund/tunnelbar) — Cloudflare tunnel management

## Support

- [Report a bug](https://github.com/kv5t/devbar/issues/new?template=bug_report.md)
- [Request a feature](https://github.com/kv5t/devbar/issues/new?template=feature_request.md)
- [Discussions](https://github.com/kv5t/devbar/discussions)
