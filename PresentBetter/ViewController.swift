import AVFoundation
import Vision
import UIKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession!
    var camera: AVCaptureDevice!
    var cameraInput: AVCaptureInput!
    var videoOutput: AVCaptureVideoDataOutput!
    
    var sampleBufferQueue: DispatchQueue!
    
    var sequenceHandler: VNSequenceRequestHandler!
    
    var accessSuccessful = false
    var configSuccessful = false
    
    var captureWidth = 0, captureHeight = 0
    var captureImage: UIImage?
    
    var roundRectLayer: CAShapeLayer!
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var faceImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let semaphore = DispatchSemaphore(value: 0)
        sequenceHandler = VNSequenceRequestHandler()
        roundRectLayer = CAShapeLayer()
        roundRectLayer.fillColor = UIColor.clear.cgColor
        roundRectLayer.lineWidth = 2.0
        roundRectLayer.strokeColor = UIColor.red.cgColor
        
        imageView.layer.addSublayer(roundRectLayer)
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            accessSuccessful = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if granted {
                    self.accessSuccessful = true
                }
                semaphore.signal()
            })
        default:
            return
        }

        if accessSuccessful == false {
            _ = semaphore.wait(timeout: .distantFuture)
        }
        
        DispatchQueue.main.async {
            self.configureCaptureSession()
        }
    }
    
    func configureCaptureSession() {
        if accessSuccessful == false {
            return
        }
        
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        captureSession.sessionPreset = .photo
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            camera = device
        } else {
            print("Error: No front camera!")
            captureSession.commitConfiguration()
            return
        }
        
        if let input = try? AVCaptureDeviceInput(device: camera) {
            cameraInput = input
        } else {
            print("Error: Cannot create device input for front camera")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(cameraInput)
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        sampleBufferQueue = DispatchQueue.global(qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Error: Cannot add output device")
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
        configSuccessful = true
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
    
    func detectedFace(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNFaceObservation] else {
            return
        }
        guard let result = results.first else {
            return
        }
        
        DispatchQueue.main.async {
            let width = Int(self.view.frame.width)
            let height = Int(self.view.frame.width * (CGFloat(self.captureWidth) / CGFloat(self.captureHeight)))
            
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.height)
            let translate = CGAffineTransform(translationX: 0, y: -(self.view.frame.height - CGFloat(height)) / 2)
            
            var imageBoundingBox = VNImageRectForNormalizedRect(result.boundingBox, width, height)
                .applying(transform)
                .applying(translate)
            
            if imageBoundingBox.width > imageBoundingBox.height {
                imageBoundingBox = CGRect(x: imageBoundingBox.origin.x + (imageBoundingBox.width - imageBoundingBox.height) / 2, y: imageBoundingBox.origin.y, width: imageBoundingBox.height, height: imageBoundingBox.height)
            } else if imageBoundingBox.width < imageBoundingBox.height {
                imageBoundingBox = CGRect(x: imageBoundingBox.origin.x, y: imageBoundingBox.origin.y + (imageBoundingBox.height - imageBoundingBox.width) / 2, width: imageBoundingBox.width, height: imageBoundingBox.width)
            }
            
            let path = UIBezierPath(roundedRect: imageBoundingBox, cornerRadius: 0)
            self.roundRectLayer.path = path.cgPath
            
            let imageBoundingBoxNotTranslated = VNImageRectForNormalizedRect(result.boundingBox, self.captureHeight, self.captureWidth)
            
            guard let captureImage = self.captureImage else {
                return
            }
            if let faceImageRef = self.getFaceImage(originalImage: captureImage, faceBox: imageBoundingBoxNotTranslated) {
                let faceImage = UIImage(cgImage: faceImageRef)
                self.faceImageView.image = faceImage
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        captureWidth = width
        captureHeight = height
        
        let contextRect = CGRect(x: 0, y: 0, width: width, height: height)
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let ciContext = CIContext(options: nil)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        guard let cgContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).rawValue) else {
            return
        }
        cgContext.draw(cgImage, in: contextRect)
        
        guard let imageRef = cgContext.makeImage() else {
            return
        }
        captureImage = UIImage(cgImage: imageRef, scale: 1, orientation: .leftMirrored)
        
        let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFace)
        do {
            try sequenceHandler.perform([detectFaceRequest], on: imageRef, orientation: .leftMirrored)
        } catch {
            print(error.localizedDescription)
        }
        
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.imageView.image = self.captureImage
            }
        }
    }
    
}

