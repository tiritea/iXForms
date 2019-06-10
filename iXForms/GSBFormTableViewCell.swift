//
//  GSBFormTableViewCell.swift
//  iXForms
//
//  Created by MBS GoGet on 11/02/19.
//  Copyright © 2019 Xiphware. All rights reserved.
//

import UIKit
import os.log

class GSBFormTableViewCell: UITableViewCell, GSBListTableViewCell {
    
    // GSBListTableViewCell
    func initWith(object: Any) -> UITableViewCell {
        let form: XForm = object as! XForm
        textLabel?.text = form.id + "\n" + (form.name ?? "")
        textLabel?.numberOfLines = 0
        detailTextLabel?.text = form.version
        accessoryType = .detailButton
        
        // icon shows form status
        imageView?.image = UIImage(named: "icons8-cloud-checked-filled-30")?.withRenderingMode(.alwaysTemplate) // open (remote)
        imageView?.image = UIImage(named: "icons8-check-mark-symbol-filled-30")?.withRenderingMode(.alwaysTemplate) // open
        imageView?.tintColor = UIColor.green
        
        imageView?.image = UIImage(named: "icons8-cloud-cross-filled-30")?.withRenderingMode(.alwaysTemplate) // closed (remote)
        imageView?.image = UIImage(named: "icons8-cancel-filled-30")?.withRenderingMode(.alwaysTemplate) // closed
        imageView?.tintColor = UIColor.red

        return self
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: UITableViewCell.CellStyle.value1, reuseIdentifier: reuseIdentifier)
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
