import AVFoundation
import CoreML
import UIKit
import Vision

enum PresentationState {
    case preparing
    case presenting
}

class PresentationViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var lblCountdown: UILabel!
    
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
    
    var state: PresentationState = .preparing
    var countdown = 5
    var smiledInSpan = false, totalSmiles = 0
    var leftShoulderAngles = [CGFloat](), rightShoulderAngles = [CGFloat]()
    var handMovedInSpan = false, totalHandMoves = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        countdown = 5
        smiledInSpan = false
        totalSmiles = 0
        handMovedInSpan = false
        totalHandMoves = 0
        leftShoulderAngles.removeAll()
        leftShoulderAngles.removeAll()
        state = .preparing
        
        DispatchQueue.main.async {
            if self.configSuccessful {
                self.captureSession.startRunning()
                self.lblCountdown.text = "\(self.countdown)"
                let _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: self.prepareCountdown)
            } else {
                self.lblCountdown.text = "Camera error!"
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        captureSession.stopRunning()
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
                if let emotionPrediction = MLDataProvider.predictEmotion(image: faceImageRef) {
                    if emotionPrediction == .Happy {
                        self.smiledInSpan = true
                    }
                }
            }
        }
    }
    
    func detectedBodyPose(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNHumanBodyPoseObservation] else {
            return
        }
        guard let result = results.first else {
            return
        }
        
        guard let points = try? result.recognizedPoints(.all) else {
            return
        }
        
        var keyPoints: [VNHumanBodyPoseObservation.JointName : CGPoint?] = [
            .leftWrist : nil,
            .leftElbow : nil,
            .leftShoulder : nil,
            .rightWrist : nil,
            .rightElbow : nil,
            .rightShoulder : nil
        ]
        
        for (key, _) in keyPoints {
            if let value = points[key], value.confidence > 0 {
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
                handMovedInSpan = true
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
                handMovedInSpan = true
            }
        }
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        captureWidth = CVPixelBufferGetWidth(imageBuffer)
        captureHeight = CVPixelBufferGetHeight(imageBuffer)
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let ciContext = CIContext(options: nil)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        captureImage = UIImage(cgImage: cgImage, scale: 1, orientation: .leftMirrored)
        
        if state == .presenting {
            let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFace)
            let detectBodyPoseRequest = VNDetectHumanBodyPoseRequest(completionHandler: detectedBodyPose)
            
            do {
                try sequenceHandler.perform([detectFaceRequest, detectBodyPoseRequest], on: imageBuffer, orientation: .leftMirrored)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.imageView.image = self.captureImage
            }
        }
    }
    
}

extension PresentationViewController {
    func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        let squareX = (from.x - to.x) * (from.x - to.x)
        let squareY = (from.y - to.y) * (from.y - to.y)
        return sqrt(squareX + squareY)
    }
}

extension PresentationViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "forwardToFeedback" {
            let feedbackView = segue.destination as! FeedbackViewController
            feedbackView.totalSmiles = totalSmiles
            feedbackView.totalHandMoves = totalHandMoves
        }
    }
    
    func prepareCountdown(timer: Timer) {
        countdown -= 1
        lblCountdown.text = "\(countdown)"
        
        if countdown == 0 {
            timer.invalidate()
            
            countdown = 30
            state = .presenting
            lblCountdown.text = String(format: "00:%02d", countdown / 2)
            let _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: presentationCountdown)
        }
    }
    
    func presentationCountdown(timer: Timer) {
        countdown -= 1
        if countdown % 2 == 0 {
            lblCountdown.text = String(format: "00:%02d", countdown / 2)
        }
        
        if smiledInSpan {
            smiledInSpan = false
            totalSmiles += 1
        }
        
        if handMovedInSpan {
            handMovedInSpan = false
            totalHandMoves += 1
        }
        
        if countdown == 0 {
            timer.invalidate()
            performSegue(withIdentifier: "forwardToFeedback", sender: self)
        }
    }
}

