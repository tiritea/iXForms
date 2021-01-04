//
//  GSBCompassView.swift
//  GSBCompassViewApp
//
//  Created by Gareth Bestor on 3/01/21.
//  Copyright © 2021 Xiphware. All rights reserved.
//
//  Inspired by https://github.com/programmingwithswift/Compass

import UIKit
import CoreGraphics

public class GSBCompassView: UIView {
    // Customize these to suit
    static let arrowColor = UIColor.systemBlue
    static let degreeFontSize: CGFloat = 16
    static let cardinalFontSize: CGFloat = 20
    
    public var compassDegress: Double // <=== ***IMPORANT*** To animate compass set this and call setNeedsDisplay()
    
    var segments: Int
    let degreeFont: [NSAttributedString.Key : Any] = [.font: UIFont.systemFont(ofSize: GSBCompassView.degreeFontSize)]
    let cardinalFont: [NSAttributedString.Key : Any] = [.font: UIFont.boldSystemFont(ofSize: GSBCompassView.cardinalFontSize)]

    // Must adjust starting drawing angle to match physical device orientation
    var startingAngle: CGFloat {
        // https://stackoverflow.com/questions/38894031/swift-how-to-detect-orientation-changes
        let interfaceOrientation: UIInterfaceOrientation?
        if #available(iOS 13.0, *) {
            interfaceOrientation = UIApplication.shared.windows.first?.windowScene!.interfaceOrientation
        } else {
            interfaceOrientation = UIApplication.shared.statusBarOrientation
        }
        
        switch interfaceOrientation {
        case .landscapeLeft:
            return -CGFloat.pi/2
        case .landscapeRight:
            return CGFloat.pi/2
        case .portraitUpsideDown:
            return 0
        default: //portrait
            return CGFloat.pi
        }
    }
    
    init(compassHeading: Double = 0, segments: Int = 12) {
        self.compassDegress = compassHeading // initial compass direction, default 0
        self.segments = segments // default 12 directions, ie 30deg increments. Change with GSBCompassView(segments: 8), ie 45deg increments
        super.init(frame: CGRect.zero)
        self.backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoder not supported")
    }
   
    // For maximum redraw speed use CoreGraphics
    public override func draw(_ rect: CGRect) {
        let halfWidth = rect.width/2
        let halfHeight = rect.height/2
        let radius = min(halfWidth, halfHeight) - GSBCompassView.degreeFontSize // inset drawing radius so degrees text isnt clipped
        let halfRadius = radius/2
        let deltaDeg: CGFloat = CGFloat.pi * 2 / CGFloat(segments)
        
        guard let drawing = UIGraphicsGetCurrentContext() else { return }
        drawing.setLineCap(.round)
        drawing.setLineJoin(.miter)
        drawing.translateBy(x: halfWidth, y: halfHeight) // center compass in view
        
        // Draw direction arrow
        let base = CGPoint(x: 0, y: halfRadius - GSBCompassView.cardinalFontSize)
        let tip = CGPoint(x: 0, y: -(halfRadius - GSBCompassView.cardinalFontSize - 5))
        drawing.move(to: base)
        drawing.addLine(to: tip)
        drawing.move(to: CGPoint(x: tip.x-15, y: tip.y+20))
        drawing.addLine(to: tip)
        drawing.addLine(to: CGPoint(x: tip.x+15, y: tip.y+20))
        GSBCompassView.arrowColor.setStroke()
        drawing.setLineWidth(4)
        drawing.strokePath()
        
        var angle = startingAngle + CGFloat(compassDegress) * CGFloat.pi/180
        drawing.rotate(by: angle) // align drawing to current compass direction
        
        // Draw compass markers around circumference
        for degrees in stride(from: 0, to: 360, by: 360/segments) {
            drawing.translateBy(x: 0, y: radius)
            
            // Compass degrees
            drawing.rotate(by: -angle) // re-align text so that it remains horizontal
            let str = String(degrees) as NSString
            let strRect = str.boundingRect(with: bounds.size, options: [], attributes: degreeFont, context: nil)
            str.draw(at: CGPoint(x: -strRect.width/2, y: -strRect.height/2), withAttributes: degreeFont) // center drawing text
            drawing.rotate(by: angle)
            
            // Cardinal direction, if applicable
            if (degrees % 90 == 0) {
                let cardinal = ["N", "E", "S", "W"][degrees/90]
                drawing.translateBy(x: 0, y: -halfRadius)
                drawing.rotate(by: -angle) // re-align text so that it remains horizontal
                let strRect = cardinal.boundingRect(with: rect.size, options: [], attributes: cardinalFont, context: nil)
                cardinal.draw(at: CGPoint(x: -strRect.width/2, y: -strRect.height/2), withAttributes: cardinalFont) // center drawing text
                drawing.rotate(by: angle)
                drawing.translateBy(x: 0, y: -halfRadius) // move back to center
            } else {
                drawing.translateBy(x: 0, y: -radius) // move back to center
            }
            
            // Compass mark
            drawing.move(to: CGPoint(x: 0, y: halfRadius + GSBCompassView.cardinalFontSize))
            drawing.addLine(to: CGPoint(x: 0, y: radius - GSBCompassView.degreeFontSize - 5))
            if (degrees == 0) { // North marker
                UIColor.black.setStroke()
                drawing.setLineWidth(4)
            } else {
                UIColor.gray.setStroke()
                drawing.setLineWidth(2)
            }
            drawing.strokePath()
            
            // rotate drawing for next compass marker...
            drawing.rotate(by: deltaDeg)
            angle += deltaDeg
        }
    }
}
