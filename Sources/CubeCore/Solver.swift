import Foundation

public struct SolutionStep: Identifiable, Sendable {
    public let id: Int
    public let notation: String
    public let moves: [Move]
    public let stage: String
}

public enum CubeSolver {
    /// Resolve o cubo. As cores são índices 0...5 (qualquer esquema de cores).
    public static func solve(_ input: CubeState) throws -> [SolutionStep] {
        let n = input.n
        guard (2...7).contains(n) else { throw CubeError.invalid("Tamanho não suportado.") }
        let geo = CubeGeometry.of(n)
        var counts = Array(repeating: 0, count: 6)
        for c in input.stickers {
            guard (0..<6).contains(c) else { throw CubeError.invalid("Há adesivos sem cor definida.") }
            counts[c] += 1
        }
        if let bad = counts.firstIndex(where: { $0 != n * n }) {
            throw CubeError.invalid("Cada cor deve aparecer exatamente \(n * n) vezes (uma cor aparece \(counts[bad]) vezes).")
        }
        let scheme = try colorScheme(input, geo)
        var state = input
        var stages: [(String, [Move])] = []

        let lib: BigCubeLibrary? = n >= 4 ? BigCubeLibrary.of(n) : nil
        if let lib {
            // 1. Centros: busca livre e depois comutadores que só preservam centros.
            var centerMoves = freeCenters(&state, scheme, geo)
            // Paridade das arestas (comutadores não mudam a paridade, então corrigimos agora).
            for orbit in lib.wingOrbits {
                let ids = try orbit.wingIdentities(state, scheme)
                if Perm.parity(ids) == 1 { centerMoves.append(orbit.parityMove); state.apply(orbit.parityMove) }
            }
            for orbit in lib.centerOrbits {
                try orbit.checkCenterCounts(state, scheme)
                centerMoves += try orbit.solveCenters(&state, scheme, loose: true)
            }
            stages.append(("Centros", centerMoves))
        }

        // 2. Cantos (pares) ou estrutura 3x3 (ímpares)
        let f3 = facelets3(state, geo, scheme)
        if n % 2 == 0 {
            let cc = try toCubie(f3, cornersOnly: true)
            let sol = PocketSolver.shared.solve(cc).map { Move(Face(rawValue: $0 / 3)!, 1, $0 % 3 + 1) }
            stages.append((n == 2 ? "Solução" : "Cantos", sol))
            state.apply(sol)
        } else {
            let cc = try toCubie(f3, cornersOnly: false)
            let sol = Kociemba.shared.solve(cc).map { Move(Face(rawValue: $0 / 3)!, 1, $0 % 3 + 1) }
            stages.append((n == 3 ? "Solução" : "Cantos e arestas centrais (como 3x3)", sol))
            state.apply(sol)
        }

        if let lib {
            // 3. Arestas com 3-ciclos puros (não mexem em mais nada).
            var wingMoves: [Move] = []
            for orbit in lib.wingOrbits {
                if Perm.parity(try orbit.wingIdentities(state, scheme)) == 1 {
                    throw CubeError.invalid("Falha interna (paridade).")
                }
                wingMoves += try orbit.solveWings(&state, scheme)
            }
            stages.append(("Arestas", wingMoves))
        }

        // Verificação final
        for s in 0..<state.stickers.count where scheme[state.stickers[s]] != geo.faceOf(s) {
            throw CubeError.invalid("Não foi possível resolver: verifique se as cores foram informadas corretamente.")
        }

        // Cancela movimentos na fronteira entre etapas (ex.: "D" no fim de uma e "D'" no início da
        // seguinte). Só camadas presentes nas duas pontas são combinadas; o resto fica na própria etapa.
        var merged: [(String, [Move])] = []
        for (name, mv) in stages {
            var mv = simplify(mv, n: n)
            if var last = merged.last, let lm = last.1.last {
                let ax = Notation.canonical(lm, n: n).0
                var t = last.1.count
                while t > 0 && Notation.canonical(last.1[t - 1], n: n).0 == ax { t -= 1 }
                var amt: [Int: Int] = [:]
                for x in last.1[t...] { let c = Notation.canonical(x, n: n); amt[c.1] = c.2 }
                var rest: [Move] = []
                var k = 0
                while k < mv.count && Notation.canonical(mv[k], n: n).0 == ax {
                    let c = Notation.canonical(mv[k], n: n)
                    if let a = amt[c.1] { amt[c.1] = (a + c.2) % 4 } else { rest.append(mv[k]) }
                    k += 1
                }
                last.1 = Array(last.1[..<t]) + amt.keys.sorted().compactMap { amt[$0]! == 0 ? nil : Notation.fromCanonical(ax, $0, amt[$0]!, n: n) }
                mv = rest + mv[k...]
                merged[merged.count - 1] = last
            }
            merged.append((name, mv))
        }

        var steps: [SolutionStep] = []
        for (name, mv) in merged where !mv.isEmpty {
            for (txt, ms) in Notation.tokens(mv, n: n) {
                steps.append(SolutionStep(id: steps.count, notation: txt, moves: ms, stage: name))
            }
        }
        return steps
    }

