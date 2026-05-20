import SwiftUI

struct PostFormView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var pendingTag = ""
    @FocusState private var focusedField: String?
    private let labelWidth: CGFloat = 96
    private let controlHeight: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("POST FORM")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Text("(generated from template)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
            }

            ForEach(appVM.editorVM.selectedTemplate.fields) { field in
                fieldView(field)
            }
        }
        .onChange(of: appVM.editorVM.focusedField) { _, value in
            focusedField = value
        }
    }

    @ViewBuilder
    private func fieldView(_ field: FrontMatterField) -> some View {
        switch field.type {
        case .repeatableText:
            repeatableTextField(field)
        case .tagList:
            tagField(field)
        case .select:
            scalarField(field, picker: true)
        case .date:
            scalarField(field, picker: false)
        case .text, .boolean:
            scalarField(field, picker: false)
        }
    }

    private func scalarField(_ field: FrontMatterField, picker: Bool) -> some View {
        HStack(spacing: 8) {
            Text(field.label + (field.required ? " *" : ""))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primaryText)
                .frame(width: labelWidth, alignment: .leading)

            if picker, !field.options.isEmpty {
                Picker("", selection: Binding(
                    get: { appVM.editorVM.formValues[field.placeholder]?.first ?? field.options.first ?? "" },
                    set: { appVM.editorVM.updateValue(field.placeholder, value: $0) }
                )) {
                    ForEach(field.options, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .frame(height: controlHeight)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                compactTextField(field.label, text: Binding(
                    get: { appVM.editorVM.formValues[field.placeholder]?.first ?? "" },
                    set: { appVM.editorVM.updateValue(field.placeholder, value: $0) }
                ), focusID: field.placeholder)
            }
        }
    }

    private func repeatableTextField(_ field: FrontMatterField) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(field.label + (field.required ? " *" : ""))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primaryText)

            ForEach(Array((appVM.editorVM.formValues[field.placeholder] ?? [""]).enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 20)
                    compactTextField(field.label, text: Binding(
                        get: { appVM.editorVM.formValues[field.placeholder]?[safe: index] ?? "" },
                        set: { appVM.editorVM.updateValue(field.placeholder, index: index, value: $0) }
                    ), focusID: field.placeholder)
                    Button {
                        appVM.editorVM.removeValue(field.placeholder, index: index)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(spacing: 8) {
                Color.clear
                    .frame(width: 20)
                Button {
                    appVM.editorVM.addValue(field.placeholder)
                } label: {
                    Label("Add Video ID", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
    }

    private func tagField(_ field: FrontMatterField) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(field.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primaryText)

            TagWrapLayout(spacing: 6, rowSpacing: 6, fillsLastSubview: true) {
                let visibleTags = appVM.editorVM.tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                ForEach(visibleTags, id: \.self) { tag in
                    Pill(text: tag) {
                        appVM.editorVM.removeTag(tag)
                    }
                }

                TextField("Add tag", text: $pendingTag)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: field.placeholder)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primaryText)
                    .frame(minWidth: 96, minHeight: 24, alignment: .leading)
                    .onSubmit {
                        appVM.editorVM.addTag(pendingTag)
                        pendingTag = ""
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: controlHeight, alignment: .leading)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = field.placeholder
            }

            Text("Tip: type a tag and press Enter to add it.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondaryText.opacity(0.62))
        }
    }

    private func compactTextField(_ placeholder: String, text: Binding<String>, focusID: String, trailingIcon: String? = nil) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .focused($focusedField, equals: focusID)
            .font(.system(size: 13))
            .foregroundStyle(Color.primaryText)
            .padding(.leading, 10)
            .padding(.trailing, trailingIcon == nil ? 10 : 30)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .background(Color.white)
            .overlay(alignment: .trailing) {
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primaryText)
                        .padding(.trailing, 9)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct TagWrapLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat
    var fillsLastSubview = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for index in subviews.indices {
            let subview = subviews[index]
            let isFlexibleLastSubview = fillsLastSubview && index == subviews.indices.last && proposal.width != nil
            let naturalSize = subview.sizeThatFits(.unspecified)
            let size: CGSize

            if isFlexibleLastSubview {
                let remainingWidth = x > 0 ? maxWidth - x : maxWidth
                if x > 0, remainingWidth < naturalSize.width {
                    y += rowHeight + rowSpacing
                    x = 0
                    rowHeight = 0
                }

                let targetWidth = max(naturalSize.width, maxWidth - x)
                size = subview.sizeThatFits(ProposedViewSize(width: targetWidth, height: nil))
                usedWidth = max(usedWidth, x + targetWidth)
                x += targetWidth + spacing
            } else {
                size = naturalSize
                if x > 0, x + size.width > maxWidth {
                    y += rowHeight + rowSpacing
                    x = 0
                    rowHeight = 0
                }

                usedWidth = max(usedWidth, x + size.width)
                x += size.width + spacing
            }

            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: proposal.width ?? usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let subview = subviews[index]
            let isFlexibleLastSubview = fillsLastSubview && index == subviews.indices.last
            let naturalSize = subview.sizeThatFits(.unspecified)

            if isFlexibleLastSubview {
                let remainingWidth = bounds.maxX - x
                if x > bounds.minX, remainingWidth < naturalSize.width {
                    y += rowHeight + rowSpacing
                    x = bounds.minX
                    rowHeight = 0
                }

                let targetWidth = max(naturalSize.width, bounds.maxX - x)
                let size = subview.sizeThatFits(ProposedViewSize(width: targetWidth, height: nil))
                rowHeight = max(rowHeight, size.height)
                subview.place(
                    at: CGPoint(x: x, y: y + max(0, (rowHeight - size.height) / 2)),
                    proposal: ProposedViewSize(width: targetWidth, height: size.height)
                )
                x += targetWidth + spacing
            } else {
                let size = naturalSize
                if x > bounds.minX, x + size.width > bounds.maxX {
                    y += rowHeight + rowSpacing
                    x = bounds.minX
                    rowHeight = 0
                }

                rowHeight = max(rowHeight, size.height)
                subview.place(
                    at: CGPoint(x: x, y: y + max(0, (rowHeight - size.height) / 2)),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: spacing) {
            content
            Spacer(minLength: 0)
        }
    }
}
