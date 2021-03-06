//
//  UIColor+.swift
//  iXForms
//
//  Created by MBS GoGet on 21/06/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(hex: Int) {
        self.init(
            red: (hex >> 16) & 0xFF,
            green: (hex >> 8) & 0xFF,
            blue: hex & 0xFF
        )
    }
    
    func complement() -> UIColor {
        let ciColor = CIColor(color: self)
        return UIColor(red: (1.0 - ciColor.red), green: (1.0 - ciColor.green), blue: (1.0 - ciColor.blue), alpha: 1.0)
    }
    
    // https://stackoverflow.com/questions/19032940
    static var systemBlue: UIColor {
        return UIButton(type: .system).tintColor
    }
    
    static var systemDetailTextLabel: UIColor {
        return UITableViewCell.init(style: .value1, reuseIdentifier: nil).detailTextLabel!.textColor
    }

    static var control: UIColor {
        return UIColor(hex: 0x6a5acd)
    }

    static var tomato: UIColor {
        return UIColor(hex: 0xff6347)
    }    
}