    // MARK: Centros livres

    /// Busca gulosa (profundidade até 4) que maximiza adesivos de centro corretos.
    /// Não mexe no canto DBL (pares) nem nos centros fixos (ímpares).
    static func freeCenters(_ st: inout CubeState, _ scheme: [Face], _ geo: CubeGeometry) -> [Move] {
        let n = st.n
        let centers = (0..<geo.stickerCount).filter { geo.boundaryCount($0) == 1 && !(n % 2 == 1 && geo.pos[$0].x * geo.pos[$0].y * geo.pos[$0].z == 0 && [geo.pos[$0].x, geo.pos[$0].y, geo.pos[$0].z].filter { $0 == 0 }.count == 2) }
        var local = [Int: Int]()
        for (i, s) in centers.enumerated() { local[s] = i }
        let moves = geo.moves.filter { mv in
            if n % 2 == 1 { return mv.depth != (n + 1) / 2 }
            return !(mv.depth == 1 && [Face.D, .L, .B].contains(mv.face))
        }
        let k = centers.count
        let maps: [[Int]] = moves.map { mv in let d = geo.dest(mv); return centers.map { local[d[$0]]! } }
        let axes = moves.map { Notation.canonical($0, n: n) }
        let target = centers.map { geo.faceOf($0).rawValue }
        var cur = centers.map { scheme[st.stickers[$0]].rawValue }
        func score(_ c: [Int]) -> Int { var r = 0; for i in 0..<k where c[i] == target[i] { r += 1 }; return r }

        var out: [Move] = []
        var bestSeq: [Int] = [], bestRatio = 0.0
        var path: [Int] = []
        var base = 0
        func dfs(_ c: [Int], _ depth: Int) {
            if !path.isEmpty {
                let g = score(c) - base
                if g > 0 {
                    let r = Double(g) / Double(path.count)
                    if r > bestRatio + 1e-9 { bestRatio = r; bestSeq = path }
                }
            }
            if depth == 0 { return }
            var nc = c
            for mi in 0..<moves.count {
                if let l = path.last {
                    // mesmo eixo: só em ordem crescente de camada, sem repetir
                    if axes[l].0 == axes[mi].0 && axes[l].1 >= axes[mi].1 { continue }
                }
                let mp = maps[mi]
                for i in 0..<k { nc[mp[i]] = c[i] }
                path.append(mi)
                dfs(nc, depth - 1)
                path.removeLast()
            }
        }
        for _ in 0..<60 {
            base = score(cur)
            if base == k { break }
            bestSeq = []; bestRatio = 0
            dfs(cur, 3)
            if bestSeq.isEmpty || bestRatio < 0.5 {
                let r3 = bestRatio, s3 = bestSeq
                dfs(cur, 4)
                if bestSeq.isEmpty || (bestRatio <= r3 && s3.isEmpty) { break }
            }
            for mi in bestSeq {
                var nc = cur
                for i in 0..<k { nc[maps[mi][i]] = cur[i] }
                cur = nc
                out.append(moves[mi])
            }
        }
        st.apply(out)
        return out
    }

