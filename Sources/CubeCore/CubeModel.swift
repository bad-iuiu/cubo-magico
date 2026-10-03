import Foundation

/// Faces na ordem usada por Kociemba: U R F D L B.
public enum Face: Int, CaseIterable, Sendable {
    case U = 0, R, F, D, L, B

    public var letter: String { ["U", "R", "F", "D", "L", "B"][rawValue] }

    var normal: V3 {
        switch self {
        case .U: return V3(0, 1, 0)
        case .D: return V3(0, -1, 0)
        case .R: return V3(1, 0, 0)
        case .L: return V3(-1, 0, 0)
        case .F: return V3(0, 0, 1)
        case .B: return V3(0, 0, -1)
        }
    }

    static func from(normal n: V3) -> Face {
        Face.allCases.first { $0.normal == n }!
    }

    public var opposite: Face {
        switch self {
        case .U: return .D
        case .D: return .U
        case .R: return .L
        case .L: return .R
        case .F: return .B
        case .B: return .F
        }
    }
}

struct V3: Hashable {
    var x: Int, y: Int, z: Int
    init(_ x: Int, _ y: Int, _ z: Int) { self.x = x; self.y = y; self.z = z }
    static func * (k: Int, v: V3) -> V3 { V3(k * v.x, k * v.y, k * v.z) }
    static func + (a: V3, b: V3) -> V3 { V3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: V3, b: V3) -> V3 { V3(a.x - b.x, a.y - b.y, a.z - b.z) }
    func dot(_ b: V3) -> Int { x * b.x + y * b.y + z * b.z }
    func cross(_ b: V3) -> V3 { V3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
    /// Rotação horária (vista de fora) em torno do eixo unitário n.
    func rotCW(_ n: V3) -> V3 { n.dot(self) * n - n.cross(self) }
}

/// Movimento de uma única camada: `depth` = 1 é a camada externa da face.
public struct Move: Hashable, Sendable {
    public var face: Face
    public var depth: Int
    public var amount: Int // 1 = horário, 2 = meia volta, 3 = anti-horário

    public init(_ face: Face, _ depth: Int = 1, _ amount: Int = 1) {
        self.face = face; self.depth = depth; self.amount = amount
    }

    public var inverse: Move { Move(face, depth, 4 - amount) }
}

/// Geometria de um cubo NxN: posição de cada adesivo e permutações dos movimentos.
public final class CubeGeometry: @unchecked Sendable {
    public let n: Int
    let m: Int
    public let stickerCount: Int
    let pos: [V3]       // posição do cubinho de cada adesivo
    let normal: [V3]
    private var index: [V3: [V3: Int]] = [:]
    /// Todos os movimentos de uma camada (sem duplicar a camada do meio).
    public let moves: [Move]
    private var destCache: [Move: [Int]] = [:]
    private let lock = NSLock()

    private static var cache: [Int: CubeGeometry] = [:]
    private static let cacheLock = NSLock()

    public static func of(_ n: Int) -> CubeGeometry {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let g = cache[n] { return g }
        let g = CubeGeometry(n: n)
        cache[n] = g
        return g
    }

    private init(n: Int) {
        self.n = n
        self.m = n - 1
        self.stickerCount = 6 * n * n
        var pos: [V3] = [], normal: [V3] = []
        for f in Face.allCases {
            for r in 0..<n {
                for c in 0..<n {
                    let p = CubeGeometry.position(f, r, c, m: n - 1)
                    pos.append(p); normal.append(f.normal)
                }
            }
        }
        self.pos = pos; self.normal = normal
        for i in 0..<pos.count { index[pos[i], default: [:]][normal[i]] = i }
        var mv: [Move] = []
        let half = n / 2
        for f in Face.allCases {
            for d in 1...half {
                for a in 1...3 { mv.append(Move(f, d, a)) }
            }
        }
        if n % 2 == 1 && n > 1 {
            for f in [Face.R, .U, .F] { for a in 1...3 { mv.append(Move(f, half + 1, a)) } }
        }
        self.moves = mv
    }

    static func position(_ f: Face, _ r: Int, _ c: Int, m: Int) -> V3 {
        switch f {
        case .U: return V3(-m + 2 * c, m, -m + 2 * r)
        case .D: return V3(-m + 2 * c, -m, m - 2 * r)
        case .F: return V3(-m + 2 * c, m - 2 * r, m)
        case .B: return V3(m - 2 * c, m - 2 * r, -m)
        case .R: return V3(m, m - 2 * r, m - 2 * c)
        case .L: return V3(-m, m - 2 * r, -m + 2 * c)
        }
    }

