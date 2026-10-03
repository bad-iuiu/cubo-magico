import Foundation

// Cantos: URF UFL ULB UBR DFR DLF DBL DRB
// Arestas: UR UF UL UB DR DF DL DB FR FL BL BR
struct CubieCube {
    var cp: [Int] = Array(0..<8)
    var co: [Int] = Array(repeating: 0, count: 8)
    var ep: [Int] = Array(0..<12)
    var eo: [Int] = Array(repeating: 0, count: 12)

    /// self * b (aplica b depois de self)
    func multiply(_ b: CubieCube) -> CubieCube {
        var r = CubieCube()
        for i in 0..<8 {
            r.cp[i] = cp[b.cp[i]]
            r.co[i] = (co[b.cp[i]] + b.co[i]) % 3
        }
        for i in 0..<12 {
            r.ep[i] = ep[b.ep[i]]
            r.eo[i] = (eo[b.ep[i]] + b.eo[i]) % 2
        }
        return r
    }

    static let basic: [CubieCube] = [
        // U
        CubieCube(cp: [3, 0, 1, 2, 4, 5, 6, 7], co: [0, 0, 0, 0, 0, 0, 0, 0],
                  ep: [3, 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11], eo: Array(repeating: 0, count: 12)),
        // R
        CubieCube(cp: [4, 1, 2, 0, 7, 5, 6, 3], co: [2, 0, 0, 1, 1, 0, 0, 2],
                  ep: [8, 1, 2, 3, 11, 5, 6, 7, 4, 9, 10, 0], eo: Array(repeating: 0, count: 12)),
        // F
        CubieCube(cp: [1, 5, 2, 3, 0, 4, 6, 7], co: [1, 2, 0, 0, 2, 1, 0, 0],
                  ep: [0, 9, 2, 3, 4, 8, 6, 7, 1, 5, 10, 11], eo: [0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0]),
        // D
        CubieCube(cp: [0, 1, 2, 3, 5, 6, 7, 4], co: [0, 0, 0, 0, 0, 0, 0, 0],
                  ep: [0, 1, 2, 3, 5, 6, 7, 4, 8, 9, 10, 11], eo: Array(repeating: 0, count: 12)),
        // L
        CubieCube(cp: [0, 2, 6, 3, 4, 1, 5, 7], co: [0, 1, 2, 0, 0, 2, 1, 0],
                  ep: [0, 1, 10, 3, 4, 5, 9, 7, 8, 2, 6, 11], eo: Array(repeating: 0, count: 12)),
        // B
        CubieCube(cp: [0, 1, 3, 7, 4, 5, 2, 6], co: [0, 0, 1, 2, 0, 0, 2, 1],
                  ep: [0, 1, 2, 11, 4, 5, 6, 10, 8, 9, 3, 7], eo: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1]),
    ]

    /// 18 movimentos: face*3 + (quantidade-1)
    static let moves18: [CubieCube] = {
        var out: [CubieCube] = []
        for f in 0..<6 {
            var c = CubieCube()
            for _ in 0..<3 { c = c.multiply(basic[f]); out.append(c) }
        }
        return out
    }()

    // Coordenadas
    var twist: Int { var r = 0; for i in 0..<7 { r = 3 * r + co[i] }; return r }
    mutating func setTwist(_ v: Int) {
        var v = v, s = 0
        for i in stride(from: 6, through: 0, by: -1) { co[i] = v % 3; s += co[i]; v /= 3 }
        co[7] = (3 - s % 3) % 3
    }
    var flip: Int { var r = 0; for i in 0..<11 { r = 2 * r + eo[i] }; return r }
    mutating func setFlip(_ v: Int) {
        var v = v, s = 0
        for i in stride(from: 10, through: 0, by: -1) { eo[i] = v % 2; s += eo[i]; v /= 2 }
        eo[11] = s % 2
    }
    var slice: Int {
        var mask = 0
        for i in 0..<12 where ep[i] >= 8 { mask |= 1 << i }
        return Comb.index[mask]
    }
    mutating func setSlice(_ v: Int) {
        let mask = Comb.masks[v]
        var s = 8, o = 0
        for i in 0..<12 {
            if mask & (1 << i) != 0 { ep[i] = s; s += 1 } else { ep[i] = o; o += 1 }
        }
    }
    var cornerPerm: Int { Perm.rank(cp) }
    mutating func setCornerPerm(_ v: Int) { cp = Perm.unrank(v, 8) }
    var udEdgePerm: Int { Perm.rank(Array(ep[0..<8])) }
    mutating func setUDEdgePerm(_ v: Int) { ep = Perm.unrank(v, 8) + [8, 9, 10, 11] }
    var slicePerm: Int { Perm.rank(ep[8..<12].map { $0 - 8 }) }
    mutating func setSlicePerm(_ v: Int) { ep = Array(0..<8) + Perm.unrank(v, 4).map { $0 + 8 } }

    var cornerParity: Int { Perm.parity(cp) }
    var edgeParity: Int { Perm.parity(ep) }
}

