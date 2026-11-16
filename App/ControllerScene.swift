import SwiftUI
import SceneKit
import Metal

/// Original procedural housings, with familiar controls and no brand marks or downloaded models.
enum ControllerScene {
    static func material(_ color: UIColor, metal: CGFloat = 0.05, roughness: CGFloat = 0.42) -> SCNMaterial {
        let value = SCNMaterial(); value.diffuse.contents = color; value.lightingModel = .physicallyBased
        value.metalness.contents = metal; value.roughness.contents = roughness
        return value
    }
    static func controller(cube: Bool) -> SCNNode {
        let root = SCNNode()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -1.9, y: 0.85))
        path.addCurve(to: CGPoint(x: 1.9, y: 0.85), controlPoint1: CGPoint(x: -0.7, y: cube ? 1.12 : 0.72), controlPoint2: CGPoint(x: 0.7, y: cube ? 1.12 : 0.72))
        path.addCurve(to: CGPoint(x: 2.3, y: -1.1), controlPoint1: CGPoint(x: 2.65, y: 0.8), controlPoint2: CGPoint(x: 2.55, y: -0.5))
        path.addCurve(to: CGPoint(x: 1.5, y: -1.38), controlPoint1: CGPoint(x: 2.18, y: -1.55), controlPoint2: CGPoint(x: 1.8, y: -1.6))
        path.addCurve(to: CGPoint(x: 0.8, y: -0.62), controlPoint1: CGPoint(x: 1.2, y: -1.22), controlPoint2: CGPoint(x: 1.1, y: -0.7))
        path.addCurve(to: CGPoint(x: -0.8, y: -0.62), controlPoint1: CGPoint(x: 0.32, y: cube ? -0.4 : -0.92), controlPoint2: CGPoint(x: -0.32, y: cube ? -0.4 : -0.92))
        path.addCurve(to: CGPoint(x: -1.5, y: -1.38), controlPoint1: CGPoint(x: -1.1, y: -0.7), controlPoint2: CGPoint(x: -1.2, y: -1.22))
        path.addCurve(to: CGPoint(x: -2.3, y: -1.1), controlPoint1: CGPoint(x: -1.8, y: -1.6), controlPoint2: CGPoint(x: -2.18, y: -1.55))
        path.addCurve(to: CGPoint(x: -1.9, y: 0.85), controlPoint1: CGPoint(x: -2.55, y: -0.5), controlPoint2: CGPoint(x: -2.65, y: 0.8)); path.close()
        path.apply(CGAffineTransform(scaleX: 100, y: 100))
        let housing = SCNShape(path: path, extrusionDepth: cube ? 48 : 35); housing.chamferRadius = 15
        housing.materials = [material(cube ? UIColor(red: 0.31, green: 0.27, blue: 0.62, alpha: 1) : UIColor(white: 0.44, alpha: 1))]
        let seam = SCNShape(path: path, extrusionDepth: 18); seam.chamferRadius = 12
        seam.materials = [material(UIColor(white: 0.09, alpha: 1), roughness: 0.65)]
        let lower = SCNNode(geometry: seam); lower.scale = SCNVector3(0.01015, 0.01015, 0.01); lower.position.z = -0.16; root.addChildNode(lower)
        let shell = SCNNode(geometry: housing); shell.scale = SCNVector3(0.01, 0.01, 0.01); root.addChildNode(shell)
        for side in [Float(-1), Float(1)] {
            let grip = SCNCapsule(capRadius: 0.24, height: 0.92)
            grip.materials = [material(cube ? UIColor(red: 0.20, green: 0.17, blue: 0.39, alpha: 1) : UIColor(white: 0.30, alpha: 1), roughness: 0.78)]
            let insert = SCNNode(geometry: grip); insert.scale.z = 0.30; insert.position = SCNVector3(side * 1.89, -0.80, 0.19); insert.eulerAngles.z = side * 0.25; root.addChildNode(insert)
        }
        func box(_ x: Float, _ y: Float, _ z: Float, _ width: CGFloat, _ height: CGFloat, _ depth: CGFloat, _ color: UIColor, angle: Float = 0) {
            let shape = SCNBox(width: width, height: height, length: depth, chamferRadius: min(width, height, depth) * 0.25)
            shape.materials = [material(color)]; let n = SCNNode(geometry: shape); n.position = SCNVector3(x, y, z); n.eulerAngles.z = angle; root.addChildNode(n)
        }
        func cap(_ x: Float, _ y: Float, _ radius: CGFloat, _ color: UIColor, _ label: String = "", _ text: UIColor = .black, sx: Float = 1, sy: Float = 1) {
            let rim = SCNCylinder(radius: radius + 0.045, height: 0.065); rim.radialSegmentCount = 48; rim.materials = [material(UIColor(white: 0.07, alpha: 1))]
            let base = SCNNode(geometry: rim); base.eulerAngles.x = .pi / 2; base.position = SCNVector3(x,y,0.31); base.scale = SCNVector3(sx,1,sy); root.addChildNode(base)
            let cylinder = SCNCylinder(radius: radius, height: 0.12); cylinder.radialSegmentCount = 48; cylinder.materials = [material(color, roughness: 0.28)]
            let node = SCNNode(geometry: cylinder); node.eulerAngles.x = .pi / 2; node.position = SCNVector3(x,y,0.38); node.scale = SCNVector3(sx,1,sy); root.addChildNode(node)
            let edge = SCNTorus(ringRadius: radius - 0.016, pipeRadius: 0.007); edge.ringSegmentCount = 48; edge.pipeSegmentCount = 8
            edge.materials = [material(color.withAlphaComponent(1), metal: 0.15, roughness: 0.25)]
            let bevel = SCNNode(geometry: edge); bevel.eulerAngles.x = .pi / 2; bevel.position = SCNVector3(x,y,0.443); bevel.scale = SCNVector3(sx,1,sy); root.addChildNode(bevel)
            if !label.isEmpty {
                let string = SCNText(string: label, extrusionDepth: 0.004); string.font = .systemFont(ofSize: 1, weight: .semibold); string.flatness = 0.05; string.materials = [material(text)]
                let word = SCNNode(geometry: string); let bounds = string.boundingBox
                word.pivot = SCNMatrix4MakeTranslation((bounds.max.x + bounds.min.x)/2, (bounds.max.y + bounds.min.y)/2, 0)
                let scale = Float(radius) * (label.count > 1 ? 0.60 : 1.0); word.scale = SCNVector3(scale,scale,scale); word.position = SCNVector3(x,y,0.448); root.addChildNode(word)
            }
        }
        func stick(_ x: Float, _ y: Float, _ color: UIColor, small: Bool = false) {
            cap(x,y,small ? 0.26 : 0.34,UIColor(white:0.08,alpha:1))
            let shaft = SCNCylinder(radius: 0.11, height: 0.25); shaft.materials = [material(UIColor(white: 0.24, alpha: 1))]
            let n=SCNNode(geometry:shaft);n.eulerAngles.x = .pi/2;n.position=SCNVector3(x,y,0.5);root.addChildNode(n)
            let top=SCNSphere(radius:small ? 0.23:0.29);top.segmentCount=48;top.materials=[material(color,roughness:0.7)]
            let head=SCNNode(geometry:top);head.scale=SCNVector3(1,1,0.40);head.position=SCNVector3(x,y,0.64);root.addChildNode(head)
            for radius in [small ? 0.14 : 0.20, small ? 0.18 : 0.24] {
                let ring = SCNTorus(ringRadius: radius, pipeRadius: 0.008); ring.ringSegmentCount = 48; ring.pipeSegmentCount = 8
                ring.materials = [material(UIColor(white: 0.08, alpha: 1), roughness: 0.85)]
                let groove = SCNNode(geometry: ring); groove.eulerAngles.x = .pi / 2; groove.position = SCNVector3(x,y,0.731); root.addChildNode(groove)
            }
        }
        func dpad(_ x: Float, _ y: Float, scale: CGFloat = 1) {
            cap(x,y,0.43 * scale,UIColor(white:0.12,alpha:1))
            box(x,y,0.46,0.66 * scale,0.23 * scale,0.14,UIColor(white:0.19,alpha:1))
            box(x,y,0.46,0.23 * scale,0.66 * scale,0.14,UIColor(white:0.19,alpha:1))
        }
        box(-1.45,1.03,-0.06,0.64,0.24,0.24,UIColor(white:0.34,alpha:1))
        box(1.45,1.03,-0.06,0.64,0.24,0.24,UIColor(white:0.34,alpha:1))
        box(-1.45,0.91,0.1,0.76,0.28,0.38,UIColor(white:0.20,alpha:1))
        box(1.45,0.91,0.1,0.76,0.28,0.38,UIColor(white:0.20,alpha:1))
        if cube {
            stick(-1.4,0.33,UIColor(white:0.72,alpha:1));dpad(-0.87,-0.55,scale:0.74)
            stick(0.88,-0.61,UIColor(red:0.98,green:0.76,blue:0.17,alpha:1),small:true)
            cap(1.5,0.25,0.34,UIColor(red:0.14,green:0.72,blue:0.43,alpha:1),"A")
            cap(0.97,-0.08,0.20,UIColor(red:0.88,green:0.2,blue:0.23,alpha:1),"B")
            cap(1.97,0.31,0.19,UIColor(white:0.72,alpha:1),"X",sx:0.85,sy:1.55)
            cap(1.45,0.75,0.19,UIColor(white:0.72,alpha:1),"Y",sx:1.55,sy:0.85)
            box(1.9,0.98,0.22,0.53,0.18,0.17,UIColor(red:0.53,green:0.43,blue:0.9,alpha:1))
            cap(0,0.2,0.1,UIColor(white:0.65,alpha:1))
        } else {
            dpad(-1.45,0.24);stick(-0.67,-0.63,UIColor(white:0.18,alpha:1));stick(0.67,-0.63,UIColor(white:0.18,alpha:1))
            let dark=UIColor(white:0.15,alpha:1)
            cap(1.46,0.68,0.205,dark,"△",.systemMint);cap(1.91,0.24,0.205,dark,"○",.systemRed)
            cap(1.46,-0.2,0.205,dark,"×",.systemCyan);cap(1.01,0.24,0.205,dark,"□",.systemPink)
            box(-0.27,0.2,0.34,0.30,0.10,0.08,dark,angle:0.15);box(0.27,0.2,0.34,0.30,0.10,0.08,dark)
        }
        return root
    }
    static func scene() -> (SCNScene, SCNNode) {
        let scene=SCNScene(); let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.usesOrthographicProjection=true;camera.camera?.orthographicScale=1.7;camera.camera?.wantsHDR=true;camera.camera?.wantsExposureAdaptation=false;camera.camera?.exposureOffset = -0.4;camera.camera?.zNear=0.1;camera.camera?.zFar=100
        camera.position=SCNVector3(0,-3.6,8);camera.look(at:SCNVector3(0,-0.1,0));scene.rootNode.addChildNode(camera)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=140;ambient.light?.color=UIColor(red:0.95,green:0.97,blue:1,alpha:1);scene.rootNode.addChildNode(ambient)
        let key=SCNNode();key.light=SCNLight();key.light?.type = .omni;key.light?.intensity=650;key.position=SCNVector3(-3,5,7);scene.rootNode.addChildNode(key)
        let rim=SCNNode();rim.light=SCNLight();rim.light?.type = .omni;rim.light?.intensity=300;rim.light?.color=UIColor(red:0.43,green:0.59,blue:1,alpha:1);rim.position=SCNVector3(4,-1,4);scene.rootNode.addChildNode(rim)
        return (scene,camera)
    }

}