    public func sticker(_ f: Face, _ r: Int, _ c: Int) -> Int { f.rawValue * n * n + r * n + c }
    public func faceOf(_ s: Int) -> Face { Face(rawValue: s / (n * n))! }

    func stickerAt(_ p: V3, _ nrm: V3) -> Int { index[p]![nrm]! }

    /// dest[i] = para onde vai o adesivo i.
    public func dest(_ mv: Move) -> [Int] {
        lock.lock(); defer { lock.unlock() }
        if let d = destCache[mv] { return d }
        let ax = mv.face.normal
        let layer = m - 2 * (mv.depth - 1)
        var d = Array(0..<stickerCount)
        for i in 0..<stickerCount where ax.dot(pos[i]) == layer {
            var p = pos[i], q = normal[i]
            for _ in 0..<mv.amount { p = p.rotCW(ax); q = q.rotCW(ax) }
            d[i] = stickerAt(p, q)
        }
        destCache[mv] = d
        return d
    }

    /// Permutação combinada (dest) de uma sequência.
    public func dest(_ seq: [Move]) -> [Int] {
        var d = Array(0..<stickerCount)
        for mv in seq {
            let md = dest(mv)
            for i in 0..<stickerCount { d[i] = md[d[i]] }
        }
        return d
    }

    /// Quantas coordenadas estão na borda (3 = canto, 2 = aresta, 1 = centro).
    func boundaryCount(_ s: Int) -> Int {
        let p = pos[s]
        return [p.x, p.y, p.z].filter { abs($0) == m }.count
    }
}

public struct CubeState: Equatable, Sendable {
    public let n: Int
    public var stickers: [Int] // índice de cor por adesivo

    public init(n: Int, stickers: [Int]) { self.n = n; self.stickers = stickers }

    /// Cubo resolvido em que a cor i está na face i.
    public static func solved(_ n: Int) -> CubeState {
        CubeState(n: n, stickers: (0..<6 * n * n).map { $0 / (n * n) })
    }

    public mutating func apply(_ mv: Move) {
        let d = CubeGeometry.of(n).dest(mv)
        var out = stickers
        for i in 0..<stickers.count { out[d[i]] = stickers[i] }
        stickers = out
    }

    public mutating func apply(_ seq: [Move]) { for mv in seq { apply(mv) } }

    public func applying(_ seq: [Move]) -> CubeState { var s = self; s.apply(seq); return s }

    public var isSolved: Bool {
        let nn = n * n
        for f in 0..<6 {
            let c = stickers[f * nn]
            for i in 0..<nn where stickers[f * nn + i] != c { return false }
        }
        return true
    }
}

extension CubeState {
    /// Embaralhamento aleatório (reprodutível com seed).
    public static func scrambled(_ n: Int, seed: UInt64? = nil, length: Int? = nil) -> CubeState {
        var rng = SplitMix(seed: seed ?? UInt64.random(in: 1...UInt64.max))
        let moves = CubeGeometry.of(n).moves.filter { n % 2 == 0 || $0.depth != (n + 1) / 2 } // mantém os centros fixos
        var s = CubeState.solved(n)
        for _ in 0..<(length ?? 25 * (n - 1)) { s.apply(moves[Int(rng.next() % UInt64(moves.count))]) }
        return s
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: API para a interface
extension CubeGeometry {
    /// Centro do adesivo (cubinhos de tamanho 1, cubo centrado na origem) e normal.
    public func stickerFrame(_ s: Int) -> (center: SIMD3<Float>, normal: SIMD3<Float>) {
        let p = pos[s], q = normal[s]
        let nrm = SIMD3<Float>(Float(q.x), Float(q.y), Float(q.z))
        return (SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z)) * 0.5 + nrm * 0.5, nrm)
    }

    /// Adesivos que giram com o movimento.
    public func stickers(in mv: Move) -> [Int] {
        let ax = mv.face.normal
        let layer = m - 2 * (mv.depth - 1)
        return (0..<stickerCount).filter { ax.dot(pos[$0]) == layer }
    }
}

extension Face {
    public var axis: SIMD3<Float> { SIMD3<Float>(Float(normal.x), Float(normal.y), Float(normal.z)) }
}