enum Comb {
    static let masks: [Int] = (0..<4096).filter { $0.nonzeroBitCount == 4 }
    static let index: [Int] = {
        var idx = Array(repeating: -1, count: 4096)
        for (i, m) in masks.enumerated() { idx[m] = i }
        return idx
    }()
    static let solvedSlice = index[0xF00]
}

enum Perm {
    static func rank(_ p: [Int]) -> Int {
        var r = 0
        let n = p.count
        for i in 0..<n {
            var c = 0
            for j in (i + 1)..<max(n, i + 1) where p[j] < p[i] { c += 1 }
            r = r * (n - i) + c
        }
        return r
    }
    static func unrank(_ v: Int, _ n: Int) -> [Int] {
        var digits = Array(repeating: 0, count: n)
        var v = v
        for i in stride(from: n - 1, through: 0, by: -1) {
            digits[i] = v % (n - i); v /= (n - i)
        }
        var avail = Array(0..<n)
        var out: [Int] = []
        for i in 0..<n { out.append(avail.remove(at: digits[i])) }
        return out
    }
    static func parity(_ p: [Int]) -> Int {
        var s = 0
        for i in 0..<p.count { for j in (i + 1)..<max(p.count, i + 1) where p[j] < p[i] { s += 1 } }
        return s % 2
    }
}

public enum CubeError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let s): return s }
    }
}

/// Algoritmo de duas fases de Kociemba (sem redução por simetria).
final class Kociemba: @unchecked Sendable {
    static let shared = Kociemba()

    static let p2Moves = [0, 1, 2, 4, 7, 9, 10, 11, 13, 16]

    let twistMove: [Int32], flipMove: [Int32], sliceMove: [Int32]
    let cpMove: [Int32], udMove: [Int32], spMove: [Int32]
    let pruneTwistSlice: [Int8], pruneFlipSlice: [Int8]
    let pruneCpSp: [Int8], pruneUdSp: [Int8]

    private init() {
        func table(_ count: Int, _ moves: [Int], _ set: (inout CubieCube, Int) -> Void, _ get: (CubieCube) -> Int) -> [Int32] {
            var t = [Int32](repeating: 0, count: count * moves.count)
            for v in 0..<count {
                var c = CubieCube(); set(&c, v)
                for (k, m) in moves.enumerated() {
                    t[v * moves.count + k] = Int32(get(c.multiply(CubieCube.moves18[m])))
                }
            }
            return t
        }
        let all = Array(0..<18)
        twistMove = table(2187, all, { $0.setTwist($1) }, { $0.twist })
        flipMove = table(2048, all, { $0.setFlip($1) }, { $0.flip })
        sliceMove = table(495, all, { $0.setSlice($1) }, { $0.slice })
        let p2 = Kociemba.p2Moves
        cpMove = table(40320, p2, { $0.setCornerPerm($1) }, { $0.cornerPerm })
        udMove = table(40320, p2, { $0.setUDEdgePerm($1) }, { $0.udEdgePerm })
        spMove = table(24, p2, { $0.setSlicePerm($1) }, { $0.slicePerm })

        func bfs(_ sizeA: Int, _ sizeB: Int, _ start: Int, _ nm: Int, _ ta: [Int32], _ tb: [Int32]) -> [Int8] {
            var dist = [Int8](repeating: -1, count: sizeA * sizeB)
            var queue = [Int32](repeating: 0, count: sizeA * sizeB)
            dist[start] = 0; queue[0] = Int32(start)
            var head = 0, tail = 1
            while head < tail {
                let s = Int(queue[head]); head += 1
                let a = s / sizeB, b = s % sizeB
                let d = dist[s]
                for k in 0..<nm {
                    let ns = Int(ta[a * nm + k]) * sizeB + Int(tb[b * nm + k])
                    if dist[ns] < 0 { dist[ns] = d + 1; queue[tail] = Int32(ns); tail += 1 }
                }
            }
            return dist
        }
        pruneTwistSlice = bfs(2187, 495, Comb.solvedSlice, 18, twistMove, sliceMove)
        pruneFlipSlice = bfs(2048, 495, Comb.solvedSlice, 18, flipMove, sliceMove)
        pruneCpSp = bfs(40320, 24, 0, 10, cpMove, spMove)
        pruneUdSp = bfs(40320, 24, 0, 10, udMove, spMove)
    }

