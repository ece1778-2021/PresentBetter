import ARKit
import UIKit

var EyeXMin: Float = -0.002, EyeXMax: Float = 0.14, EyeYMin: Float = -0.004, EyeYMax: Float = -0.112
var EyeZMin: Float = 0.94, EyeZMax: Float = 0.98

class EyeCalibrationViewController: UIViewController {
    @IBOutlet var sceneView: ARSCNView!
    
    var leftEye: Eye!, rightEye: Eye!
    var devicePlane: Device!
    
    var dotTransition = [[CGFloat]]()
    var collectedCalibrationData = [CGPoint]()
    
    var countdown = 4, calibratedDots = 0
    var intermediateEyeX: Float = 0
    var intermediateEyeY: Float = 0
    var intermediateEyeDataCollected: Float = 0
    var collectingData = false
    
    var eyeCalibrationDot: [CAShapeLayer]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        leftEye = Eye()
        rightEye = Eye()
        devicePlane = Device()
        
        sceneView.session.delegate = self
        sceneView.delegate = self
        sceneView.scene.rootNode.addChildNode(devicePlane.node)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        computeDotTransition()
        eyeCalibrationDot = CustomGraphics.shapeForEyeCalibrationDot(insets: view.safeAreaInsets)
        for shape in eyeCalibrationDot {
            view.layer.addSublayer(shape)
        }
        
        let _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: progressTimer(timer:))
    }
    
    func computeDotTransition() {
        let effectiveHeight = view.frame.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        let effectiveWidth = view.frame.width
        
        dotTransition.append([0, effectiveHeight - 20 - 36])
        dotTransition.append([effectiveWidth - 20 - 36, 0])
        dotTransition.append([effectiveWidth - 20 - 36, effectiveHeight - 20 - 36])
    }
    
    func progressTimer(timer: Timer) {
        countdown -= 1
        
        if countdown == 0 {
            countdown = 4
            calibratedDots += 1
            
            if calibratedDots == 4 {
                timer.invalidate()
                
                let x = collectedCalibrationData.map { $0.x }
                let y = collectedCalibrationData.map { $0.y }
                EyeXMin = Float(min(x[0], x[1]))
                EyeXMax = Float(max(x[2], x[3]))
                EyeYMin = Float(min(y[0], y[2]))
                EyeYMax = Float(max(x[1], y[3]))
                
                navigationController?.popViewController(animated: true)
                
            } else {
                for shape in eyeCalibrationDot {
                    let transition = dotTransition[calibratedDots - 1]
                    let startPosition = shape.position
                    shape.position = CGPoint(x: transition[0], y: transition[1])
                
                    let animation = CABasicAnimation(keyPath: "position")
                    animation.duration = 0.3
                    animation.fromValue = [startPosition.x, startPosition.y]
                    animation.toValue = dotTransition[calibratedDots - 1]
                    shape.add(animation, forKey: "position")
                }
                
            }
            
        } else if countdown == 1 {
            collectingData = false
            
            let average = CGPoint(x: CGFloat(intermediateEyeX / intermediateEyeDataCollected), y: CGFloat(intermediateEyeY / intermediateEyeDataCollected))
            print(average)
            collectedCalibrationData.append(average)
            
        } else if countdown == 2 {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.duration = 1
            animation.fromValue = 0
            animation.toValue = 1
            eyeCalibrationDot[2].add(animation, forKey: "strokeEnd")
            
            intermediateEyeX = 0
            intermediateEyeY = 0
            intermediateEyeDataCollected = 0
            collectingData = true
        }
        
    }
}

extension EyeCalibrationViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
    }
}

extension EyeCalibrationViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else {
            return nil
        }
        
        let faceNode = SCNNode()
        faceNode.addChildNode(leftEye.node)
        faceNode.addChildNode(rightEye.node)
        return faceNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let sceneTransformInfo = sceneView.pointOfView?.transform else {
            return
        }
        devicePlane.node.transform = sceneTransformInfo
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else {
            return
        }
        
        leftEye.node.simdTransform = faceAnchor.leftEyeTransform
        rightEye.node.simdTransform = faceAnchor.rightEyeTransform
        
        if collectingData {
            let rightEyeHittingAt = rightEye.hittingAt(device: devicePlane)
            let leftEyeHittingAt = leftEye.hittingAt(device: devicePlane)
            let lookAt = CGPoint(x: (leftEyeHittingAt.x + rightEyeHittingAt.x) / 2, y: -(rightEyeHittingAt.y + leftEyeHittingAt.y) / 2)
            intermediateEyeX += Float(lookAt.x)
            intermediateEyeY += Float(lookAt.y)
            print(faceAnchor.lookAtPoint.z)
            intermediateEyeDataCollected += 1
        }
    }
}
