import SwiftUI

struct DecorationEditor: View {
    @ObservedObject var session: DesktopSession
    let display: String
    @State private var drag: [DesktopProp: CGSize] = [:]

    private var props: [DesktopProp] {
        DesktopProp.allCases.filter { session.decoration($0, on: display) }
    }

    var body: some View {
        if !props.isEmpty {
            Text("Drag an icon to position it on the selected display.").font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                    ForEach(props) { prop in
                        let layout = session.decorationLayout(prop, on: display)
                        let shift = drag[prop] ?? .zero
                        let vertical = prop == .tree ? size.height : size.height * (1 - layout.y) + shift.height
                        Image(systemName: prop == .tree ? "tree.fill" : "snowflake")
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(.regularMaterial, in: Circle())
                            .position(x: size.width * layout.x + shift.width,
                                      y: vertical - 16)
                            .gesture(DragGesture().onChanged { drag[prop] = $0.translation }
                                .onEnded { value in
                                    drag[prop] = nil
                                    guard size.width > 0, size.height > 0 else { return }
                                    var next = layout
                                    next.x = min(0.94, max(0.06, next.x + value.translation.width / size.width))
                                    if prop == .snowman {
                                        next.y = min(0.86, max(0, next.y - value.translation.height / size.height))
                                    }
                                    session.updateDecoration(prop, on: display, layout: next)
                                })
                            .accessibilityHidden(true)
                    }
                }.clipped()
            }.frame(height: 100)

            ForEach(props) { prop in
                HStack {
                    Text(prop.title)
                    Spacer()
                    Button("Move Left", systemImage: "arrow.left") { change(prop) { $0.x = max(0.06, $0.x - 0.05) } }
                    Button("Move Right", systemImage: "arrow.right") { change(prop) { $0.x = min(0.94, $0.x + 0.05) } }
                    if prop == .snowman {
                        Button("Move Up", systemImage: "arrow.up") { change(prop) { $0.y = min(0.86, $0.y + 0.08) } }
                        Button("Move Down", systemImage: "arrow.down") { change(prop) { $0.y = max(0, $0.y - 0.08) } }
                    }
                    Button("Rotate", systemImage: "rotate.right") {
                        change(prop) { layout in
                            if prop == .tree {
                                let maximum = DecorationLayout.maxTreeLean
                                layout.angle = layout.treeLean >= maximum ? -maximum : min(maximum, layout.treeLean + 15)
                            } else {
                                layout.angle = (layout.angle + 15).truncatingRemainder(dividingBy: 360)
                            }
                        }
                    }
                    if prop == .snowman {
                        Button("Remove decoration", systemImage: "trash") {
                            session.setDecoration(prop, on: display, enabled: false)
                        }
                    }
                }.labelStyle(.iconOnly)
                if prop == .tree {
                    Toggle("Tree lights", isOn: Binding(
                        get: { session.decorationLayout(.tree, on: display).lights },
                        set: { selected in change(.tree) { $0.lights = selected } }
                    ))
                }
            }
        }
    }

    private func change(_ prop: DesktopProp, change: (inout DecorationLayout) -> Void) {
        var layout = session.decorationLayout(prop, on: display)
        change(&layout)
        session.updateDecoration(prop, on: display, layout: layout)
    }
}
