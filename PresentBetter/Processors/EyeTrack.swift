import ARKit
import UIKit

class Device {
    var screenSize: CGSize
    var screenPointSize: CGSize
    var node: SCNNode
    var screenNode: SCNNode
    var compensation: CGPoint
    
    init() {
        screenSize = CGSize(width: 0.0714, height: 0.1440)
        screenPointSize = CGSize(width: 375, height: 812)
        compensation = CGPoint(x: 0, y: 375)
        
        node = SCNNode()
        let screenGeometry = SCNPlane(width: 1, height: 1)
        screenGeometry.firstMaterial?.isDoubleSided = true
        screenGeometry.firstMaterial?.diffuse.contents = UIColor.green
        screenNode = SCNNode()
        screenNode.geometry = screenGeometry
        node.addChildNode(screenNode)
    }
}

class Eye {
    let optimumDistanceInCm: Float = 75
    
    var lookAtPosition = CGPoint(x: 0, y: 0)
    var node: SCNNode
    var target: SCNNode
    
    init(hidden: Bool = false) {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.1)
        geometry.radialSegmentCount = 3
        let eyeNode = SCNNode()
        eyeNode.geometry = geometry
        
        if !hidden {
            geometry.firstMaterial?.diffuse.contents = UIColor.red
        } else {
            geometry.firstMaterial?.diffuse.contents = UIColor.clear
        }
        eyeNode.eulerAngles.x = -.pi / 2
        eyeNode.position.z = 0.1
        
        node = SCNNode()
        node.addChildNode(eyeNode)
        target = SCNNode()
        node.addChildNode(target)
        target.position.z = 2
    }
    
    func distanceToDevice() -> Float {
        return (node.worldPosition - SCNVector3Zero).length()
    }
    
    func hittingAt(device: Device) -> CGPoint {
        let deviceScreenEyeHitTestResults = device.node.hitTestWithSegment(from: target.worldPosition, to: node.worldPosition, options: nil)
        for result in deviceScreenEyeHitTestResults {
            lookAtPosition.x = CGFloat(result.localCoordinates.x) / (device.screenSize.width / 2) * device.screenPointSize.width + device.compensation.x
            lookAtPosition.y = CGFloat(result.localCoordinates.y) / (device.screenSize.height / 2) * device.screenPointSize.height + device.compensation.y
        }
        return lookAtPosition
    }
}

class EyeContactSession {
    var leftEye: Eye, rightEye: Eye
    var devicePlane: Device
    
    init(currentScene: SCNScene) {
        leftEye = Eye(hidden: true)
        rightEye = Eye(hidden: true)
        devicePlane = Device()
        currentScene.rootNode.addChildNode(devicePlane.node)
    }
    
    func faceNode() -> SCNNode {
        let faceNode = SCNNode()
        faceNode.addChildNode(leftEye.node)
        faceNode.addChildNode(rightEye.node)
        return faceNode
    }
    
    func updateDevicePlane(newTransform: SCNMatrix4) {
        devicePlane.node.transform = newTransform
    }
    
    func updateFaceAnchor(anchor: ARFaceAnchor) {
        leftEye.node.simdTransform = anchor.leftEyeTransform
        rightEye.node.simdTransform = anchor.rightEyeTransform
    }
    
    func isWithAttention() -> Bool {
        // Up-down eye rotation
        let eyeRotateX = (leftEye.node.simdEulerAngles.x + rightEye.node.simdEulerAngles.x) / 2
        // Left-right eye rotation
        let eyeRotateY = (leftEye.node.simdEulerAngles.y + rightEye.node.simdEulerAngles.y) / 2
        
        if deg(eyeRotateX) * leftEye.distanceToDevice() * 100 < -(3.0 * leftEye.optimumDistanceInCm) || abs(deg(eyeRotateY)) * leftEye.distanceToDevice() * 100 > 4.0 * leftEye.optimumDistanceInCm {
            return false
        } else {
            return true
        }
    }
}

extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
}
func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z)
}
