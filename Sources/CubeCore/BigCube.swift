import Foundation

/// Uma órbita de peças (centros ou arestas "asa") de um cubo grande, com uma
/// biblioteca de 3-ciclos puros (comutadores conjugados) que só mexem nessa órbita.
final class Orbit: @unchecked Sendable {
    let geo: CubeGeometry
    let isWing: Bool
    /// adesivos de cada posição (ordem consistente com os movimentos)
    let slots: [[Int]]
    let slotOf: [Int: Int]
    var parityMove = Move(.R, 2, 1)

    struct Cycle { let a: Int, b: Int, c: Int; let seq: [Move] }
    var cycles: [Cycle] = []
    var looseCycles: [Cycle] = []

    init(geo: CubeGeometry, slots: [[Int]], isWing: Bool) {
        self.geo = geo; self.slots = slots; self.isWing = isWing
        var so: [Int: Int] = [:]
        for (i, s) in slots.enumerated() { for x in s { so[x] = i } }
        slotOf = so
    }

    func slotDest(_ d: [Int]) -> [Int] { slots.map { slotOf[d[$0[0]]]! } }

    /// Se a permutação d é um 3-ciclo puro desta órbita, devolve (a, b, c) com a→b→c.
    func asThreeCycle(_ d: [Int], ignore: [Bool]? = nil) -> (Int, Int, Int)? {
        var moved: [Int] = []
        for i in 0..<d.count where d[i] != i && !(ignore?[i] ?? false) {
            guard slotOf[i] != nil else { return nil }
            moved.append(i)
            if moved.count > 3 * slots[0].count { return nil }
        }
        guard moved.count == 3 * slots[0].count else { return nil }
        let a = slotOf[moved[0]]!
        let sd = { (s: Int) -> Int? in
            let t = self.slotOf[d[self.slots[s][0]]]!
            for k in 0..<self.slots[s].count where d[self.slots[s][k]] != self.slots[t][k] { return nil }
            return t
        }
        guard let b = sd(a), let c = sd(b), let a2 = sd(c), a2 == a, a != b, b != c, a != c else { return nil }
        return (a, b, c)
    }

    // MARK: resolução

    func faceColors(_ st: CubeState, _ scheme: [Face]) -> [Face] {
        slots.map { scheme[st.stickers[$0[0]]] }
    }

    func checkCenterCounts(_ st: CubeState, _ scheme: [Face]) throws {
        var cnt = [Int](repeating: 0, count: 6)
        for f in faceColors(st, scheme) { cnt[f.rawValue] += 1 }
        if cnt.contains(where: { $0 != slots.count / 6 }) {
            throw CubeError.invalid("As peças de centro não batem com um cubo válido: verifique as cores dos centros.")
        }
    }

    lazy var homeKey: [[Face]: Int] = {
        var h: [[Face]: Int] = [:]
        for (i, s) in slots.enumerated() { h[s.map { geo.faceOf($0) }] = i }
        return h
    }()

    /// Para cada posição, qual é a posição de origem da peça que está nela.
    func wingIdentities(_ st: CubeState, _ scheme: [Face]) throws -> [Int] {
        var ids: [Int] = []
        for s in slots {
            guard let h = homeKey[s.map { scheme[st.stickers[$0]] }] else {
                throw CubeError.invalid("Há uma aresta com cores impossíveis: verifique as arestas.")
            }
            ids.append(h)
        }
        if Set(ids).count != ids.count { throw CubeError.invalid("Há peças de aresta repetidas: verifique as arestas.") }
        return ids
    }

    func solveCenters(_ st: inout CubeState, _ scheme: [Face], loose: Bool = false) throws -> [Move] {
        let target = slots.map { geo.faceOf($0[0]) }
        var out: [Move] = []
        for _ in 0..<200 {
            let cur = faceColors(st, scheme)
            if cur == target { return out }
            guard let cy = bestCycle(loose ? looseCycles : cycles, { from, to in cur[from] == target[to] ? 1 : 0 }) else { break }
            out += cy.seq; st.apply(cy.seq)
        }
        throw CubeError.invalid("Falha interna ao resolver os centros.")
    }

    func solveWings(_ st: inout CubeState, _ scheme: [Face]) throws -> [Move] {
        var out: [Move] = []
        for _ in 0..<200 {
            let cur = try wingIdentities(st, scheme)
            if cur.enumerated().allSatisfy({ $0.offset == $0.element }) { return out }
            guard let cy = bestCycle(cycles, { from, to in cur[from] == to ? 1 : 0 }) else { break }
            out += cy.seq; st.apply(cy.seq)
        }
        throw CubeError.invalid("Falha interna ao resolver as arestas.")
    }

