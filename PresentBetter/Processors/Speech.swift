import AVFoundation
import Foundation
import Speech

class SpeechSession {
    var recognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var audioEngine = AVAudioEngine()
    
    func initializeSpeechRecognition() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var hasSpeechAccess = false
        
        SFSpeechRecognizer.requestAuthorization() { status in
            switch status {
            case .authorized:
                hasSpeechAccess = true
                print("Speech recognition authorized")
                semaphore.signal()
            case .denied:
                hasSpeechAccess = false
                print("Speech recognition was denied")
                semaphore.signal()
            default:
                hasSpeechAccess = false
                print("Speech access unknown")
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if hasSpeechAccess == false {
            return false
        }
        
        let locale = Locale(identifier: "en_US")
        recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer = recognizer else {
            print("Failed to create recognizer")
            return false
        }
        
        if recognizer.isAvailable == false {
            print("Speech recognition is not available")
            return false
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        if recognitionRequest == nil {
            print("Unable to create recognition request")
            return false
        }
        recognitionRequest?.requiresOnDeviceRecognition = true
        recognitionRequest?.shouldReportPartialResults = true
        
        return true
    }
    
    func startRecognition(responseHandler: @escaping ((SFSpeechRecognitionResult?, Error?) -> Void)) -> Bool {
        let audioInstance = AVAudioSession.sharedInstance()
        
        do {
            try audioInstance.setCategory(.record, mode: .measurement, options: .mixWithOthers)
            try audioInstance.setActive(true, options: .notifyOthersOnDeactivation)
        } catch let e {
            print(e)
            return false
        }
        
        guard let recognitionRequest = recognitionRequest else {
            return false
        }
        
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { result, err in
            if err != nil {
                self.stopRecognition()
            }
            responseHandler(result, err)
        }
        
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch let e {
            print(e)
            return false
        }
        
        return true
    }
    
    func stopRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
    }
}
