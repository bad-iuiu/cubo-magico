import AppKit
// Desenha um ícone simples de cubo isométrico 3x3.
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: size - 80, height: size - 80), xRadius: 200, yRadius: 200).fill()
let c = CGPoint(x: size / 2, y: size / 2 - 20)
let s: CGFloat = 330
let up = CGVector(dx: 0, dy: s), right = CGVector(dx: s * 0.866, dy: -s * 0.5), left = CGVector(dx: -s * 0.866, dy: -s * 0.5)
func face(_ o: CGPoint, _ a: CGVector, _ b: CGVector, _ colors: [NSColor]) {
    for i in 0..<3 { for j in 0..<3 {
        let p0 = CGPoint(x: o.x + a.dx * CGFloat(i) / 3 + b.dx * CGFloat(j) / 3, y: o.y + a.dy * CGFloat(i) / 3 + b.dy * CGFloat(j) / 3)
        let path = CGMutablePath()
        let inset: CGFloat = 0.08
        func pt(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: p0.x + a.dx / 3 * u + b.dx / 3 * v, y: p0.y + a.dy / 3 * u + b.dy / 3 * v) }
        path.move(to: pt(inset, inset)); path.addLine(to: pt(1 - inset, inset)); path.addLine(to: pt(1 - inset, 1 - inset)); path.addLine(to: pt(inset, 1 - inset)); path.closeSubpath()
        ctx.addPath(path); ctx.setFillColor(colors[(i * 3 + j) % colors.count].cgColor); ctx.fillPath()
    } }
}
let w = NSColor.white, g = NSColor(red: 0.05, green: 0.62, blue: 0.28, alpha: 1), r = NSColor(red: 0.85, green: 0.1, blue: 0.12, alpha: 1)
let y = NSColor(red: 1, green: 0.84, blue: 0, alpha: 1), o = NSColor(red: 1, green: 0.47, blue: 0, alpha: 1), b = NSColor(red: 0, green: 0.32, blue: 0.8, alpha: 1)
face(CGPoint(x: c.x, y: c.y), right, up, [r, r, b, r, r, r, y, r, r])            // direita
face(CGPoint(x: c.x, y: c.y), left, up, [g, g, g, o, g, g, g, g, w])             // esquerda
face(CGPoint(x: c.x, y: c.y + s), CGVector(dx: -right.dx, dy: -right.dy), CGVector(dx: -left.dx, dy: -left.dy), [w, w, w, w, w, y, w, w, w]) // topo
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
