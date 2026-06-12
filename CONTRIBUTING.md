# Contributing to DevBar

Thank you for your interest in contributing to DevBar! This document provides guidelines and steps for contributing.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [GitHub Issues](https://github.com/kv5t/devbar/issues).
2. If not, create a new issue with:
   - A clear, descriptive title
   - Steps to reproduce the issue
   - Expected vs actual behavior
   - macOS version and Xcode version
   - Screenshots if applicable

### Suggesting Features

1. Check existing issues for similar feature requests.
2. Create a new issue with the `enhancement` label.
3. Describe the feature, its use case, and why it would benefit DevBar.

### Pull Requests

1. Fork the repository.
2. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes following the code guidelines below.
4. Test your changes thoroughly.
5. Commit with a clear, descriptive message.
6. Push to your fork and create a Pull Request.

## Development Setup

### Prerequisites

- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+ (16.0+ recommended)
- Swift 5.9+
- [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) installed (`brew install cloudflared`)

### Building

```bash
# Clone your fork
git clone https://github.com/your-username/devbar.git
cd devbar/DevBar

# Build
xcodebuild -scheme DevBar -configuration Debug build

# Run tests
xcodebuild test -scheme DevBar -destination 'platform=macOS'
```

### Project Structure

```
DevBar/
├── DevBar/
│   ├── Config/          # App configuration (Config.swift, Enums.swift)
│   ├── Models/          # Data models (DevServer, Tunnel, Container)
│   ├── Services/        # Core services (PortScanner, TunnelManager, etc.)
│   ├── ViewModels/      # State management (PortStore)
│   ├── Views/           # SwiftUI views
│   ├── DevBarApp.swift  # App entry point
│   └── Logging.swift    # os.Logger setup
├── DevBarTests/         # Unit tests
└── scripts/             # Build and install scripts
```

## Code Guidelines

### Swift Style

- Use Swift 5.9+ features (structured concurrency, `@Observable`, etc.)
- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use `// MARK: -` for code organization
- Comments in French (to match existing codebase)
- No external dependencies — use only Apple frameworks

### SwiftUI

- Use `@Observable` macro (not `ObservableObject` where possible)
- Prefer `@Environment` for dependency injection
- Use `withAnimation` for state changes
- Keep views small and composable

### Concurrency

- Use `@MainActor` for UI-related code
- Use `Sendable` conformance where required
- Avoid `DispatchQueue.main.async` — use `Task { @MainActor in }` instead
- Handle `Task.isCancelled` in long-running tasks

### Testing

- Add tests for new functionality
- Test edge cases and error paths
- Use descriptive test names
- Keep tests independent

## Commit Messages

Use clear, descriptive commit messages:

- `feat: add Docker container detection`
- `fix: resolve tunnel kill not terminating process`
- `docs: update README with installation steps`
- `refactor: simplify PortScanner filtering logic`
- `test: add unit tests for CloudflareURL extraction`

## Questions?

Feel free to open an issue for any questions about contributing!
