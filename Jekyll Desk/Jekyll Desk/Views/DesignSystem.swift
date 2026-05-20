import SwiftUI
import AppKit

extension Color {
    static let appBackground = Color(red: 0.972, green: 0.976, blue: 0.982)
    static let toolbarBackground = Color(red: 0.985, green: 0.987, blue: 0.992)
    static let panelBackground = Color.white
    static let appBorder = Color(red: 0.898, green: 0.906, blue: 0.922)
    static let appBlue = Color(red: 0.039, green: 0.518, blue: 1.0)
    static let appGreen = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let appRed = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let primaryText = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let secondaryText = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let selectionBlue = Color(red: 0.910, green: 0.945, blue: 1.0)
}

struct SectionTitle: View {
    let title: String
    var trailing: AnyView?

    init(_ title: String, trailing: AnyView? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
            Spacer()
            trailing
        }
    }
}

struct IconButton: View {
    @State private var isHovered = false

    let systemName: String
    var iconSize: CGFloat = 14
    var foregroundColor: Color = .primaryText
    var hoverBackgroundColor: Color? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: 28, height: 28)
                .background {
                    if let hoverBackgroundColor {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(hoverBackgroundColor.opacity(isHovered ? 1 : 0))
                    }
                }
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
}

struct Pill: View {
    let text: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
            }
        }
        .font(.caption)
        .foregroundStyle(Color.primaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.selectionBlue)
        .clipShape(Capsule())
    }
}

struct RoundedPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color.panelBackground)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var width: CGFloat = 106

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.primaryText)
            .frame(width: width, height: 34)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.92 : 1) : 0.55)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var width: CGFloat = 132

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: width, height: 34)
            .background(Color.appBlue.opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.55))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: Color.appBlue.opacity(0.22), radius: 3, y: 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.94 : 1) : 0.7)
    }
}

struct AppModalInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
    }
}

extension View {
    func appModalInputStyle() -> some View {
        modifier(AppModalInputModifier())
    }
}

struct AppSettingsDropdown: View {
    @Binding var selection: String

    let values: [String]
    var width: CGFloat = 140

    var body: some View {
        ZStack(alignment: .trailing) {
            NativeMenuDropdown(selection: $selection, values: values)
            .frame(width: width, height: 34)
            .padding(.leading, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .padding(.trailing, 12)
                .allowsHitTesting(false)
        }
    }
}

private struct NativeMenuDropdown: NSViewRepresentable {
    @Binding var selection: String
    let values: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.isBordered = false
        button.focusRingType = .none
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryPushIn)
        button.preferredEdge = .maxY

        if let cell = button.cell as? NSPopUpButtonCell {
            cell.arrowPosition = .noArrow
            cell.isBordered = false
            cell.usesItemFromMenu = true
            cell.controlSize = .regular
            cell.font = .systemFont(ofSize: 13, weight: .medium)
            cell.lineBreakMode = .byTruncatingTail
        }

        update(button, context: context)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        update(button, context: context)
    }

    private func update(_ button: NSPopUpButton, context: Context) {
        let currentTitle = button.selectedItem?.title
        let needsMenuRefresh = button.numberOfItems != values.count || button.itemTitles != values

        if needsMenuRefresh {
            button.removeAllItems()
            button.addItems(withTitles: values)
        }

        if currentTitle != selection {
            button.selectItem(withTitle: selection)
        }

        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = NSColor(Color.primaryText)
        button.setFrameSize(NSSize(width: button.frame.width, height: 34))
        (button.cell as? NSPopUpButtonCell)?.font = .systemFont(ofSize: 13, weight: .medium)
    }

    final class Coordinator: NSObject {
        private var selection: Binding<String>

        init(selection: Binding<String>) {
            self.selection = selection
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            selection.wrappedValue = sender.selectedItem?.title ?? selection.wrappedValue
        }
    }
}
