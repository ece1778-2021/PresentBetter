import AVFoundation
import UIKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession!
    var camera: AVCaptureDevice!
    var cameraInput: AVCaptureInput!
    var videoOutput: AVCaptureVideoDataOutput!
    
    var sampleBufferQueue: DispatchQueue!
    
    var accessSuccessful = false
    var configSuccessful = false
    @IBOutlet var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        //videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_444YpCbCr8]
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

    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        /*
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let yPlaneBufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
        
        let data = NSData(bytes: yPlaneBufferAddress, length: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let dataProvider = CGDataProvider(data: data) else {
            return
        }
        
        guard let imageRef = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: .byteOrder32Little, provider: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return
        }
        let image = UIImage(cgImage: imageRef)
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        */
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
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
        let image = UIImage(cgImage: imageRef, scale: 1, orientation: .right)
        
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.imageView.image = image
            }
        }
    }
    
}