    /// Escolhe o ciclo que mais acerta peças por movimento.
    private func bestCycle(_ cycles: [Cycle], _ ok: (Int, Int) -> Int) -> Cycle? {
        var best: Cycle? = nil
        var bestScore = 0.0
        for cy in cycles {
            let gain = ok(cy.a, cy.b) + ok(cy.b, cy.c) + ok(cy.c, cy.a) - ok(cy.a, cy.a) - ok(cy.b, cy.b) - ok(cy.c, cy.c)
            if gain <= 0 { continue }
            let score = Double(gain) / Double(cy.seq.count + 4)
            if score > bestScore { bestScore = score; best = cy }
        }
        return best
    }
}

final class BigCubeLibrary: @unchecked Sendable {
    let n: Int
    let centerOrbits: [Orbit]
    let wingOrbits: [Orbit]

    private static var cache: [Int: BigCubeLibrary] = [:]
    private static let lock = NSLock()

    static func of(_ n: Int) -> BigCubeLibrary {
        lock.lock(); defer { lock.unlock() }
        if let l = cache[n] { return l }
        let l = BigCubeLibrary(n: n)
        cache[n] = l
        return l
    }

    private init(n: Int) {
        self.n = n
        let geo = CubeGeometry.of(n)
        let moves = geo.moves
        let dests = moves.map { geo.dest($0) }
        let count = geo.stickerCount
        let m = n - 1

        // Agrupa adesivos por cubinho e encontra órbitas (union-find por cubinho).
        var cubieOf: [V3: [Int]] = [:]
        for s in 0..<count { cubieOf[geo.pos[s], default: []].append(s) }
        let cubies = Array(cubieOf.keys)
        var cid: [V3: Int] = [:]
        for (i, p) in cubies.enumerated() { cid[p] = i }
        var parent = Array(0..<cubies.count)
        func find(_ x: Int) -> Int { var x = x; while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }; return x }
        for d in dests {
            for s in 0..<count {
                let a = find(cid[geo.pos[s]]!), b = find(cid[geo.pos[d[s]]]!)
                if a != b { parent[a] = b }
            }
        }
        var groups: [Int: [Int]] = [:]
        for i in 0..<cubies.count { groups[find(i), default: []].append(i) }

        var centers: [Orbit] = [], wings: [Orbit] = []
        for (_, g) in groups.sorted(by: { $0.key < $1.key }) {
            let p0 = cubies[g[0]]
            let bc = [p0.x, p0.y, p0.z].filter { abs($0) == m }.count
            let hasZero = [p0.x, p0.y, p0.z].contains(0)
            if bc == 1 {
                if [p0.x, p0.y, p0.z].filter({ $0 == 0 }).count == 2 { continue } // centro fixo
                let slots = g.flatMap { cubieOf[cubies[$0]]! }.sorted().map { [$0] }
                centers.append(Orbit(geo: geo, slots: slots, isWing: false))
            } else if bc == 2 {
                if hasZero { continue } // aresta central (tratada como 3x3)
                // Ordem consistente via BFS.
                var ordered: [V3: [Int]] = [:]
                let first = cubies[g[0]]
                ordered[first] = cubieOf[first]!.sorted()
                var queue = [first]
                while let p = queue.popLast() {
                    let st = ordered[p]!
                    for d in dests {
                        let img = st.map { d[$0] }
                        let q = geo.pos[img[0]]
                        if ordered[q] == nil { ordered[q] = img; queue.append(q) }
                    }
                }
                let slots = ordered.values.sorted { $0[0] < $1[0] }
                wings.append(Orbit(geo: geo, slots: slots, isWing: true))
            }
        }

        // Peças estritas: tudo deve ficar no lugar exceto o 3-ciclo.
        let strictCycles = BigCubeLibrary.discover(geo, orbits: centers + wings, moves: moves, ignore: nil)
        for (o, c) in zip(centers + wings, strictCycles) { o.cycles = c }
        // Centros "soltos": só os centros precisam ficar no lugar (cantos e arestas são resolvidos depois).
        // Em cubos pares o canto DBL não pode sair do lugar (ele define o esquema de cores).
        let looseMoves = moves.filter { !(n % 2 == 0 && $0.depth == 1 && [Face.D, .L, .B].contains($0.face)) }
        var ignore = [Bool](repeating: false, count: count)
        for s in 0..<count where geo.boundaryCount(s) != 1 { ignore[s] = true }
        let looseCycles = BigCubeLibrary.discover(geo, orbits: centers, moves: looseMoves, ignore: ignore)
        for (o, c) in zip(centers, looseCycles) { o.looseCycles = c }

