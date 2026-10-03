import CubeCore
import SceneKit
import SwiftUI

/// Cena 3D do cubo, com animação das camadas.
@MainActor
final class Cube3DController {
    let scene = SCNScene()
    private let root = SCNNode()
    private var stickerNodes: [SCNNode] = []
    private var body: SCNNode?
    private var n = 0
    private var pending: CubeState?
    private var animating = false

    init() {
        scene.rootNode.addChildNode(root)
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 30
        cam.name = "camera"
        scene.rootNode.addChildNode(cam)
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .ambient
        light.light?.intensity = 900
        scene.rootNode.addChildNode(light)
        let dir = SCNNode()
        dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.intensity = 350
        dir.eulerAngles = SCNVector3(-0.6, 0.5, 0)
        scene.rootNode.addChildNode(dir)
    }

    var cameraNode: SCNNode { scene.rootNode.childNode(withName: "camera", recursively: false)! }

    private func build(_ n: Int) {
        root.childNodes.forEach { $0.removeFromParentNode() }
        stickerNodes = []
        self.n = n
        let geo = CubeGeometry.of(n)
        let size = CGFloat(n)
        let box = SCNBox(width: size * 0.995, height: size * 0.995, length: size * 0.995, chamferRadius: 0.12)
        box.firstMaterial?.diffuse.contents = NSColor(white: 0.08, alpha: 1)
        let b = SCNNode(geometry: box)
        root.addChildNode(b)
        body = b
        for s in 0..<geo.stickerCount {
            let (c, nrm) = geo.stickerFrame(s)
            let plane = SCNPlane(width: 0.86, height: 0.86)
            plane.cornerRadius = 0.1
            let mat = SCNMaterial()
            mat.lightingModel = .lambert
            mat.isDoubleSided = false
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            node.simdPosition = c + nrm * 0.003
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: nrm)
            if abs(nrm.z + 1) < 0.01 { node.simdOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0)) }
            root.addChildNode(node)
            stickerNodes.append(node)
        }
        let dist = Float(n) * 3.9
        cameraNode.simdPosition = SIMD3<Float>(dist * 0.55, dist * 0.5, dist * 0.68)
        cameraNode.look(at: SCNVector3(0, 0, 0))
    }

    func show(_ st: CubeState) {
        if animating { pending = st; return }
        if st.n != n { build(st.n) }
        for (i, node) in stickerNodes.enumerated() {
            let c = st.stickers[i]
            node.geometry?.firstMaterial?.diffuse.contents = c >= 0 ? palette[c].ns : unknownNS
        }
    }

    /// Anima os movimentos (todos no mesmo eixo, giram juntos) e depois mostra `final`.
    func animate(_ moves: [Move], n: Int, to final: CubeState, duration: Double) {
        if animating {
            // termina a animação anterior imediatamente
            finishAnimation()
        }
        guard n == self.n, let first = moves.first else { show(final); return }
        let geo = CubeGeometry.of(n)
        var nodes = Set<Int>()
        for mv in moves { nodes.formUnion(geo.stickers(in: mv)) }
        let pivot = SCNNode()
        pivot.name = "pivot"
        root.addChildNode(pivot)
        for i in nodes { pivot.addChildNode(stickerNodes[i]) }
        animating = true
        pending = final
        let angle = -CGFloat(first.amount == 3 ? -1 : first.amount) * .pi / 2
        let ax = first.face.axis
        let action = SCNAction.rotate(by: angle, around: SCNVector3(ax.x, ax.y, ax.z), duration: duration)
        action.timingMode = .easeInEaseOut
        pivot.runAction(action) { [weak self] in
            DispatchQueue.main.async { self?.finishAnimation() }
        }
    }

    private func finishAnimation() {
        guard animating else { return }
        if let pivot = root.childNode(withName: "pivot", recursively: false) {
            pivot.removeAllActions()
            let geo = CubeGeometry.of(n)
            for node in pivot.childNodes {
                node.removeFromParentNode()
                root.addChildNode(node)
            }
            pivot.removeFromParentNode()
            // reposiciona todos os adesivos
            for (s, node) in stickerNodes.enumerated() {
                let (c, nrm) = geo.stickerFrame(s)
                node.simdPosition = c + nrm * 0.003
                node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: nrm)
                if abs(nrm.z + 1) < 0.01 { node.simdOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0)) }
            }
        }
        animating = false
        if let p = pending { pending = nil; show(p) }
    }

    func resetCamera() {
        let dist = Float(n) * 3.9
        cameraNode.simdPosition = SIMD3<Float>(dist * 0.55, dist * 0.5, dist * 0.68)
        cameraNode.look(at: SCNVector3(0, 0, 0))
    }
}

struct Cube3DView: NSViewRepresentable {
    let controller: Cube3DController

    func makeNSView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = controller.scene
        v.pointOfView = controller.cameraNode
        v.allowsCameraControl = true
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = false
        return v
    }

    func updateNSView(_ nsView: SCNView, context: Context) {}
}
