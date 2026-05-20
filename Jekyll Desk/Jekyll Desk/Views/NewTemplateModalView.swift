import SwiftUI

struct NewTemplateModalView: View {
    @ObservedObject var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss
    private let template: FrontMatterTemplate?
    @State private var name = ""
    @State private var slug = ""
    @State private var yamlTemplate = """
    ---
    layout: post
    title: {TITLE}
    date: {DATETIME}
    category: {CATEGORY}
    tags:
      - {TAG}
    description: {DESCRIPTION}
    ---
    """

    private var detectedFields: [FrontMatterField] {
        FrontMatterParser.fields(from: yamlTemplate)
    }

    private var isEditing: Bool {
        template != nil
    }

    init(appVM: AppViewModel, template: FrontMatterTemplate? = nil) {
        self.appVM = appVM
        self.template = template
        _name = State(initialValue: template?.name ?? "")
        _slug = State(initialValue: template?.slug ?? "")
        _yamlTemplate = State(initialValue: template?.yamlTemplate ?? Self.defaultYamlTemplate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Front Matter Template" : "New Front Matter Template")
                    .font(.headline)
                Spacer()
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 18) {
                        formText("Template Name", placeholder: "e.g. Blog Post", text: $name)
                        formText("Slug / Key", placeholder: "e.g. blog-post", text: $slug)
                    }

                    HStack(alignment: .bottom) {
                        Text("YAML Template")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("Placeholders inside the template will generate\nthe post form automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .trailing, spacing: 8) {
                            ForEach(1...max(1, yamlTemplate.components(separatedBy: .newlines).count), id: \.self) { line in
                                Text("\(line)")
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)

                        TextEditor(text: $yamlTemplate)
                            .font(.system(size: 13, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .frame(height: 170)
                    }
                    .padding(10)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appBorder))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected Placeholders")
                            .font(.caption.weight(.semibold))
                        FlowLayout(spacing: 8) {
                            ForEach(FrontMatterParser.placeholders(in: yamlTemplate), id: \.self) { placeholder in
                                Pill(text: placeholder)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Field Settings")
                            .font(.caption.weight(.semibold))
                        VStack(spacing: 0) {
                            row("Placeholder", "Field Type", "Repeatable", header: true)
                            ForEach(detectedFields) { field in
                                row(field.placeholder, field.type.displayName, field.repeatable ? "checkmark.circle.fill" : "-", header: false)
                            }
                        }
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appBorder))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
                .padding(20)
            }

            Divider()
            HStack(spacing: 14) {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primaryText)
                        .frame(width: 106, height: 34)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.appBorder, lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                }
                .buttonStyle(.plain)

                Button("Save Template") {
                    let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
                    let template = FrontMatterTemplate(
                        id: self.template?.id ?? UUID(),
                        name: cleanedName.isEmpty ? "Untitled Template" : cleanedName,
                        slug: cleanedSlug.isEmpty ? "untitled-template" : cleanedSlug,
                        yamlTemplate: yamlTemplate,
                        fields: detectedFields
                    )
                    appVM.saveTemplate(template)
                    dismiss()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 132, height: 34)
                .background(Color.appBlue)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: Color.appBlue.opacity(0.22), radius: 3, y: 1)
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .foregroundStyle(Color.primaryText)
        .preferredColorScheme(.light)
    }

    private static let defaultYamlTemplate = """
    ---
    layout: post
    title: {TITLE}
    date: {DATETIME}
    category: {CATEGORY}
    tags:
      - {TAG}
    description: {DESCRIPTION}
    ---
    """

    private func formText(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            TextField(placeholder, text: text)
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

    private func row(_ first: String, _ second: String, _ third: String, header: Bool) -> some View {
        HStack {
            Text(first).frame(maxWidth: .infinity, alignment: .leading)
            Text(second).frame(width: 140, alignment: .leading)
            if third == "checkmark.circle.fill" {
                Image(systemName: third)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appGreen)
                    .frame(width: 90)
            } else {
                Text(third)
                    .foregroundStyle(.secondary)
                    .frame(width: 90)
            }
        }
        .font(header ? .caption.weight(.semibold) : .caption)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(header ? Color.appBackground : Color.white)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
