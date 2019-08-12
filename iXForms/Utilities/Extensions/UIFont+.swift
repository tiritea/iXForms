//
//  UIFont+.swift
//  iXForms
//
//  Created by MBS GoGet on 21/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit

extension UIFont {
    func bold() -> UIFont {
        let traits = fontDescriptor.symbolicTraits.rawValue | UIFontDescriptor.SymbolicTraits.traitBold.rawValue
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(rawValue: traits))!, size: 0)
    }
    
    func italic() -> UIFont {
        let traits = fontDescriptor.symbolicTraits.rawValue | UIFontDescriptor.SymbolicTraits.traitItalic.rawValue
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(rawValue: traits))!, size: 0)
    }
    
    func regular() -> UIFont {
        let traits = fontDescriptor.symbolicTraits.rawValue & ~UIFontDescriptor.SymbolicTraits.traitBold.rawValue & ~UIFontDescriptor.SymbolicTraits.traitItalic.rawValue
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(rawValue: traits))!, size: 0)
    }
}
