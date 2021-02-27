import ARKit
import AVFoundation
import CoreML
import UIKit
import Vision

enum PresentationState {
    case preparing
    case presenting
}

func deg(_ rad: Float) -> Float {
    return rad / .pi * 180
}

class PresentationViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var lblCountdown: UILabel!
    @IBOutlet var lblPrepareCountdown: UILabel!
    @IBOutlet var countdownBackgroundView: UIView!
    
    // AVCaptureSession objects
    var captureSession: AVCaptureSession!
    var camera: AVCaptureDevice!
    var cameraInput: AVCaptureInput!
    var videoOutput: AVCaptureVideoDataOutput!
    var sampleBufferQueue: DispatchQueue!
    
    var sequenceHandler: VNSequenceRequestHandler!
    
    // AR parameters
    var supportsDepthCamera = false
    var lastARUpdateFrameTime: Date?    // Stores the last time ARSession updates its frame
    var tryStartPresentation = false
    var leftEye: Eye!, rightEye: Eye!
    var devicePlane: Device!
    
    // Indicates if AVCaptureSession configuration is successful
    var accessSuccessful = false
    var configSuccessful = false
    
    // Stores the width and height of captured CVPixelBuffer, and the UIImage representation of it
    var captureWidth = 0, captureHeight = 0
    var captureImage: UIImage?
    
    var roundRectLayer: CAShapeLayer!
    
    // Presentation parameters
    var state: PresentationState = .preparing
    var countdown = 5
    var smiledInSpan = false, totalSmiles = 0
    var leftShoulderAngles = [CGFloat](), rightShoulderAngles = [CGFloat]()
    var handMovedInSpan = false, totalHandMoves = 0
    var focusDetected = 0, lostFocusDetected = 0, totalLooks = 0
    
    // Performance metrics: Number of frames processed during a session
    var frames = 0
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        supportsDepthCamera = ARFaceTrackingConfiguration.isSupported
        sequenceHandler = VNSequenceRequestHandler()
        roundRectLayer = CAShapeLayer()
        roundRectLayer.fillColor = UIColor.clear.cgColor
        roundRectLayer.lineWidth = 2.0
        roundRectLayer.strokeColor = UIColor.red.cgColor
        
        if supportsDepthCamera {
            sceneView.layer.addSublayer(roundRectLayer)
            sceneView.isHidden = false
            imageView.isHidden = true
            initializeARScene()
        } else {
            // Fallback to traditional AVCaptureSession if the device has no TrueDepth camera.
            imageView.layer.addSublayer(roundRectLayer)
            sceneView.isHidden = true
            imageView.isHidden = false
            initializeAVCapture()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        resetPresentationCountdown()
        DispatchQueue.main.async {
            if self.supportsDepthCamera {
                self.tryStartPresentation = true
                self.startARSession()
            } else {
                // Fallback to traditional AVCaptureSession if the device has no TrueDepth camera.
                if self.configSuccessful {
                    self.captureSession.startRunning()
                    
                    PresentationPreparationViewController.showView(self)
                    NotificationCenter.default.addObserver(self, selector: #selector(self.startPresenting), name: Notification.popoverDismissed, object: nil)
                } else {
                    NoCameraViewController.showView(self)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if supportsDepthCamera {
            sceneView.session.pause()
        } else {
            // Fallback to traditional AVCaptureSession if the device has no TrueDepth camera.
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Camera capture session initialization
    
    // Alias of startPresentationCountdown
    @objc func startPresenting() {
        NotificationCenter.default.removeObserver(self)
        startPresentationCountdown()
    }
    
    func initializeARScene() {
        leftEye = Eye()
        rightEye = Eye()
        devicePlane = Device()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.preferredFramesPerSecond = 15
        sceneView.scene.rootNode.addChildNode(devicePlane.node)
    }
    
    func startARSession() {
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func initializeAVCapture() {
        let semaphore = DispatchSemaphore(value: 0)
        
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
        configSuccessful = true
    }

    // MARK: - Facial expression detection
    
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
            
            var transform: CGAffineTransform
            if self.supportsDepthCamera {
                transform = CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -CGFloat(width), y: -CGFloat(height))
            } else {
                transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -CGFloat(height))
            }
            
            let imageBoundingBox = VNImageRectForNormalizedRect(result.boundingBox, width, height)
                .applying(transform)
            let imageBoundingBoxNotTranslated = VNImageRectForNormalizedRect(result.boundingBox, self.captureHeight, self.captureWidth)
            
            let path = UIBezierPath(roundedRect: imageBoundingBox, cornerRadius: 0)
            self.roundRectLayer.path = path.cgPath
            
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
    
    // MARK: - Body pose detection
    
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
    
    // MARK: - Camera capture session
    
    func processDetection(_ imageBuffer: CVPixelBuffer) {
        guard state == .presenting else { return }
        
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
            frames += 1
            
            do {
                try sequenceHandler.perform([detectFaceRequest, detectBodyPoseRequest], on: imageBuffer, orientation: .leftMirrored)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

extension PresentationViewController: ARSCNViewDelegate {
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
        
        // Up-down eye rotation
        let eyeRotateX = (leftEye.node.simdEulerAngles.x + rightEye.node.simdEulerAngles.x) / 2
        // Left-right eye rotation
        let eyeRotateY = (leftEye.node.simdEulerAngles.y + rightEye.node.simdEulerAngles.y) / 2
        
        if state == .presenting {
            if deg(eyeRotateX) * leftEye.distanceToDevice() * 100 < -(3.0 * leftEye.optimumDistanceInCm) || abs(deg(eyeRotateY)) * leftEye.distanceToDevice() * 100 > 4.0 * leftEye.optimumDistanceInCm {
                lostFocusDetected += 1
            } else {
                focusDetected += 1
            }
        }
    }
}

extension PresentationViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if tryStartPresentation == true {
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                tryStartPresentation = false
                PresentationPreparationViewController.showView(self)
                NotificationCenter.default.addObserver(self, selector: #selector(self.startPresenting), name: Notification.popoverDismissed, object: nil)
            }
        }
        
        var updateInterval: Double
        if let lastARUpdateFrameTime = self.lastARUpdateFrameTime {
            updateInterval = Date().timeIntervalSince(lastARUpdateFrameTime)
        } else {
            updateInterval = 1 / 17
        }
        
        DispatchQueue.main.async {
            if updateInterval >= 1 / 17 {
                self.lastARUpdateFrameTime = Date()
                self.processDetection(frame.capturedImage)
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("Cannot start ARKit: \(error.localizedDescription)")
        NoCameraViewController.showView(self)
    }
}

extension PresentationViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        processDetection(imageBuffer)
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
            feedbackView.totalLooks = totalLooks
        }
    }
    
    func resetPresentationCountdown() {
        frames = 0
        countdown = 5
        smiledInSpan = false
        totalSmiles = 0
        handMovedInSpan = false
        totalHandMoves = 0
        focusDetected = 0
        lostFocusDetected = 0
        totalLooks = 0
        leftShoulderAngles.removeAll()
        leftShoulderAngles.removeAll()
        state = .preparing
        
        lblPrepareCountdown.isHidden = true
        countdownBackgroundView.isHidden = true
        lblCountdown.text = "00:15"
    }
    
    func startPresentationCountdown() {
        lblPrepareCountdown.text = "5"
        lblPrepareCountdown.isHidden = false
        
        let _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: prepareCountdown)
    }
    
    func prepareCountdown(timer: Timer) {
        countdown -= 1
        lblPrepareCountdown.text = "\(countdown)"
        
        if countdown == 0 {
            timer.invalidate()
            lblPrepareCountdown.isHidden = true
            countdownBackgroundView.isHidden = false
            
            countdown = 30
            state = .presenting
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
        
        if focusDetected > lostFocusDetected {
            totalLooks += 1
        }
        focusDetected = 0
        lostFocusDetected = 0
        
        if countdown == 0 {
            timer.invalidate()
            performSegue(withIdentifier: "forwardToFeedback", sender: self)
        }
    }
}

