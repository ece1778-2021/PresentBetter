import CoreML
import Foundation
import Vision

enum EmotionClasses {
    case Angry
    case Disgust
    case Fear
    case Happy
    case Sad
    case Surprise
    case Neutral
}

class MLProvider {
    static let EmotionTextMap: [EmotionClasses: String] = [
        .Angry: "Angry",
        .Disgust: "Disgust",
        .Fear: "Fear",
        .Happy: "Happy",
        .Sad: "Sad",
        .Surprise: "Surprise",
        .Neutral: "Neutral"
    ]
    
    var emotionModel: MLModel?
    
    init() {
        emotionModel = loadModel(name: "emotion_image_input")
    }
    
    fileprivate func loadModel(name: String) -> MLModel? {
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
            return nil
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try MLModel(contentsOf: modelURL, configuration: config)
            return model
        } catch {
            print("Error loading model: \(error.localizedDescription)")
            return nil
        }
    }
    
    func predictEmotion(image: CGImage) -> EmotionClasses? {
        let EmotionClassesMap: [EmotionClasses] = [.Angry, .Disgust, .Fear, .Happy, .Sad, .Surprise, .Neutral]
        
        guard let model = emotionModel else {
            return nil
        }
        
        guard let imageConstraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
            return nil
        }
        let imageOptions: [MLFeatureValue.ImageOption: Any] = [
            MLFeatureValue.ImageOption.cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
        ]
        
        do {
            let featureValue = try MLFeatureValue(cgImage: image, constraint: imageConstraint, options: imageOptions)
            let featureProvider = try MLDictionaryFeatureProvider(dictionary: ["image": featureValue])
            
            let prediction = try model.prediction(from: featureProvider)
            guard let value = prediction.featureValue(for: "Identity")?.multiArrayValue else {
                return nil
            }
            
            let pointer = try UnsafeBufferPointer<Float32>(value)
            let emotionClassOnehot = Array(pointer)
            
            guard let onehotMax = pointer.max(),
                  let emotionClassRaw = emotionClassOnehot.firstIndex(of: onehotMax)
            else {
                return nil
            }
            //print(onehotMax)
            return EmotionClassesMap[emotionClassRaw]
        } catch {
            print("Error running model: \(error.localizedDescription)")
            return nil
        }
    }
}

let MLDataProvider = MLProvider()
