import ARKit
import ARVideoKit
import AVFoundation
import CoreML
import Speech
import UIKit
import Vision

enum PresentationState {
    case preparing
    case presenting
}

enum PresentationMode {
    case trainingFacial
    case trainingEye
    case trainingGesture
    case trainingSpeech
    case presenting
}

enum TrainingState {
    case tooFew
    case good
    case tooMuch
}

struct SpeechWords {
    var totalLength: Int
    var atTime: Int
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
    @IBOutlet var tipBackgroundView: UIView!
    @IBOutlet var lblTip: UILabel!
    
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
    var isSpeechAble = false
    
    // UIImage representation of captured CVPixelBuffer
    var captureImage: UIImage?
    
    var roundRectLayer: CAShapeLayer!
    
    // Presentation quality measurement sessions
    var eyeContactSession: EyeContactSession!
    var facialExpressionSession: FacialExpressionSession!
    var handPoseSession: HandPoseSession!
    var speechSession: SpeechSession!
    
    // Presentation parameters
    var mode: PresentationMode = .presenting    // Presentation mode: Training or Presenting?
    var state: PresentationState = .preparing
    var countdown = 5
    var countdownMax = 30
    var smiledInSpan = false, totalSmiles = 0
    var handMovedInSpan = false, totalHandMoves = 0
    var focusDetected = 0, lostFocusDetected = 0, totalLooks = 0
    var averageWordsPerMinute: CGFloat = 0
    var isPresentationRecorded = true
    
    // Training parameters
    var recentFeedbacks = [Bool]()
    var trainingState: TrainingState = .good
    var recentTrainingState = [TrainingState]()
    var firstReachWindow = false
    
    // Speech training parameters
    var recognizedWords = [SpeechWords]()
    var recognitionFinishSignal: DispatchSemaphore?
    
    // Performance metrics: Number of frames processed during a session
    var frames = 0
    var indicatorTimer: Timer?
    
    // Information passed to Feedback View
    var highScore = 0
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        highScore = highScorePassed
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        supportsDepthCamera = ARFaceTrackingConfiguration.isSupported
        sequenceHandler = VNSequenceRequestHandler()
        roundRectLayer = CAShapeLayer()
        roundRectLayer.fillColor = UIColor.clear.cgColor
        roundRectLayer.lineWidth = 2.0
        roundRectLayer.strokeColor = UIColor.red.cgColor
        
        recordingIndicatorView.isHidden = true
        recordingIndicator.layer.cornerRadius = 5.0
        
        tipBackgroundView.layer.cornerRadius = 35.0
        tipBackgroundView.isHidden = true
        
