import AppKit
import CubeCore
import SceneKit
import SwiftUI

/// Uso interno (desenvolvimento): CuboMagico --snapshot <pasta>
@MainActor
enum Snapshot {
    static func run(_ dir: String) {
        let st = CubeState.scrambled(4, seed: 7)
        let net = NetView(n: 4, stickers: st.stickers, cell: 22).padding(20).background(Color.white)
        let r = ImageRenderer(content: net)
        r.scale = 2
        if let img = r.nsImage { write(img, "\(dir)/net.png") }

        let ctl = Cube3DController()
        ctl.show(st)
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = ctl.scene
        renderer.pointOfView = ctl.cameraNode
        let img3d = renderer.snapshot(atTime: 0, with: CGSize(width: 600, height: 600), antialiasingMode: .multisampling4X)
        write(img3d, "\(dir)/cube3d.png")

        let model = AppModel()
        model.n = 4
        model.stickers = st.stickers
        model.load(try! CubeSolver.solve(st), st)
        model.current = 37
        let full = ContentView(model: model).frame(width: 1180, height: 800).background(Color(white: 0.96))
        let fr = ImageRenderer(content: full); fr.scale = 1.5
        if let img = fr.nsImage { write(img, "\(dir)/full.png") }

        let cv = ContentView(model: model)
        for (name, v) in [("editor", AnyView(cv.editorContent.frame(width: 600))), ("steps", AnyView(cv.stepChips.frame(width: 560)))] {
            let rr = ImageRenderer(content: v.background(Color(white: 0.96))); rr.scale = 1.5
            if let img = rr.nsImage { write(img, "\(dir)/\(name).png") }
        }

        let help = HelpView().frame(width: 460).background(Color.white)
        let hr = ImageRenderer(content: help); hr.scale = 2
        if let img = hr.nsImage { write(img, "\(dir)/help.png") }
    }
    static func write(_ img: NSImage, _ path: String) {
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    }
}
