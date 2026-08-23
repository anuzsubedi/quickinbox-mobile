import SwiftUI

enum QuickMailDesign {
    static let contentMaxWidth: CGFloat = 720
    static let compactCornerRadius: CGFloat = 16
}

struct QuickMailMark: View {
    var size: Font = .largeTitle

    var body: some View {
        Image(systemName: "envelope.fill")
            .font(size.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }
}

struct ParticipantMonogram: View {
    @Environment(\.colorScheme) private var colorScheme

    let name: String
    var isEmphasized = false
    var size: CGFloat = 40

    var body: some View {
        Text(initials)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                isEmphasized
                    ? (colorScheme == .dark ? Color.black : Color.white)
                    : Color.primary
            )
            .frame(width: size, height: size)
            .background(
                isEmphasized ? Color.accentColor : Color.secondary.opacity(0.13),
                in: Circle()
            )
            .overlay(alignment: .bottomTrailing) {
                if isEmphasized {
                    Circle()
                        .fill(.background)
                        .frame(width: 11, height: 11)
                        .overlay {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                        }
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHidden(true)
    }

    private var initials: String {
        let words = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "@" || $0 == "." })
            .filter { !$0.isEmpty }
        let characters = words.prefix(2).compactMap(\.first)
        let value = String(characters).uppercased()
        return value.isEmpty ? "?" : value
    }
}

struct MetadataPill: View {
    let title: String
    let systemImage: String
    var tint: Color = .secondary

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.1), in: Capsule())
    }
}

struct QuickMailAccountHeader: View {
    let name: String
    let email: String
    var server: String?

    var body: some View {
        HStack(spacing: 14) {
            ParticipantMonogram(name: name, isEmphasized: true, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let server, !server.isEmpty {
                    Label(server, systemImage: "server.rack")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
