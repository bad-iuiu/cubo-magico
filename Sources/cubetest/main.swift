import CubeCore
import Foundation

let sizes = CommandLine.arguments.count > 1 ? CommandLine.arguments[1...].compactMap { Int($0) } : [2, 3, 4, 5]
for n in sizes {
    var total = 0, maxLen = 0
    let trials = 20
    let t0 = Date()
    for t in 0..<trials {
        let s = CubeState.scrambled(n, seed: UInt64(t + 1))
        do {
            let steps = try CubeSolver.solve(s)
            let after = s.applying(steps.flatMap { $0.moves })
            if !after.isSolved { print("N=\(n) trial \(t): NOT SOLVED"); exit(1) }
            total += steps.count; maxLen = max(maxLen, steps.count)
            if t == 0 {
                print("N=\(n) exemplo:", steps.map { "\($0.notation)" }.joined(separator: " "))
            }
        } catch {
            print("N=\(n) trial \(t): erro \(error.localizedDescription)"); exit(1)
        }
    }
    print(String(format: "N=%d ok: média %.1f passos, máx %d, %.2fs total", n, Double(total) / Double(trials), maxLen, Date().timeIntervalSince(t0)))
}

// Casos de borda
for n in 2...5 {
    let r = try! CubeSolver.solve(CubeState.solved(n))
    print("N=\(n) resolvido -> \(r.count) passos")
    // troca duas cores de um mesmo canto (canto torcido/impossível)
    var s = CubeState.scrambled(n, seed: 99)
    let a = 0, b = n * n * 4 + 1 // U(0,0) e L(0,1)
    s.stickers.swapAt(a, b)
    do { _ = try CubeSolver.solve(s); print("N=\(n) troca: resolveu?!") } catch { print("N=\(n) troca -> \(error.localizedDescription)") }
    // gira um canto (U(0,0), L(0,0), B(0,N-1) são o canto ULB)
    var t = CubeState.scrambled(n, seed: 5)
    let u = 0, l = 4 * n * n, bk = 5 * n * n + n - 1
    (t.stickers[u], t.stickers[l], t.stickers[bk]) = (t.stickers[l], t.stickers[bk], t.stickers[u])
    do { _ = try CubeSolver.solve(t); print("N=\(n) torção: resolveu?!") } catch { print("N=\(n) torção -> \(error.localizedDescription)") }
}
