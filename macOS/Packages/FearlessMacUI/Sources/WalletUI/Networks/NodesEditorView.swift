import DesignSystem
import SwiftUI
import WalletCore

/// The nodes of one network: automatic selection or a chosen node, with
/// custom nodes that can be added (after the engine checked them) and removed.
struct NodesEditorView: View {
    @Bindable var model: NodesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isLoading, model.nodes.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading nodes…").foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    NodeChoiceRow(
                        title: "Automatic",
                        detail: "Fearless picks a node that answers and switches if it stops.",
                        isSelected: model.selectedNodeID == nil,
                        isCustom: false,
                        onSelect: { Task { await model.select(nil) } },
                        onRemove: nil
                    )
                    ForEach(model.nodes) { node in
                        NodeChoiceRow(
                            title: node.name,
                            detail: node.url.absoluteString,
                            isSelected: model.selectedNodeID == node.id,
                            isCustom: node.isCustom,
                            onSelect: { Task { await model.select(node.id) } },
                            onRemove: node.isCustom ? { Task { await model.remove(node) } } : nil
                        )
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Node")
            }

            if model.isAddingNode {
                addForm
            } else {
                Button {
                    model.beginAdd()
                } label: {
                    Label("Add Custom Node…", systemImage: "plus")
                }
                .controlSize(.small)
                .disabled(model.chain == nil)
            }
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New node").font(.callout.weight(.medium))
            TextField("Name (optional)", text: $model.newNodeName)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Node name")
            TextField(model.chain.map { NodesModel.example(for: $0) } ?? "wss://", text: $model.newNodeURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .autocorrectionDisabled()
                .onSubmit { Task { await model.addNode() } }
                .accessibilityLabel("Node address")
            if let problem = model.urlProblem {
                InlineMessage(problem, kind: .error)
            } else if let error = model.addError {
                InlineMessage(error, kind: .error)
            } else {
                Text("Fearless checks that the node answers for this network before saving it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if model.isChecking {
                    ProgressView().controlSize(.small)
                    Text("Checking…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { model.cancelAdd() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Node") { Task { await model.addNode() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canAdd)
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// One selectable node, drawn like a radio button row.
private struct NodeChoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let isCustom: Bool
    let onSelect: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? BrandColor.accent : Color.secondary)
                        .font(.body)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(title).font(.callout.weight(.medium))
                            if isCustom {
                                StatusPill("Custom", kind: .neutral, showsIcon: false)
                            }
                        }
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isSelected ? "Selected. \(detail)" : detail)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove this node")
                .accessibilityLabel("Remove \(title)")
            }
        }
        .padding(.vertical, 5)
    }
}
