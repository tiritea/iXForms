//
//  GSBFormTableViewCell.swift
//  iXForms
//
//  Created by MBS GoGet on 11/02/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

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
}

class GSBFormTableViewCell: UITableViewCell, GSBListTableViewCell {
    
    // GSBListTableViewCell
    func initWith(object: Any) -> UITableViewCell {
        let form: XForm = object as! XForm
        
        if (form.name != nil && form.name!.count > 0) {
            textLabel?.text = form.name
            textLabel?.font = textLabel?.font.regular()
        } else {
            textLabel?.text = "untitled"
            textLabel?.font = textLabel?.font.italic()
        }
        
        if (form.version != nil && form.version!.count > 0) {
            detailTextLabel?.text = form.id + " (" + (form.version!) + ")"
        } else {
            detailTextLabel?.text = form.id
        }
        
        // icon for status
        var icon: UIImage?
        var tint: UIColor?
        switch form.state.value {
        case FormState.open.rawValue:
            if (form.xml != nil) { // on device
                icon = UIImage(named: "icons8-check-mark-symbol-filled-30")
            } else { // must download from server
                icon = UIImage(named: "icons8-download-from-cloud-filled-30")
            }
            tint = FormState.open.color()
        case FormState.closing.rawValue:
            if (form.xml != nil) { // on device but can still be submitted
                icon = UIImage(named: "icons8-check-mark-symbol-filled-30")
            } else { // on server and cannot be downloaded
                icon = UIImage(named: "icons8-cloud-cross-filled-30")
            }
            tint = FormState.closing.color()
        case FormState.closed.rawValue:
            if (form.xml != nil) { // on device
                icon = UIImage(named: "icons8-cancel-filled-30")
            } else { // on server
                icon = UIImage(named: "icons8-cloud-cross-filled-30")
            }
            tint = FormState.closed.color()
        default:
            assertionFailure("unrecognized state")
        }
        imageView?.image = icon?.withRenderingMode(.alwaysTemplate)
        imageView?.tintColor = tint!
        return self
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: reuseIdentifier)
        textLabel?.numberOfLines = 0
        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.textColor = UIColor.gray
        accessoryType = .detailButton
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
