import SwiftUI

struct FrontMatterTemplateListView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var templateToRemove: FrontMatterTemplate?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(
                "FRONT MATTER TEMPLATES",
                trailing: AnyView(
                    IconButton(systemName: "plus") {
                        appVM.editingTemplate = nil
                        appVM.showNewTemplate = true
                    }
                )
            )

            ForEach(appVM.projectVM.selectedProject?.templates ?? FrontMatterTemplate.defaults) { template in
                let selected = template.id == appVM.editorVM.selectedTemplate.id || template.slug == appVM.editorVM.selectedTemplate.slug
                let isDefault = template.id == appVM.projectVM.selectedProject?.defaultTemplateID
                Button {
                    appVM.editorVM.selectTemplate(template)
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.gearshape")
                            .foregroundStyle(Color.secondaryText)
                        Text(template.name)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primaryText)
                        if isDefault {
                            Text("(default)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Color.appBlue : Color.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 35)
                    .background(selected ? Color.selectionBlue : Color.panelBackground)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? Color.appBlue : Color.appBorder, lineWidth: selected ? 1.2 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit template") {
                        appVM.editingTemplate = template
                        appVM.showNewTemplate = true
                    }
                    Button("Set as Default") {
                        appVM.setDefaultTemplate(template)
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        templateToRemove = template
                    }
                }
            }
        }
        .alert("Remove Template?", isPresented: removeConfirmationBinding, presenting: templateToRemove) { template in
            Button("Cancel", role: .cancel) {
                templateToRemove = nil
            }
            Button("Remove", role: .destructive) {
                appVM.removeTemplate(template)
                templateToRemove = nil
            }
        } message: { template in
            Text("Are you sure you want to remove \"\(template.name)\"?")
        }
    }

    private var removeConfirmationBinding: Binding<Bool> {
        Binding(
            get: { templateToRemove != nil },
            set: { if !$0 { templateToRemove = nil } }
        )
    }
}