    // MARK: busca

    private var path: [Int] = []
    private var best: [Int]? = nil
    private var maxLen = 0
    private var deadline = Date()
    private var start = CubieCube()
    private var nodes = 0
    private var timedOut = false

    /// Resolve e devolve movimentos no formato face*3 + (quantidade-1).
    func solve(_ cube: CubieCube, timeLimit: TimeInterval = 1.0) -> [Int] {
        start = cube
        best = nil
        maxLen = 30
        path = []
        timedOut = false
        nodes = 0
        let hardDeadline = Date().addingTimeInterval(20)
        deadline = Date().addingTimeInterval(timeLimit)
        var d1 = 0
        while d1 <= maxLen {
            path = []
            phase1(cube.twist, cube.flip, cube.slice, d1, -1)
            if timedOut {
                // Sem solução ainda: continua (até o limite rígido) até achar uma.
                if best == nil && Date() < hardDeadline {
                    timedOut = false
                    deadline = hardDeadline
                    continue
                }
                break
            }
            d1 += 1
        }
        return best ?? []
    }

    private func checkTime() -> Bool {
        nodes += 1
        if nodes & 0xFFF == 0 && Date() > deadline { timedOut = true }
        return timedOut
    }

    private func phase1(_ tw: Int, _ fl: Int, _ sl: Int, _ togo: Int, _ last: Int) {
        if checkTime() { return }
        if togo == 0 {
            if tw == 0 && fl == 0 && sl == Comb.solvedSlice {
                if let l = path.last, Kociemba.p2Moves.contains(l) { return }
                startPhase2()
            }
            return
        }
        for f in 0..<6 {
            if last >= 0 && (f == last || f == last - 3) { continue }
            for a in 0..<3 {
                let m = f * 3 + a
                let ntw = Int(twistMove[tw * 18 + m]), nfl = Int(flipMove[fl * 18 + m]), nsl = Int(sliceMove[sl * 18 + m])
                let h = max(pruneTwistSlice[ntw * 495 + nsl], pruneFlipSlice[nfl * 495 + nsl])
                if Int(h) < togo {
                    path.append(m)
                    phase1(ntw, nfl, nsl, togo - 1, f)
                    path.removeLast()
                    if timedOut { return }
                }
            }
        }
    }

    private func startPhase2() {
        var c = start
        for m in path { c = c.multiply(CubieCube.moves18[m]) }
        let limit = maxLen - path.count
        if limit < 0 { return }
        let cp = c.cornerPerm, ud = c.udEdgePerm, sp = c.slicePerm
        let lastFace = path.last.map { $0 / 3 } ?? -1
        let p1len = path.count
        for d2 in 0...limit {
            if phase2(cp, ud, sp, d2, lastFace) {
                best = path
                maxLen = path.count - 1
                path.removeSubrange(p1len...)
                return
            }
            if timedOut { return }
        }
    }

