//
//  DrawingBoundingBoxView.swift
//  SSDMobileNet-CoreML
//
//  Created by GwakDoyoung on 04/02/2019.
//  Modified by Cole Johnson on 2025/12/17
//

import UIKit
import Vision

/// A view responsible for drawing bounding boxes and labels
/// for objects detected by a Vision/CoreML model.
class DrawingBoundingBoxView: UIView {
    
    // MARK: - Static Properties
    
    /// Stores assigned colors for each detected label to maintain consistency.
    static private var colors: [String: UIColor] = [:]
    
    // MARK: - Color Helper
    
    /// Returns a consistent color for a given label, or generates a new random color.
    /// - Parameter label: The object label for which to get a color.
    /// - Returns: UIColor assigned to the label.
    public func labelColor(with label: String) -> UIColor {
        if let color = DrawingBoundingBoxView.colors[label] {
            return color
        } else {
            let color = UIColor(
                hue: .random(in: 0...1),
                saturation: 1,
                brightness: 1,
                alpha: 0.8
            )
            DrawingBoundingBoxView.colors[label] = color
            return color
        }
    }
    
    // MARK: - Predicted Objects
    
    /// Array of detected objects from Vision/CoreML.
    /// Setting this property automatically redraws bounding boxes and labels.
    public var predictedObjects: [VNRecognizedObjectObservation] = [] {
        didSet {
            self.drawBoxes(with: predictedObjects)
            self.setNeedsDisplay()
        }
    }
    
    // MARK: - Drawing Methods
    
    /// Removes all previous subviews and draws new bounding boxes for predictions.
    /// - Parameter predictions: Array of VNRecognizedObjectObservation.
    func drawBoxes(with predictions: [VNRecognizedObjectObservation]) {
        subviews.forEach({ $0.removeFromSuperview() })
        for prediction in predictions {
            createLabelAndBox(prediction: prediction)
        }
    }
    
    /// Creates a UIView box and UILabel for a detected object and adds them to the view.
    /// - Parameter prediction: A VNRecognizedObjectObservation representing the detected object.
    func createLabelAndBox(prediction: VNRecognizedObjectObservation) {
        let labelString: String? = prediction.label
        let color: UIColor = labelColor(with: labelString ?? "N/A")
        
        // Convert normalized coordinates to view coordinates
        let scale = CGAffineTransform.identity.scaledBy(x: bounds.width, y: bounds.height)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
        let bgRect = prediction.boundingBox.applying(transform).applying(scale)
        
        // Bounding box view
        let bgView = UIView(frame: bgRect)
        bgView.layer.borderColor = color.cgColor
        bgView.layer.borderWidth = 4
        bgView.backgroundColor = UIColor.clear
        addSubview(bgView)
        
        // Label above the bounding box
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        label.text = labelString ?? "N/A"
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor.black
        label.backgroundColor = color
        label.sizeToFit()
        label.frame = CGRect(
            x: bgRect.origin.x,
            y: bgRect.origin.y - label.frame.height,
            width: label.frame.width,
            height: label.frame.height
        )
        addSubview(label)
    }
}

// MARK: - VNRecognizedObjectObservation Extension

extension VNRecognizedObjectObservation {
    /// Returns the first label's identifier of the observation.
    var label: String? {
        return self.labels.first?.identifier
    }
}

// MARK: - CGRect Extension

extension CGRect {
    /// Returns a string representation of the CGRect with specified decimal digits.
    /// - Parameter digit: Number of decimal digits.
    /// - Returns: String like "(x, y, width, height)" with formatted decimals.
    func toString(digit: Int) -> String {
        let xStr = String(format: "%.\(digit)f", origin.x)
        let yStr = String(format: "%.\(digit)f", origin.y)
        let wStr = String(format: "%.\(digit)f", width)
        let hStr = String(format: "%.\(digit)f", height)
        return "(\(xStr), \(yStr), \(wStr), \(hStr))"
    }
}
