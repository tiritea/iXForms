//
//  GSBGroupTableViewCell.swift
//  iXForms
//
//  Created by MBS GoGet on 11/02/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

class GSBGroupTableViewCell: UITableViewCell, GSBListTableViewCell {
    
    // GSBListTableViewCell
    func initWith(object: Any) -> UITableViewCell {
        let group: Group = object as! Group
        
        if (group.name != nil && group.name!.count > 0) {
            textLabel?.text = group.id + ". " + group.name!
            textLabel?.font = textLabel?.font.regular()
        } else {
            textLabel?.text = group.id + ". " + "untitled"
            textLabel?.font = textLabel?.font.italic()
        }
        
        if (group.forms != nil) { // RealmOptional
            let forms = group.forms.value!
            detailTextLabel?.text = String(forms) + " form" + ((forms == 1) ? "" : "s")
        } else {
            detailTextLabel?.text = "—" // em-dash; not yet known
        }
        return self
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: UITableViewCell.CellStyle.value1, reuseIdentifier: reuseIdentifier)
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