    private func phase2(_ cp: Int, _ ud: Int, _ sp: Int, _ togo: Int, _ last: Int) -> Bool {
        if togo == 0 { return cp == 0 && ud == 0 && sp == 0 }
        if checkTime() { return false }
        for (k, m) in Kociemba.p2Moves.enumerated() {
            let f = m / 3
            if last >= 0 && (f == last || f == last - 3) { continue }
            let ncp = Int(cpMove[cp * 10 + k]), nud = Int(udMove[ud * 10 + k]), nsp = Int(spMove[sp * 10 + k])
            let h = max(pruneCpSp[ncp * 24 + nsp], pruneUdSp[nud * 24 + nsp])
            if Int(h) < togo {
                path.append(m)
                if phase2(ncp, nud, nsp, togo - 1, f) { return true }
                path.removeLast()
            }
        }
        return false
    }
}

/// Resolvedor ótimo de 2x2 (só cantos, DBL fixo, movimentos U R F).
final class PocketSolver: @unchecked Sendable {
    static let shared = PocketSolver()
    static let moveIdx = [0, 1, 2, 3, 4, 5, 6, 7, 8] // U U2 U' R R2 R' F F2 F'
    let permMove: [Int32], twistMove: [Int32]
    let dist: [Int8]

    static let posIdx = [0, 1, 2, 3, 4, 5, 7]

    static func perm7(_ c: CubieCube) -> Int {
        Perm.rank(posIdx.map { c.cp[$0] == 7 ? 6 : c.cp[$0] })
    }
    static func setPerm7(_ c: inout CubieCube, _ v: Int) {
        let p = Perm.unrank(v, 7)
        for (k, pos) in posIdx.enumerated() { c.cp[pos] = p[k] == 6 ? 7 : p[k] }
        c.cp[6] = 6
    }
    static func twist6(_ c: CubieCube) -> Int { var r = 0; for i in 0..<6 { r = 3 * r + c.co[i] }; return r }
    static func setTwist6(_ c: inout CubieCube, _ v: Int) {
        var v = v, s = 0
        for i in stride(from: 5, through: 0, by: -1) { c.co[i] = v % 3; s += c.co[i]; v /= 3 }
        c.co[6] = 0
        c.co[7] = (3 - s % 3) % 3
    }

    private init() {
        var pm = [Int32](repeating: 0, count: 5040 * 9)
        var tm = [Int32](repeating: 0, count: 729 * 9)
        for v in 0..<5040 {
            var c = CubieCube(); PocketSolver.setPerm7(&c, v)
            for k in 0..<9 { pm[v * 9 + k] = Int32(PocketSolver.perm7(c.multiply(CubieCube.moves18[k]))) }
        }
        for v in 0..<729 {
            var c = CubieCube(); PocketSolver.setTwist6(&c, v)
            for k in 0..<9 { tm[v * 9 + k] = Int32(PocketSolver.twist6(c.multiply(CubieCube.moves18[k]))) }
        }
        permMove = pm; twistMove = tm
        var d = [Int8](repeating: -1, count: 5040 * 729)
        var q = [Int32](repeating: 0, count: 5040 * 729)
        d[0] = 0
        var head = 0, tail = 1
        while head < tail {
            let s = Int(q[head]); head += 1
            let p = s / 729, t = s % 729
            for k in 0..<9 {
                let ns = Int(pm[p * 9 + k]) * 729 + Int(tm[t * 9 + k])
                if d[ns] < 0 { d[ns] = d[s] + 1; q[tail] = Int32(ns); tail += 1 }
            }
        }
        dist = d
    }

    func solve(_ c: CubieCube) -> [Int] {
        var p = PocketSolver.perm7(c), t = PocketSolver.twist6(c)
        var out: [Int] = []
        while dist[p * 729 + t] > 0 {
            let cur = dist[p * 729 + t]
            for k in 0..<9 {
                let np = Int(permMove[p * 9 + k]), nt = Int(twistMove[t * 9 + k])
                if dist[np * 729 + nt] == cur - 1 { p = np; t = nt; out.append(k); break }
            }
        }
        return out
    }
}
