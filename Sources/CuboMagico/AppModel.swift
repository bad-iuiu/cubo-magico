import CubeCore
import SwiftUI

struct CubeColor {
    let name: String
    let color: Color
    let ns: NSColor
}

let palette: [CubeColor] = [
    CubeColor(name: "Branco", color: Color(red: 0.97, green: 0.97, blue: 0.97), ns: NSColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)),
    CubeColor(name: "Vermelho", color: Color(red: 0.80, green: 0.10, blue: 0.12), ns: NSColor(red: 0.80, green: 0.10, blue: 0.12, alpha: 1)),
    CubeColor(name: "Verde", color: Color(red: 0.05, green: 0.62, blue: 0.28), ns: NSColor(red: 0.05, green: 0.62, blue: 0.28, alpha: 1)),
    CubeColor(name: "Amarelo", color: Color(red: 1.00, green: 0.84, blue: 0.00), ns: NSColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1)),
    CubeColor(name: "Laranja", color: Color(red: 1.00, green: 0.47, blue: 0.00), ns: NSColor(red: 1.00, green: 0.47, blue: 0.00, alpha: 1)),
    CubeColor(name: "Azul", color: Color(red: 0.00, green: 0.32, blue: 0.80), ns: NSColor(red: 0.00, green: 0.32, blue: 0.80, alpha: 1)),
]
let unknownColor = Color(white: 0.45)
let unknownNS = NSColor(white: 0.45, alpha: 1)

func swatch(_ c: Int) -> Color { c >= 0 ? palette[c].color : unknownColor }

@MainActor
final class AppModel: ObservableObject {
    @Published var n = 3 { didSet { if n != oldValue { resetSolved() } } }
    /// Cores informadas (-1 = vazio)
    @Published var stickers: [Int] = CubeState.solved(3).stickers { didSet { if stickers != oldValue { invalidate() } } }
    @Published var selected = 0

    @Published var steps: [SolutionStep] = []
    @Published var current = 0
    @Published var solving = false
    @Published var errorMessage: String?
    @Published var playing = false
    @Published var speed = 1.0

    private var states: [CubeState] = []
    private var playTask: Task<Void, Never>?
    let scene = Cube3DController()

    init() { scene.show(CubeState(n: n, stickers: stickers)) }

    var hasSolution: Bool { !states.isEmpty }

    var counts: [Int] {
        var c = Array(repeating: 0, count: 6)
        for s in stickers where s >= 0 { c[s] += 1 }
        return c
    }

    var displayState: CubeState {
        states.isEmpty ? CubeState(n: n, stickers: stickers) : states[current]
    }

    func resetSolved() {
        stickers = CubeState.solved(n).stickers
        invalidate()
    }

    func clearAll() {
        // Mantém os centros fixos (ímpares) para servir de referência.
        var s = Array(repeating: -1, count: 6 * n * n)
        if n % 2 == 1 {
            for f in 0..<6 { s[f * n * n + (n / 2) * n + n / 2] = f }
        }
        stickers = s
    }

    func scramble() {
        stickers = CubeState.scrambled(n).stickers
    }

    func paint(_ index: Int) {
        guard stickers[index] != selected else { return }
        stickers[index] = selected
    }

    private func invalidate() {
        stopPlaying()
        steps = []; states = []; current = 0; errorMessage = nil
        scene.show(CubeState(n: n, stickers: stickers))
    }

    func solve() {
        if stickers.contains(-1) {
            errorMessage = "Ainda há quadradinhos sem cor (cinza)."
            return
        }
        let input = CubeState(n: n, stickers: stickers)
        solving = true; errorMessage = nil
        Task.detached(priority: .userInitiated) {
            let result = Result { try CubeSolver.solve(input) }
            await MainActor.run {
                self.solving = false
                guard input.stickers == self.stickers else { return }
                switch result {
                case .success(let st):
                    self.load(st, input)
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }

    func load(_ st: [SolutionStep], _ input: CubeState) {
        var s = input
        var all = [s]
        for step in st { s.apply(step.moves); all.append(s) }
        steps = st
        states = all
        current = 0
        scene.show(input)
    }

    // MARK: reprodução

    func next() {
        guard current < steps.count else { stopPlaying(); return }
        let step = steps[current]
        current += 1
        scene.animate(step.moves, n: n, to: states[current], duration: 0.35 / speed)
    }

    func previous() {
        guard current > 0 else { return }
        current -= 1
        let inv = steps[current].moves.map { $0.inverse }
        scene.animate(inv, n: n, to: states[current], duration: 0.35 / speed)
    }

    func jump(to i: Int) {
        guard hasSolution else { return }
        stopPlaying()
        current = max(0, min(steps.count, i))
        scene.show(states[current])
    }

    func togglePlay() {
        if playing { stopPlaying(); return }
        if current >= steps.count { jump(to: 0) }
        playing = true
        playTask = Task { [weak self] in
            while let self, self.playing, !Task.isCancelled {
                self.next()
                if self.current >= self.steps.count { self.stopPlaying(); break }
                try? await Task.sleep(nanoseconds: UInt64(0.55 / self.speed * 1e9))
            }
        }
    }

    func stopPlaying() {
        playing = false
        playTask?.cancel(); playTask = nil
    }

    func editAgain() {
        stopPlaying()
        steps = []; states = []; current = 0
        scene.show(CubeState(n: n, stickers: stickers))
    }

    /// Faixas de passos por etapa: (nome, início, fim exclusivo)
    var stageRanges: [(String, Int, Int)] {
        var out: [(String, Int, Int)] = []
        for (i, s) in steps.enumerated() {
            if let last = out.last, last.0 == s.stage { out[out.count - 1].2 = i + 1 }
            else { out.append((s.stage, i, i + 1)) }
        }
        return out
    }
}