        // Movimento de paridade para cada órbita de asas: camada interna que permuta a órbita de forma ímpar.
        for o in wings {
            for mv in moves where mv.depth > 1 && mv.amount == 1 && !(n % 2 == 1 && mv.depth == (n + 1) / 2) {
                if Perm.parity(o.slotDest(geo.dest(mv))) == 1 { o.parityMove = mv; break }
            }
        }
        centerOrbits = centers
        wingOrbits = wings
    }

    /// Descobre 3-ciclos [A, B] (A = X, X Y ou X Y X'; B = um movimento) e os conjuga
    /// com até 2 movimentos de preparação para cobrir o máximo de ciclos possível.
    /// `ignore`: adesivos que podem ficar bagunçados.
    static func discover(_ geo: CubeGeometry, orbits: [Orbit], moves: [Move], ignore: [Bool]?) -> [[Orbit.Cycle]] {
        let n = geo.n, count = geo.stickerCount
        let dests = moves.map { geo.dest($0) }
        func compose(_ a: [Int], _ b: [Int]) -> [Int] { // primeiro a, depois b
            var r = a
            for i in 0..<count { r[i] = b[a[i]] }
            return r
        }
        func inverse(_ a: [Int]) -> [Int] {
            var r = a
            for i in 0..<count { r[a[i]] = i }
            return r
        }
        let invDests = dests.map { inverse($0) }
        let axis = moves.map { Notation.canonical($0, n: n).0 }
        var base: [[(Int, Int, Int, [Move])]] = Array(repeating: [], count: orbits.count)
        func test(_ aSeq: [Move], _ aD: [Int]) {
            let aInv = inverse(aD)
            for (bi, b) in moves.enumerated() {
                let d = compose(compose(compose(aD, dests[bi]), aInv), invDests[bi])
                for (oi, o) in orbits.enumerated() {
                    if let (p, q, r) = o.asThreeCycle(d, ignore: ignore) {
                        base[oi].append((p, q, r, aSeq + [b] + aSeq.reversed().map { $0.inverse } + [b.inverse]))
                    }
                }
            }
        }
        for (xi, x) in moves.enumerated() {
            test([x], dests[xi])
            for (yi, y) in moves.enumerated() where axis[xi] != axis[yi] {
                test([x, y], compose(dests[xi], dests[yi]))
                test([x, y, x.inverse], compose(compose(dests[xi], dests[yi]), invDests[xi]))
            }
        }

        var setups: [[Move]] = [[]]
        for a in moves { setups.append([a]) }
        for (ai, a) in moves.enumerated() { for (bi, b) in moves.enumerated() where axis[ai] != axis[bi] { setups.append([a, b]) } }
        let setupDests = setups.map { geo.dest($0) }
        var result: [[Orbit.Cycle]] = []
        for (oi, o) in orbits.enumerated() {
            let k = o.slots.count
            func key(_ a: Int, _ b: Int, _ c: Int) -> Int {
                if a < b && a < c { return (a * k + b) * k + c }
                if b < c { return (b * k + c) * k + a }
                return (c * k + a) * k + b
            }
            var uniq: [Int: (Int, Int, Int, [Move])] = [:]
            for e in base[oi] {
                let kk = key(e.0, e.1, e.2)
                if uniq[kk] == nil || uniq[kk]!.3.count > e.3.count { uniq[kk] = e }
            }
            let baseList = Array(uniq.values)
            var bestLen = [Int](repeating: Int.max, count: k * k * k)
            var bestCy = [Orbit.Cycle?](repeating: nil, count: k * k * k)
            for (si, s) in setups.enumerated() {
                let sd = o.slotDest(setupDests[si])
                var inv = [Int](repeating: 0, count: k)
                for i in 0..<k { inv[sd[i]] = i }
                for e in baseList {
                    let a = inv[e.0], b = inv[e.1], c = inv[e.2]
                    let kk = key(a, b, c)
                    let len = e.3.count + 2 * s.count
                    if len < bestLen[kk] {
                        bestLen[kk] = len
                        bestCy[kk] = Orbit.Cycle(a: a, b: b, c: c, seq: s + e.3 + s.reversed().map { $0.inverse })
                    }
                }
            }
            result.append(bestCy.compactMap { $0 }.map {
                Orbit.Cycle(a: $0.a, b: $0.b, c: $0.c, seq: CubeSolver.simplify($0.seq, n: n))
            })
        }
        return result
    }
}