    // MARK: Esquema de cores

    /// cor -> face
    static func colorScheme(_ st: CubeState, _ geo: CubeGeometry) throws -> [Face] {
        let n = st.n, m = n - 1
        var scheme = Array(repeating: Face.U, count: 6)
        if n % 2 == 1 {
            var seen = Set<Int>()
            for f in Face.allCases {
                let c = st.stickers[geo.sticker(f, n / 2, n / 2)]
                seen.insert(c); scheme[c] = f
            }
            if seen.count != 6 { throw CubeError.invalid("Os centros fixos devem ter 6 cores diferentes.") }
            return scheme
        }
        // Pares: deduz os opostos a partir dos cantos e fixa o canto DBL.
        var together = Array(repeating: Array(repeating: false, count: 6), count: 6)
        for x in [-m, m] { for y in [-m, m] { for z in [-m, m] {
            let p = V3(x, y, z)
            let cs = [V3(x.signum(), 0, 0), V3(0, y.signum(), 0), V3(0, 0, z.signum())].map { st.stickers[geo.stickerAt(p, $0)] }
            for a in cs { for b in cs where a != b { together[a][b] = true } }
            if Set(cs).count != 3 { throw CubeError.invalid("Um canto tem cores repetidas.") }
        } } }
        var opp = Array(repeating: -1, count: 6)
        for a in 0..<6 {
            let cands = (0..<6).filter { $0 != a && !together[a][$0] }
            if cands.count != 1 { throw CubeError.invalid("As cores dos cantos não formam um cubo válido.") }
            opp[a] = cands[0]
        }
        let p = V3(-m, -m, -m)
        let d = st.stickers[geo.stickerAt(p, Face.D.normal)]
        let b = st.stickers[geo.stickerAt(p, Face.B.normal)]
        let l = st.stickers[geo.stickerAt(p, Face.L.normal)]
        scheme[d] = .D; scheme[opp[d]] = .U
        scheme[b] = .B; scheme[opp[b]] = .F
        scheme[l] = .L; scheme[opp[l]] = .R
        return scheme
    }

    /// Reduz o cubo grande a 54 facelets de 3x3 (cantos, arestas centrais e centros fixos).
    static func facelets3(_ st: CubeState, _ geo: CubeGeometry, _ scheme: [Face]) -> [Face] {
        let n = st.n
        func r(_ i: Int) -> Int { i == 0 ? 0 : (i == 2 ? n - 1 : n / 2) }
        var out: [Face] = []
        for f in Face.allCases {
            for i in 0..<3 { for j in 0..<3 {
                if n % 2 == 0 && (i == 1 || j == 1) { out.append(f) } // não usado
                else { out.append(scheme[st.stickers[geo.sticker(f, r(i), r(j))]]) }
            } }
        }
        return out
    }

    static let cornerFacelet: [[Int]] = [[8, 9, 20], [6, 18, 38], [0, 36, 47], [2, 45, 11],
                                         [29, 26, 15], [27, 44, 24], [33, 53, 42], [35, 17, 51]]
    static let edgeFacelet: [[Int]] = [[5, 10], [7, 19], [3, 37], [1, 46], [32, 16], [28, 25],
                                       [30, 43], [34, 52], [23, 12], [21, 41], [50, 39], [48, 14]]
    static let cornerColor: [[Face]] = [[.U, .R, .F], [.U, .F, .L], [.U, .L, .B], [.U, .B, .R],
                                        [.D, .F, .R], [.D, .L, .F], [.D, .B, .L], [.D, .R, .B]]
    static let edgeColor: [[Face]] = [[.U, .R], [.U, .F], [.U, .L], [.U, .B], [.D, .R], [.D, .F],
                                      [.D, .L], [.D, .B], [.F, .R], [.F, .L], [.B, .L], [.B, .R]]

