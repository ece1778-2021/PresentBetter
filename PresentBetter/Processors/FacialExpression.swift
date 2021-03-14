import ARKit
import UIKit
import Vision

class FacialExpressionSession {
    var capturedImage: UIImage?
    var captureWidth = 0, captureHeight = 0
    
    var imageInFrame: CGRect
    var imageBoundingBox: CGRect?
    
    var supportsDepthCamera: Bool
    
    init(boundingFrame: CGRect) {
        imageInFrame = boundingFrame
        supportsDepthCamera = ARFaceTrackingConfiguration.isSupported
    }
    
    func updateFrame(withImage image: UIImage?, width: Int, height: Int) {
        capturedImage = image
        captureWidth = width
        captureHeight = height
    }
    
    func getFaceImage(originalImage: UIImage, faceBox: CGRect) -> CGImage? {
        let transform = CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -originalImage.size.height)
        
        guard let cgImage = originalImage.cgImage?.cropping(to: faceBox.applying(transform)) else {
            return nil
        }
        let width = cgImage.width
        let height = cgImage.height
        
        guard let cgContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue) else {
            return nil
        }
        cgContext.rotate(by: -.pi / 2)
        cgContext.translateBy(x: CGFloat(-height), y: 0)
        cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return cgContext.makeImage()
    }
    
    func detectExpressionAndUpdateDrawing(faceObservation: VNFaceObservation) -> EmotionClasses? {
        let width = Int(imageInFrame.width)
        let height = Int(imageInFrame.width * (CGFloat(captureWidth) / CGFloat(captureHeight)))
        
        var transform: CGAffineTransform
        if supportsDepthCamera {
            transform = CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -CGFloat(width), y: -CGFloat(height))
        } else {
            transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -CGFloat(height))
        }
        
        imageBoundingBox = VNImageRectForNormalizedRect(faceObservation.boundingBox, width, height)
            .applying(transform)
        let imageBoundingBoxNotTranslated = VNImageRectForNormalizedRect(faceObservation.boundingBox, captureHeight, captureWidth)
        
        guard let capturedImage = self.capturedImage else {
            return nil
        }
        if let faceImageRef = self.getFaceImage(originalImage: capturedImage, faceBox: imageBoundingBoxNotTranslated) {
            if let emotionPrediction = MLDataProvider.predictEmotion(image: faceImageRef) {
                return emotionPrediction
            }
        }
        
        return nil
    }
}
