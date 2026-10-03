import CubeCore
import SwiftUI

/// Planificação em cruz:   U / L F R B / D
struct NetView: View {
    let n: Int
    let stickers: [Int]
    let cell: CGFloat
    var editable = false
    var onPaint: (Int) -> Void = { _ in }
    var showLabels = true

    private let gap: CGFloat = 6
    private static let layout: [(Face, Int, Int)] = [(.U, 1, 0), (.L, 0, 1), (.F, 1, 1), (.R, 2, 1), (.B, 3, 1), (.D, 1, 2)]
    private static let names: [Face: String] = [.U: "Cima (U)", .D: "Baixo (D)", .F: "Frente (F)", .B: "Trás (B)", .R: "Direita (R)", .L: "Esquerda (L)"]

    private var faceSize: CGFloat { CGFloat(n) * cell }
    private var labelH: CGFloat { showLabels ? 16 : 0 }
    private var block: CGFloat { faceSize + gap + labelH }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.layout, id: \.0) { (face, col, row) in
                VStack(alignment: .leading, spacing: 2) {
                    if showLabels {
                        Text(Self.names[face]!).font(.caption).foregroundStyle(.secondary).frame(height: labelH - 2)
                    }
                    faceGrid(face)
                }
                .offset(x: CGFloat(col) * (faceSize + gap), y: CGFloat(row) * block)
            }
        }
        .frame(width: 4 * faceSize + 3 * gap, height: 3 * block, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(editable ? DragGesture(minimumDistance: 0).onChanged { g in
            if let i = hit(g.location) { onPaint(i) }
        } : nil)
    }

    private func faceGrid(_ face: Face) -> some View {
        let base = face.rawValue * n * n
        return VStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { c in
                        let v = stickers[base + r * n + c]
                        RoundedRectangle(cornerRadius: cell * 0.12)
                            .fill(swatch(v))
                            .overlay(RoundedRectangle(cornerRadius: cell * 0.12).strokeBorder(.black.opacity(0.35), lineWidth: 1))
                            .padding(cell * 0.05)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.85)))
    }

    private func hit(_ p: CGPoint) -> Int? {
        for (face, col, row) in Self.layout {
            let x0 = CGFloat(col) * (faceSize + gap)
            let y0 = CGFloat(row) * block + labelH
            let x = p.x - x0, y = p.y - y0
            if x >= 0 && y >= 0 && x < faceSize && y < faceSize {
                let c = Int(x / cell), r = Int(y / cell)
                return face.rawValue * n * n + r * n + c
            }
        }
        return nil
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 0) {
            editor
                .frame(minWidth: 560)
            Divider()
            solutionPanel
                .frame(minWidth: 420, maxWidth: .infinity)
        }
        .frame(minWidth: 1080, minHeight: 720)
        .background(KeyHandler(model: model))
    }

    // MARK: Editor

    private var cell: CGFloat { [2: 34, 3: 28, 4: 22, 5: 18][model.n] ?? 18 }

    private var editor: some View {
        ScrollView { editorContent }
    }

    var editorContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Cubo").font(.headline)
                    Picker("", selection: $model.n) {
                        ForEach(2...5, id: \.self) { Text("\($0)x\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .disabled(model.solving)
                    Spacer()
                    Button { showHelp.toggle() } label: { Label("Como usar", systemImage: "questionmark.circle") }
                        .popover(isPresented: $showHelp) { HelpView().frame(width: 460) }
                }

                paletteView

                NetView(n: model.n, stickers: model.stickers, cell: cell, editable: !model.hasSolution && !model.solving) { i in
                    model.paint(i)
                }
                .opacity(model.hasSolution ? 0.55 : 1)

                HStack {
                    Group {
                        Button("Cubo resolvido") { model.resetSolved() }
                        Button("Limpar tudo") { model.clearAll() }
                        Button("Embaralhar (teste)") { model.scramble() }
                    }
                    .disabled(model.hasSolution)
                    Spacer()
                    if model.hasSolution {
                        Button { model.editAgain() } label: { Label("Editar cores", systemImage: "pencil") }
                            .controlSize(.large)
                    } else {
                    Button {
                        model.solve()
                    } label: {
                        if model.solving {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Calculando…") }
                        } else {
                            Label("Resolver", systemImage: "wand.and.stars")
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.solving)
                    }
                }
                .disabled(model.solving)

                if let e = model.errorMessage {
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Segure o cubo sem girá-lo: uma face para você (Frente) e outra para cima (Cima). Cada face da planificação é desenhada como você a vê olhando de frente para ela, com a borda de cima encostada na face de Cima (para Cima e Baixo, a borda que encosta na Frente fica para baixo/para cima, como no desenho).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
    }

    private var paletteView: some View {
        let counts = model.counts
        let need = model.n * model.n
        return HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { i in
                Button { model.selected = i } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(palette[i].color)
                            .frame(width: 40, height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(model.selected == i ? Color.accentColor : .black.opacity(0.3), lineWidth: model.selected == i ? 3 : 1))
                        Text("\(i + 1) · \(palette[i].name)").font(.caption2)
                        Text("\(counts[i])/\(need)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(counts[i] == need ? Color.secondary : Color.red)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Solução

    private var solutionPanel: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                Cube3DView(controller: model.scene)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                Text("Arraste para girar a visão (não muda o cubo)")
                    .font(.caption2).foregroundStyle(.secondary).padding(8)
            }
            .frame(minHeight: 280)

            if model.hasSolution {
                stepHeader
                controls
                stepList
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cube").font(.system(size: 34)).foregroundStyle(.secondary)
                    Text("Pinte as cores do seu cubo à esquerda e clique em Resolver.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
    }

    private var stepHeader: some View {
        VStack(spacing: 6) {
            if model.steps.isEmpty {
                Text("O cubo já está resolvido! 🎉").font(.title2)
            } else if model.current < model.steps.count {
                let s = model.steps[model.current]
                HStack(alignment: .firstTextBaseline) {
                    Text("Próximo:").foregroundStyle(.secondary)
                    Text(s.notation).font(.system(size: 34, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("\(s.stage)").font(.callout).foregroundStyle(.secondary)
                }
                Text(Notation.describe(s, n: model.n))
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Resolvido! 🎉 (\(model.steps.count) passos)").font(.title2)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button { model.jump(to: 0) } label: { Image(systemName: "backward.end.fill") }
            Button { model.previous() } label: { Image(systemName: "backward.frame.fill") }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button { model.togglePlay() } label: { Image(systemName: model.playing ? "pause.fill" : "play.fill") }
                .keyboardShortcut(.space, modifiers: [])
            Button { model.next() } label: { Image(systemName: "forward.frame.fill") }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button { model.jump(to: model.steps.count) } label: { Image(systemName: "forward.end.fill") }
            Text("\(model.current)/\(model.steps.count)").font(.callout.monospacedDigit()).frame(width: 70)
            Spacer()
            Image(systemName: "tortoise")
            Slider(value: $model.speed, in: 0.3...3).frame(width: 110)
            Image(systemName: "hare")
        }
        .disabled(model.steps.isEmpty)
    }

    private var stepList: some View {
        ScrollViewReader { proxy in
            ScrollView { stepChips }
            .onChange(of: model.current) { c in
                withAnimation { proxy.scrollTo(min(c, max(model.steps.count - 1, 0)), anchor: .center) }
            }
        }
    }

    var stepChips: some View {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.stageRanges, id: \.1) { (name, a, b) in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(name) — \(b - a) passos").font(.subheadline.bold())
                            FlowLayout(spacing: 4) {
                                ForEach(a..<b, id: \.self) { i in
                                    Text(model.steps[i].notation)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(
                                            i == model.current ? Color.accentColor.opacity(0.85) :
                                                (i < model.current ? Color.gray.opacity(0.15) : Color.gray.opacity(0.3))))
                                        .foregroundStyle(i == model.current ? .white : (i < model.current ? .secondary : .primary))
                                        .id(i)
                                        .onTapGesture { model.jump(to: i) }
                                        .help("Clique para ir até este passo")
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
    }
}

/// Atalhos de teclado 1–6 para escolher a cor.
struct KeyHandler: NSViewRepresentable {
    let model: AppModel
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if let ch = e.charactersIgnoringModifiers, let d = Int(ch), (1...6).contains(d), e.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                Task { @MainActor in model.selected = d - 1 }
                return nil
            }
            return e
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeCoordinator() -> Coord { Coord() }
    final class Coord { var monitor: Any? }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > w && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Como usar").font(.title3.bold())
                Text("1. Escolha o tamanho do cubo.\n2. Escolha uma cor na paleta (ou tecle 1–6) e clique/arraste nos quadradinhos para pintar.\n3. Segure o cubo sempre na mesma posição: Frente virada para você, Cima para cima. Não gire o cubo inteiro durante a solução.\n4. Clique em Resolver (⌘↩) e siga os passos com ← → ou espaço.")
                Text("Notação").font(.headline)
                Text("""
                U, D, R, L, F, B — Cima, Baixo, Direita, Esquerda, Frente, Trás.
                Letra sozinha: gire a face 90° no sentido horário (olhando para ela).
                ' (linha): sentido anti-horário.   2: meia volta (180°).
                2R, 3U…: gire só a 2ª/3ª camada a partir daquela face.
                Rw, Uw…: gire juntas as 2 camadas externas daquela face.
                M, E, S: camada do meio (M acompanha L, E acompanha D, S acompanha F).
                """)
                .font(.callout)
                Text("Dica: no cubo 3D, a camada que vai girar é animada a cada passo. Em cubos ímpares as cores dos centros fixos definem qual cor fica em cada face.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(16)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