        facialExpressionSession = FacialExpressionSession(boundingFrame: view.frame)
        handPoseSession = HandPoseSession()
        speechSession = SpeechSession()
        
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
                self.isSpeechAble = self.speechSession.initializeSpeechRecognition()
                self.initializeAVAudio()
                self.tryStartPresentation = true
                self.startARSession()
            } else {
                // Fallback to traditional AVCaptureSession if the device has no TrueDepth camera.
                if self.configSuccessful {
                    self.captureSession.startRunning()
                    
                    PresentationPreparationViewController.showView(self, mode: self.mode == .presenting)
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
        if mode != .trainingEye {
            eyeContactSession = EyeContactSession(currentScene: sceneView.scene)
        } else {
            eyeContactSession = EyeContactSession(currentScene: sceneView.scene, hideLaser: false)
        }
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
    
    // MARK: - Speech recognition session
    func processSpeechRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let segments = result.bestTranscription.segments
            
            if result.isFinal {
                print(result.bestTranscription.formattedString)
                if segments.count > 0 {
                    let duration = CGFloat(segments.last!.timestamp + segments.last!.duration - segments.first!.timestamp)
                    if duration > 0 {
                        averageWordsPerMinute = CGFloat(segments.count) / duration * 60
                    } else {
                        averageWordsPerMinute = 0
                    }
                } else {
                    averageWordsPerMinute = 0
                }
                
                recognitionFinishSignal?.signal()
            }
            
            recognizedWords.append(SpeechWords(totalLength: segments.count, atTime: countdown))
        } else if error != nil {
            recognitionFinishSignal?.signal()
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
                PresentationPreparationViewController.showView(self, mode: self.mode == .presenting)
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
        if segue.identifier == "forwardToReport" {
            let feedbackView = segue.destination as! PresentationReportViewController
            feedbackView.totalSmiles = totalSmiles
            feedbackView.totalHandMoves = totalHandMoves
            feedbackView.totalLooks = totalLooks
            feedbackView.videoURL = videoURL
            feedbackView.highScore = highScore
            feedbackView.averageWordsPerMinute = averageWordsPerMinute
            feedbackView.mode = .new
        } else if segue.identifier == "forwardToTrainingResult" {
            let resultView = segue.destination as! TrainingResultViewController
            if mode == .trainingFacial {
                resultView.mode = .facialExpression
                resultView.totalPasses = totalSmiles
            } else if mode == .trainingGesture {
                resultView.mode = .gesture
                resultView.totalPasses = totalHandMoves
            } else if mode == .trainingEye {
                resultView.mode = .eyeContact
                resultView.totalPasses = totalLooks
            } else if mode == .trainingSpeech {
                resultView.mode = .speech
                resultView.averageWordsPerMinute = Int(averageWordsPerMinute)
                print("Average speech pace: \(averageWordsPerMinute) wpm")
            }
        }
    }
    
    func resetPresentationCountdown() {
        frames = 0
        countdown = 5
        countdownMax = 30
        smiledInSpan = false
        totalSmiles = 0
        handMovedInSpan = false
        totalHandMoves = 0
        focusDetected = 0
        lostFocusDetected = 0
        totalLooks = 0
        recognizedWords.removeAll()
        averageWordsPerMinute = 0
        state = .preparing
        
        recentFeedbacks.removeAll()
        trainingState = .good
        recentTrainingState.removeAll()
        firstReachWindow = false
        
        handPoseSession.reset()
        
        lblPrepareCountdown.isHidden = true
        countdownBackgroundView.isHidden = true
        
        if mode == .presenting {
            lblCountdown.text = "00:15"
        } else {
            lblCountdown.text = "00:20"
        }
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
            
            if supportsDepthCamera && isPresentationRecorded {
                startRecordingIndicator()
                recorder?.record()
            }
            
            if mode == .presenting {
                countdown = 30
                countdownMax = 30
            } else {
                countdown = 40
                countdownMax = 40
            }
            
            if isSpeechAble {
                let _ = speechSession.startRecognition(responseHandler: processSpeechRecognition)
                recognizedWords.append(SpeechWords(totalLength: 0, atTime: countdownMax))
            }
            
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
            if mode == .trainingFacial {
                recentFeedbacks.append(true)
                processTrainingData()
            }
            totalSmiles += 1
        } else {
            if mode == .trainingFacial {
                recentFeedbacks.append(false)
                processTrainingData()
            }
        }
        
        if handMovedInSpan {
            handMovedInSpan = false
            if mode == .trainingGesture {
                recentFeedbacks.append(true)
                processTrainingData()
            }
            totalHandMoves += 1
        } else {
            if mode == .trainingGesture {
                recentFeedbacks.append(false)
                processTrainingData()
            }
        }
        
        if focusDetected > lostFocusDetected {
            if mode == .trainingEye {
                recentFeedbacks.append(true)
                processTrainingData()
            }
            totalLooks += 1
        } else {
            if mode == .trainingEye {
                recentFeedbacks.append(false)
                processTrainingData()
            }
        }
        focusDetected = 0
        lostFocusDetected = 0
        
        if mode == .trainingSpeech {
            processSpeechTrainingData()
        }
        
        if countdown == 0 {
            timer.invalidate()
            speechSession.stopRecognition()
            
            if supportsDepthCamera && isPresentationRecorded {
                recorder?.stop() { videoURL in
                    DispatchQueue.main.async {
                        self.waitForSpeechRecognitionAndForwardToFeedback(videoURL: videoURL)
                    }
                }
            } else {
                self.waitForSpeechRecognitionAndForwardToFeedback(videoURL: nil)
            }
        }
    }
    
    func waitForSpeechRecognitionAndForwardToFeedback(videoURL: URL?) {
        if recognizedWords.count > 0 {
            DispatchQueue(label: "waitForSpeechRecognition").async {
                self.recognitionFinishSignal = DispatchSemaphore(value: 0)
                
                DispatchQueue.main.async {
                    LoadingViewController.showView(self)
                }
                
                let _ = self.recognitionFinishSignal?.wait(timeout: .now() + 60)
                
                DispatchQueue.main.async {
                    self.presentedViewController?.dismiss(animated: true) {
                        self.forwardToFeedback(videoURL: videoURL)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.forwardToFeedback(videoURL: videoURL)
            }
        }
    }
    
    func processSpeechTrainingData() {
        let tips = ["Speak faster.", "Great! Keep going.", "Speak slower."]
        var windowTrainingState: TrainingState
        
        if recognizedWords.count > 0 {
            if recognizedWords.first!.atTime - countdown >= 10 {
                let slice = recognizedWords.filter { $0.atTime - countdown <= 10 }
                
                let newTip: String
                let wordsPerMinute: CGFloat
                if slice.count > 0 {
                    if slice.last!.totalLength >= slice.first!.totalLength {
                        wordsPerMinute = CGFloat(slice.last!.totalLength - slice.first!.totalLength) / 4.8 * 60.0
                    } else {
                        wordsPerMinute = 150
                    }
                } else {
                    wordsPerMinute = 0
                }
                
                if wordsPerMinute < 140 {
                    newTip = tips[0]
                    windowTrainingState = .tooFew
                    recentTrainingState.append(.tooFew)
                } else if wordsPerMinute >= 140 && wordsPerMinute <= 160 {
                    newTip = tips[1]
                    windowTrainingState = .good
                    recentTrainingState.append(.good)
                } else {
                    newTip = tips[2]
                    windowTrainingState = .tooMuch
                    recentTrainingState.append(.tooMuch)
                }
                
                if recentTrainingState.count > 10 {
                    recentTrainingState.removeFirst()
                }
                
                if firstReachWindow == false {
                    firstReachWindow = true
                    trainingState = windowTrainingState
                    animateTip(firstTip: true, newTip: newTip)
                } else {
                    if recentTrainingState.count >= 2 {
                        let mostRecentTrainingState = recentTrainingState.suffix(2)
                        if windowTrainingState != trainingState && (mostRecentTrainingState.filter { $0 == windowTrainingState }.count == 2) {
                            trainingStateTransition(newState: windowTrainingState)
                            animateTip(firstTip: false, newTip: newTip)
                        }
                    }
                }
            }
        }
    }
    
    func processTrainingData() {
        var tips: [String]
        var windowTrainingState: TrainingState
        
        if mode == .trainingFacial {
            tips = ["Smile more.", "Great! Keep going.", "Smile less."]
        } else if mode == .trainingGesture {
            tips = ["Move your arms more.", "Great! Keep going.", "Move your arms less."]
        } else {
            tips = ["Look at camera more.", "Great! Keep going.", "Look at camera less."]
        }
        
        if recentFeedbacks.count >= 10 {
            if recentFeedbacks.count > 10 {
                recentFeedbacks.removeFirst()
            }
            
            let newTip: String
            let totalMatches = recentFeedbacks.filter { $0 == true }.count
            if totalMatches < 3 {
                newTip = tips[0]
                windowTrainingState = .tooFew
                recentTrainingState.append(.tooFew)
            } else if totalMatches >= 3 && totalMatches <= 8 {
                newTip = tips[1]
                windowTrainingState = .good
                recentTrainingState.append(.good)
            } else {
                newTip = tips[2]
                windowTrainingState = .tooMuch
                recentTrainingState.append(.tooMuch)
            }
            
            if recentTrainingState.count > 10 {
                recentTrainingState.removeFirst()
            }
            
            if firstReachWindow == false {
                firstReachWindow = true
                trainingState = windowTrainingState
                animateTip(firstTip: true, newTip: newTip)
            } else {
                if recentTrainingState.count >= 2 {
                    let mostRecentTrainingState = recentTrainingState.suffix(2)
                    if windowTrainingState != trainingState && (mostRecentTrainingState.filter { $0 == windowTrainingState }.count == 2) {
                        trainingStateTransition(newState: windowTrainingState)
                        animateTip(firstTip: false, newTip: newTip)
                    }
                }
            }
        }
    }
    
    func trainingStateTransition(newState: TrainingState) {
        if trainingState == .tooFew {
            if newState == .good || newState == .tooMuch {
                trainingState = .good
            }
        } else if trainingState == .good {
            trainingState = newState
        } else {
            if newState == .good || newState == .tooFew {
                trainingState = .good
            }
        }
    }
    
    func animateTip(firstTip: Bool, newTip: String) {
        if firstTip {
            tipBackgroundView.alpha = 0
            tipBackgroundView.isHidden = false
            tipBackgroundView.transform = CGAffineTransform(translationX: 0, y: 30)
            lblTip.text = newTip
            UIView.animate(withDuration: 0.25, animations: {
                self.tipBackgroundView.alpha = 1
                self.tipBackgroundView.transform = CGAffineTransform.identity
            })
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.tipBackgroundView.alpha = 0
                self.tipBackgroundView.transform = CGAffineTransform(translationX: 0, y: -30)
            }) { _ in
                self.tipBackgroundView.transform = CGAffineTransform(translationX: 0, y: 30)
                self.lblTip.text = newTip
                UIView.animate(withDuration: 0.25, animations: {
                    self.tipBackgroundView.alpha = 1
                    self.tipBackgroundView.transform = CGAffineTransform.identity
                })
            }
        }
    }
    
    func forwardToFeedback(videoURL: URL?) {
        if let videoURL = videoURL {
            self.videoURL = videoURL
        }
        
        if mode == .presenting {
            self.performSegue(withIdentifier: "forwardToReport", sender: self)
        } else {
            self.performSegue(withIdentifier: "forwardToTrainingResult", sender: self)
        }
    }
}