    static func toCubie(_ f: [Face], cornersOnly: Bool) throws -> CubieCube {
        var c = CubieCube()
        for i in 0..<8 {
            guard let ori = (0..<3).first(where: { f[cornerFacelet[i][$0]] == .U || f[cornerFacelet[i][$0]] == .D }) else {
                throw CubeError.invalid("Há um canto com cores impossíveis.")
            }
            let c1 = f[cornerFacelet[i][(ori + 1) % 3]], c2 = f[cornerFacelet[i][(ori + 2) % 3]]
            guard let j = (0..<8).first(where: { cornerColor[$0][1] == c1 && cornerColor[$0][2] == c2 }) else {
                throw CubeError.invalid("Há um canto com cores impossíveis (verifique a ordem das cores).")
            }
            c.cp[i] = j; c.co[i] = ori
        }
        if Set(c.cp).count != 8 { throw CubeError.invalid("Há cantos repetidos.") }
        if c.co.reduce(0, +) % 3 != 0 { throw CubeError.invalid("Um canto está torcido: esse estado é impossível de resolver.") }
        if cornersOnly { return c }
        for i in 0..<12 {
            let a = f[edgeFacelet[i][0]], b = f[edgeFacelet[i][1]]
            if let j = (0..<12).first(where: { edgeColor[$0] == [a, b] }) {
                c.ep[i] = j; c.eo[i] = 0
            } else if let j = (0..<12).first(where: { edgeColor[$0] == [b, a] }) {
                c.ep[i] = j; c.eo[i] = 1
            } else {
                throw CubeError.invalid("Há uma aresta com cores impossíveis.")
            }
        }
        if Set(c.ep).count != 12 { throw CubeError.invalid("Há arestas repetidas.") }
        if c.eo.reduce(0, +) % 2 != 0 { throw CubeError.invalid("Uma aresta está invertida: esse estado é impossível de resolver.") }
        if c.cornerParity != c.edgeParity { throw CubeError.invalid("Duas peças estão trocadas: esse estado é impossível de resolver.") }
        return c
    }

    // MARK: Simplificação

    /// Junta movimentos consecutivos no mesmo eixo.
    static func simplify(_ seq: [Move], n: Int) -> [Move] {
        struct Run { var axis: Int; var amt: [Int: Int] }
        var runs: [Run] = []
        for mv in seq {
            let (axis, layer, a) = Notation.canonical(mv, n: n)
            if var last = runs.last, last.axis == axis {
                last.amt[layer] = ((last.amt[layer] ?? 0) + a) % 4
                if last.amt[layer] == 0 { last.amt[layer] = nil }
                runs.removeLast()
                if !last.amt.isEmpty { runs.append(last) }
            } else {
                runs.append(Run(axis: axis, amt: [layer: a]))
            }
        }
        var out: [Move] = []
        for r in runs {
            for layer in r.amt.keys.sorted() {
                out.append(Notation.fromCanonical(r.axis, layer, r.amt[layer]!, n: n))
            }
        }
        return out
    }
}

public enum Notation {
    static let posFaces: [Face] = [.R, .U, .F]

    /// (eixo, camada a partir da face positiva, quartos de volta no sentido da face positiva)
    static func canonical(_ mv: Move, n: Int) -> (Int, Int, Int) {
        switch mv.face {
        case .R: return (0, mv.depth - 1, mv.amount)
        case .U: return (1, mv.depth - 1, mv.amount)
        case .F: return (2, mv.depth - 1, mv.amount)
        case .L: return (0, n - mv.depth, 4 - mv.amount)
        case .D: return (1, n - mv.depth, 4 - mv.amount)
        case .B: return (2, n - mv.depth, 4 - mv.amount)
        }
    }

