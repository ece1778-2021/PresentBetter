import UIKit

class VerbalProvider {
    static func calculateVerbalRating(_ wordsPerMinute: CGFloat) -> String {
        if wordsPerMinute == 0 {
            return "No data"
        } else if wordsPerMinute < 140 {
            return "Slow"
        } else if wordsPerMinute >= 140 && wordsPerMinute <= 160 {
            return "Normal"
        } else {
            return "Fast"
        }
    }
}
