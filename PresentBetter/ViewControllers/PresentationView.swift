import ARKit
import ARVideoKit
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
    @IBOutlet var recordingIndicator: UIView!
    @IBOutlet var recordingIndicatorView: UIView!
    
    // AVCaptureSession objects
    var captureSession: AVCaptureSession!
    var camera: AVCaptureDevice!
    var cameraInput: AVCaptureInput!
    var videoOutput: AVCaptureVideoDataOutput!
    var sampleBufferQueue: DispatchQueue!
    
    var sequenceHandler: VNSequenceRequestHandler!
    
    // AR parameters
    var supportsDepthCamera = false
    var hasMicrophoneAccess = false
    var lastARUpdateFrameTime: Date?    // Stores the last time ARSession updates its frame
    var tryStartPresentation = false
    var recorder: RecordAR?
    var videoURL: URL?
    
    // Indicates if AVCaptureSession configuration is successful
    var accessSuccessful = false
    var configSuccessful = false
    
    // UIImage representation of captured CVPixelBuffer
    var captureImage: UIImage?
    
    var roundRectLayer: CAShapeLayer!
    
    // Presentation quality measurement sessions
    var eyeContactSession: EyeContactSession!
    var facialExpressionSession: FacialExpressionSession!
    var handPoseSession: HandPoseSession!
    
    // Presentation parameters
    var state: PresentationState = .preparing
    var countdown = 5
    var smiledInSpan = false, totalSmiles = 0
    var handMovedInSpan = false, totalHandMoves = 0
    var focusDetected = 0, lostFocusDetected = 0, totalLooks = 0
    
    // Performance metrics: Number of frames processed during a session
    var frames = 0
    var indicatorTimer: Timer?
    
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
        
        recordingIndicatorView.isHidden = true
        recordingIndicator.layer.cornerRadius = 5.0
        
        facialExpressionSession = FacialExpressionSession(boundingFrame: view.frame)
        handPoseSession = HandPoseSession()
        
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
                self.initializeAVAudio()
                if self.hasMicrophoneAccess {
                    self.tryStartPresentation = true
                    self.startARSession()
                } else {
                    NoCameraViewController.showView(self)
                }
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
            indicatorTimer?.invalidate()
            recorder?.rest()
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
        eyeContactSession = EyeContactSession(currentScene: sceneView.scene)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.preferredFramesPerSecond = 15
        
        recorder = RecordAR(ARSceneKit: sceneView)
    }
    
    func startARSession() {
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        recorder?.prepare(config)
        
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
    
    func initializeAVAudio() {
        let semaphore = DispatchSemaphore(value: 0)
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasMicrophoneAccess = true
            semaphore.signal()
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission() { granted in
                if granted {
                    self.hasMicrophoneAccess = true
                }
                semaphore.signal()
            }
        default:
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .distantFuture)
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
    
    func detectedFace(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNFaceObservation] else {
            return
        }
        guard let result = results.first else {
            self.roundRectLayer.isHidden = true
            return
        }
        
        let emotionPrediction = facialExpressionSession.detectExpressionAndUpdateDrawing(faceObservation: result)
        if emotionPrediction == .Happy {
            smiledInSpan = true
        }
        
        DispatchQueue.main.async {
            if let imageBoundingBox = self.facialExpressionSession.imageBoundingBox {
                //let path = UIBezierPath(roundedRect: imageBoundingBox, cornerRadius: 0)
                //self.roundRectLayer.isHidden = false
                //self.roundRectLayer.path = path.cgPath
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
        
        let handMoved = handPoseSession.updateDataAndEvaluateDetectionResult(withBodyKeyPoints: points)
        if handMoved {
            handMovedInSpan = true
        }
    }
    
    // MARK: - Camera capture session
    
    func processDetection(_ imageBuffer: CVPixelBuffer) {
        guard state == .presenting else { return }
        
        let captureWidth = CVPixelBufferGetWidth(imageBuffer)
        let captureHeight = CVPixelBufferGetHeight(imageBuffer)
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let ciContext = CIContext(options: nil)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        captureImage = UIImage(cgImage: cgImage, scale: 1, orientation: .leftMirrored)
        facialExpressionSession.updateFrame(withImage: captureImage, width: captureWidth, height: captureHeight)
        
        if state == .presenting {
            let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFace)
            let detectBodyPoseRequest = VNDetectHumanBodyPoseRequest(completionHandler: detectedBodyPose)
            frames += 1
            
            do {
                try sequenceHandler.perform([detectFaceRequest, detectBodyPoseRequest], on: imageBuffer, orientation: .leftMirrored)
            } catch {
                print(error.localizedDescription)
            }
        } else {
            DispatchQueue.main.async {
                self.roundRectLayer.isHidden = true
            }
        }
    }
}

extension PresentationViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else {
            return nil
        }
        return eyeContactSession.faceNode()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let sceneTransformInfo = sceneView.pointOfView?.transform else {
            return
        }
        eyeContactSession.updateDevicePlane(newTransform: sceneTransformInfo)
    }
    
    // MARK: - Eye contact detection
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else {
            return
        }
        eyeContactSession.updateFaceAnchor(anchor: faceAnchor)
        
        if state == .presenting {
            if eyeContactSession.isWithAttention() {
                focusDetected += 1
            } else {
                lostFocusDetected += 1
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
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "forwardToFeedback" {
            let feedbackView = segue.destination as! FeedbackViewController
            feedbackView.totalSmiles = totalSmiles
            feedbackView.totalHandMoves = totalHandMoves
            feedbackView.totalLooks = totalLooks
            feedbackView.videoURL = videoURL
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
        state = .preparing
        
        handPoseSession.reset()
        
        lblPrepareCountdown.isHidden = true
        countdownBackgroundView.isHidden = true
        lblCountdown.text = "00:15"
    }
    
    func resetRecordingIndicator() {
        recordingIndicatorView.isHidden = true
        recordingIndicator.isHidden = false
    }
    
    func startRecordingIndicator() {
        recordingIndicatorView.isHidden = false
        
        indicatorTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.recordingIndicator.isHidden = !self.recordingIndicator.isHidden
        })
    }
    
    func startPresentationCountdown() {
        lblPrepareCountdown.text = "5"
        lblPrepareCountdown.isHidden = false
        
        let _ = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true, block: prepareCountdown)
    }
    
    func prepareCountdown(timer: Timer) {
        countdown -= 1
        lblPrepareCountdown.text = "\(countdown)"
        
        if countdown == 0 {
            timer.invalidate()
            lblPrepareCountdown.isHidden = true
            countdownBackgroundView.isHidden = false
            
            if supportsDepthCamera {
                startRecordingIndicator()
                recorder?.record()
            }
            
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
            
            recorder?.stop() { videoURL in
                DispatchQueue.main.async {
                    print(videoURL)
                    self.videoURL = videoURL
                    self.performSegue(withIdentifier: "forwardToFeedback", sender: self)
                }
            }
        }
    }
}