struct SolidControllerPreview: UIViewRepresentable, Animatable {
    let system: ConsoleSystem
    var tilt = CGSize.zero
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(tilt.width, tilt.height) }
        set { tilt = CGSize(width: newValue.first, height: newValue.second) }
    }
    func makeUIView(context: Context) -> SCNView {
        let view=SCNView();view.backgroundColor = .clear;view.isOpaque=false;view.antialiasingMode = .multisampling4X
        let (scene,camera)=ControllerScene.scene();let model=ControllerScene.controller(cube:system == .gamecube);model.name="controller";scene.rootNode.addChildNode(model)
        view.scene=scene;view.pointOfView=camera;view.rendersContinuously=false;view.isPlaying=false;view.isUserInteractionEnabled=false;view.preferredFramesPerSecond=30;view.tag=system == .gamecube ? 2 : 1
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        if view.tag != (system == .gamecube ? 2 : 1), let scene = view.scene {
            scene.rootNode.childNode(withName: "controller", recursively: false)?.removeFromParentNode()
            let model = ControllerScene.controller(cube: system == .gamecube); model.name = "controller"; scene.rootNode.addChildNode(model)
            view.tag = system == .gamecube ? 2 : 1
        }
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        view.scene?.rootNode.childNode(withName:"controller",recursively:false)?.eulerAngles=SCNVector3(Float(tilt.height)*0.006,Float(tilt.width)*0.008,0)
        SCNTransaction.commit(); view.setNeedsDisplay()
    }
}
