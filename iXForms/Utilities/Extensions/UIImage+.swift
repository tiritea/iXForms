//
//  UIImage+.swift
//  XiphForms
//
//  Created by MBS GoGet on 15/09/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit

extension UIImage {
    
    // https://gist.github.com/ppamorim/cc79170422236d027b2b
    func withInset(_ insets: UIEdgeInsets) -> UIImage? {
        let cgSize = CGSize(width: self.size.width + insets.left * self.scale + insets.right * self.scale,
                            height: self.size.height + insets.top * self.scale + insets.bottom * self.scale)
        
        UIGraphicsBeginImageContextWithOptions(cgSize, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        
        let origin = CGPoint(x: insets.left * self.scale, y: insets.top * self.scale)
        self.draw(at: origin)
        
        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(self.renderingMode)
    }
}
