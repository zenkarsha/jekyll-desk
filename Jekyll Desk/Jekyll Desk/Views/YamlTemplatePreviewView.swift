import SwiftUI

struct YamlTemplatePreviewView: View {
    let template: FrontMatterTemplate
    private var lines: [String] { template.yamlTemplate.components(separatedBy: .newlines) }
    private var showsRepeatableBadge: Bool {
        template.fields.contains { $0.placeholder == "YOUTUBE_VIDEO_ID" && $0.repeatable }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("YAML TEMPLATE PREVIEW")
            previewBody
        }
    }

    private var previewBody: some View {
        HStack(alignment: .top, spacing: 10) {
            lineNumbers
            Divider()
            yamlText
        }
        .padding(10)
        .frame(height: 176, alignment: .top)
        .background(Color.panelBackground)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appBorder))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var lineNumbers: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(lines.indices, id: \.self) { index in
                Text("\(index + 1)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var yamlText: some View {
        Text(template.yamlTemplate)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                if showsRepeatableBadge {
                    Text("repeatable")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.selectionBlue)
                        .clipShape(Capsule())
                        .offset(y: 52)
                }
            }
    }
}
