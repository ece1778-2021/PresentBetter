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
    
    static func shapeForEyeCalibrationDot(insets: UIEdgeInsets) -> [CAShapeLayer] {
        var shapes = [CAShapeLayer]()
        
        let path1 = UIBezierPath(arcCenter: CGPoint(x: 10 + 36 / 2, y: insets.top + 10 + 36 / 2), radius: 18, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        let shape1 = CAShapeLayer()
        shape1.path = path1.cgPath
        shape1.fillColor = UIColor.white.cgColor
        shape1.strokeColor = UIColor.gray.cgColor
        shape1.lineWidth = 3.0
        shapes.append(shape1)
        
        let path2 = UIBezierPath(arcCenter: CGPoint(x: 10 + 36 / 2, y: insets.top + 10 + 36 / 2), radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        let shape2 = CAShapeLayer()
        shape2.path = path2.cgPath
        shape2.fillColor = UIColor.gray.cgColor
        shapes.append(shape2)
        
        let path3 = UIBezierPath(arcCenter: CGPoint(x: 10 + 36 / 2, y: insets.top + 10 + 36 / 2), radius: 21, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        let shape3 = CAShapeLayer()
        shape3.path = path3.cgPath
        shape3.fillColor = UIColor.clear.cgColor
        shape3.strokeColor = UIColor.white.cgColor
        shape3.lineWidth = 3.0
        shape3.strokeEnd = 0
        shapes.append(shape3)
        
        return shapes
    }
}
