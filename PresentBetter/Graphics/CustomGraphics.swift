import UIKit

class CustomGraphics {
    static func pathForHumanUpperBody(_ bounds: CGRect) -> UIBezierPath {
        let width = bounds.width
        let height = bounds.height
        
        let x = bounds.origin.x
        let y = bounds.origin.y
        
        let ovalRect = CGRect(x: x + width / 3, y: y + 0, width: width / 3, height: height / 3)
        let path = UIBezierPath(ovalIn: ovalRect)
        
        path.move(to: CGPoint(x: x + width / 3, y: y + height / 3))
        path.addLine(to: CGPoint(x: x + width / 6, y: y + height / 2))
        path.addLine(to: CGPoint(x: x + 5, y: y + height / 4 * 3))
        path.addLine(to: CGPoint(x: x + width / 8, y: y + height / 8 * 7))
        path.addLine(to: CGPoint(x: x + width / 3, y: y + height / 8 * 5))
        
        path.move(to: CGPoint(x: x + width - width / 3, y: y + height / 3))
        path.addLine(to: CGPoint(x: x + width - width / 6, y: y + height / 2))
        path.addLine(to: CGPoint(x: x + width - 5, y: y + height / 4 * 3))
        path.addLine(to: CGPoint(x: x + width - width / 8, y: y + height / 8 * 7))
        path.addLine(to: CGPoint(x: x + width - width / 3, y: y + height / 8 * 5))
        
        path.move(to: CGPoint(x: x + width / 3, y: y + height / 8 * 5))
        path.addLine(to: CGPoint(x: x + width / 3, y: y + height - 5))
        path.addLine(to: CGPoint(x: x + width - width / 3, y: y + height - 5))
        path.addLine(to: CGPoint(x: x + width - width / 3, y: y + height / 8 * 5))
        
        return path
    }
}
