import SwiftUI

/// Section affichant les conteneurs Docker
struct ContainerSectionView: View {
    let containers: [Container]
    let onStartTunnel: (UInt16) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CONTAINERS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                if !containers.isEmpty {
                    Text("\(containers.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ForEach(containers) { container in
                ContainerRowView(
                    container: container,
                    onStartTunnel: { onStartTunnel($0) }
                )
            }
        }
    }
}

struct ContainerRowView: View {
    let container: Container
    let onStartTunnel: (UInt16) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(container.isRunning ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                    .offset(y: -1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(container.name)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(container.image)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let ports = container.ports.first {
                            Text(ports)
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if container.isRunning {
                    Button(action: {
                        if let portStr = container.ports.first,
                           let port = extractPort(from: portStr) {
                            onStartTunnel(port)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                            Text("Flare")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
        }
    }

    private func extractPort(from string: String) -> UInt16? {
        let components = string.components(separatedBy: ":")
        guard let last = components.last else { return nil }
        let portPart = last.components(separatedBy: "->").first ?? last
        let portNumber = portPart.components(separatedBy: "/").first ?? portPart
        return UInt16(portNumber)
    }
}