    static func fromCanonical(_ axis: Int, _ layer: Int, _ a: Int, n: Int) -> Move {
        if layer < (n + 1) / 2 { return Move(posFaces[axis], layer + 1, a) }
        return Move(posFaces[axis].opposite, n - layer, 4 - a)
    }

    static let faceName: [Face: String] = [.U: "de Cima", .D: "de Baixo", .R: "da Direita", .L: "da Esquerda", .F: "da Frente", .B: "de Trás"]
    static let faceShort: [Face: String] = [.U: "Cima", .D: "Baixo", .R: "Direita", .L: "Esquerda", .F: "Frente", .B: "Trás"]

    /// Descrição em português de um passo.
    public static func describe(_ step: SolutionStep, n: Int) -> String {
        guard let mv = step.moves.first else { return "" }
        let dir: String
        switch mv.amount {
        case 1: dir = "90° no sentido horário"
        case 2: dir = "180° (meia volta)"
        default: dir = "90° no sentido anti-horário"
        }
        let look = "olhando de frente para a face \(faceShort[mv.face]!)"
        if step.moves.count > 1 {
            return "Gire juntas as \(step.moves.count) camadas \(faceName[mv.face]!) \(dir), \(look)."
        }
        if n % 2 == 1 && mv.depth == (n + 1) / 2 && n > 1 {
            return "Gire só a camada do meio (entre \(faceShort[mv.face]!) e \(faceShort[mv.face.opposite]!)) \(dir), \(look)."
        }
        if mv.depth == 1 {
            return "Gire a face \(faceShort[mv.face]!) \(dir), \(look)."
        }
        return "Gire só a \(mv.depth)ª camada a partir da face \(faceShort[mv.face]!) (sem a face externa) \(dir), \(look)."
    }

    static func suffix(_ a: Int) -> String { a == 1 ? "" : (a == 2 ? "2" : "'") }

    public static func name(_ mv: Move, n: Int) -> String {
        if n % 2 == 1 && mv.depth == (n + 1) / 2 {
            switch mv.face {
            case .R: return "M" + suffix(4 - mv.amount)
            case .L: return "M" + suffix(mv.amount)
            case .U: return "E" + suffix(4 - mv.amount)
            case .D: return "E" + suffix(mv.amount)
            case .F: return "S" + suffix(mv.amount)
            case .B: return "S" + suffix(4 - mv.amount)
            }
        }
        return (mv.depth == 1 ? "" : "\(mv.depth)") + mv.face.letter + suffix(mv.amount)
    }

    /// Agrupa uma sequência já simplificada em passos legíveis (com movimentos largos, ex. Rw).
    static func tokens(_ seq: [Move], n: Int) -> [(String, [Move])] {
        var out: [(String, [Move])] = []
        var i = 0
        while i < seq.count {
            let axis = canonical(seq[i], n: n).0
            var group: [Move] = []
            while i < seq.count && canonical(seq[i], n: n).0 == axis { group.append(seq[i]); i += 1 }
            // separa por face
            for face in [posFaces[axis], posFaces[axis].opposite] {
                var byDepth: [Int: Move] = [:]
                for mv in group where mv.face == face { byDepth[mv.depth] = mv }
                guard !byDepth.isEmpty else { continue }
                var start = 1
                if let outer = byDepth[1] {
                    var k = 1
                    while k + 1 <= n / 2, let nx = byDepth[k + 1], nx.amount == outer.amount { k += 1 }
                    if k >= 2 {
                        let ms = (1...k).map { byDepth[$0]! }
                        out.append(((k == 2 ? "" : "\(k)") + face.letter + "w" + suffix(outer.amount), ms))
                        start = k + 1
                    }
                }
                for d in byDepth.keys.sorted() where d >= start {
                    out.append((name(byDepth[d]!, n: n), [byDepth[d]!]))
                }
            }
        }
        return out
    }
}
