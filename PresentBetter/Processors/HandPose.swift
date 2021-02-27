import UIKit
import Vision

class HandPoseSession {
    var leftShoulderAngles: [CGFloat], rightShoulderAngles: [CGFloat]
    
    init() {
        leftShoulderAngles = [CGFloat]()
        rightShoulderAngles = [CGFloat]()
    }
    
    func reset() {
        leftShoulderAngles.removeAll()
        rightShoulderAngles.removeAll()
    }
    
    func updateDataAndEvaluateDetectionResult(withBodyKeyPoints points: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) -> Bool {
        var handMoved = false
        
        var keyPoints: [VNHumanBodyPoseObservation.JointName : CGPoint?] = [
            .leftWrist : nil,
            .leftElbow : nil,
            .leftShoulder : nil,
            .rightWrist : nil,
            .rightElbow : nil,
            .rightShoulder : nil
        ]
        
        for (key, _) in keyPoints {
            if let value = points[key], value.confidence > 0.4 {
                keyPoints[key] = value.location
            }
        }
        
        var a: CGFloat, b: CGFloat, c: CGFloat
        var leftAngle: CGFloat, rightAngle: CGFloat
        
        if let leftWrist = keyPoints[.leftWrist]!,
           let leftElbow = keyPoints[.leftElbow]!,
           let leftShoulder = keyPoints[.leftShoulder]! {
            a = CGPointDistance(from: leftWrist, to: leftShoulder)
            b = CGPointDistance(from: leftWrist, to: leftElbow)
            c = CGPointDistance(from: leftElbow, to: leftShoulder)
            leftAngle = acos((b * b + c * c - a * a) / (2 * b * c)) / .pi * 180
        } else {
            leftAngle = .nan
        }
        
        if let rightWrist = keyPoints[.rightWrist]!,
           let rightElbow = keyPoints[.rightElbow]!,
           let rightShoulder = keyPoints[.rightShoulder]! {
            a = CGPointDistance(from: rightWrist, to: rightShoulder)
            b = CGPointDistance(from: rightWrist, to: rightElbow)
            c = CGPointDistance(from: rightElbow, to: rightShoulder)
            rightAngle = acos((b * b + c * c - a * a) / (2 * b * c)) / .pi * 180
        } else {
            rightAngle = .nan
        }
        
        if leftAngle != .nan {
            leftShoulderAngles.append(leftAngle)
        } else {
            if leftShoulderAngles.count > 0 {
                leftShoulderAngles.append(leftShoulderAngles.last!)
            }
        }
        if leftShoulderAngles.count > 15 {
            leftShoulderAngles.removeFirst()
        }
        if leftShoulderAngles.count > 0 {
            if leftShoulderAngles.max()! - leftShoulderAngles.min()! > 15 {
                handMoved = true
            }
        }
        
        if rightAngle != .nan {
            rightShoulderAngles.append(rightAngle)
        } else {
            if rightShoulderAngles.count > 0 {
                rightShoulderAngles.append(leftShoulderAngles.last!)
            }
        }
        if rightShoulderAngles.count > 15 {
            rightShoulderAngles.removeFirst()
        }
        if rightShoulderAngles.count > 0 {
            if rightShoulderAngles.max()! - rightShoulderAngles.min()! > 15 {
                handMoved = true
            }
        }
        
        return handMoved
    }
}

extension HandPoseSession {
    func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        let squareX = (from.x - to.x) * (from.x - to.x)
        let squareY = (from.y - to.y) * (from.y - to.y)
        return sqrt(squareX + squareY)
    }
}
