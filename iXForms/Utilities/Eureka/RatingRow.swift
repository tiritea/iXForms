//
//  RatingRow.swift
//  iXForms
//
//  Created by Gareth Bestor on 12/10/20.
//  Copyright © 2020 Xiphware. All rights reserved.
//

// https://github.com/xmartlabs/Eureka/issues/1275
// https://github.com/evgenyneu/Cosmos

import Eureka
import Cosmos

open class RatingCell: Cell<Double>, CellType {

    private var awakeFromNibCalled = false

    @IBOutlet open weak var titleLabel: UILabel!
    @IBOutlet open weak var valueLabel: UILabel!
    @IBOutlet weak var rating: CosmosView!

    public required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)

        NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            guard let me = self else { return }
            if me.shouldShowTitle {
                me.titleLabel = me.textLabel
                me.valueLabel = me.detailTextLabel
                me.setNeedsUpdateConstraints()
            }
        }
    }

    deinit {
        guard !awakeFromNibCalled else { return }
        NotificationCenter.default.removeObserver(self, name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        awakeFromNibCalled = true
    }

    open override func setup() {
        super.setup()
        if !awakeFromNibCalled {
            let title = textLabel
            textLabel?.translatesAutoresizingMaskIntoConstraints = false
            textLabel?.setContentHuggingPriority(UILayoutPriority(rawValue: 500), for: .horizontal)
            self.titleLabel = title
            if shouldShowTitle {
                contentView.addSubview(titleLabel)
            }
            
            let value = detailTextLabel
            value?.translatesAutoresizingMaskIntoConstraints = false
            value?.setContentHuggingPriority(UILayoutPriority(500), for: .horizontal)
            value?.adjustsFontSizeToFitWidth = true
            value?.minimumScaleFactor = 0.5
            self.valueLabel = value
            if !ratingRow.shouldHideValue {
              contentView.addSubview(valueLabel)
            }
            
            let cosmosRating = CosmosView()
            cosmosRating.translatesAutoresizingMaskIntoConstraints = false
            cosmosRating.setContentHuggingPriority(UILayoutPriority(rawValue: 500), for: .horizontal)
            cosmosRating.settings.starSize = 30.0
            cosmosRating.settings.emptyBorderWidth = 1
            cosmosRating.settings.filledBorderWidth = 5
            self.rating = cosmosRating
            contentView.addSubview(cosmosRating)
            
            setNeedsUpdateConstraints()
        }
        selectionStyle = .none
        
        rating.didFinishTouchingCosmos = { rating in
            self.row.value = rating
        }
    }

    open override func update() {
        super.update()
        titleLabel.text = row.title
        titleLabel.isHidden = !shouldShowTitle
        valueLabel.text = row.displayValueFor?(row.value)
        valueLabel.isHidden = ratingRow.shouldHideValue
        rating.rating = row.value ?? 0.0
        
        rating.isUserInteractionEnabled = !row.isDisabled
        rating.settings.filledColor = row.isDisabled ? .systemGray : .systemBlue
        rating.settings.emptyBorderColor = rating.settings.filledColor
        rating.settings.filledBorderColor = rating.settings.filledColor
    }

    @objc func valueChanged() {
        row.value = rating.rating
        row.updateCell()
    }

    var shouldShowTitle: Bool {
        return row?.title?.isEmpty == false
    }

    private var ratingRow: RatingRow {
        return row as! RatingRow
    }
    
    open override func updateConstraints() {
        customConstraints()
        super.updateConstraints()
    }
    
    open var dynamicConstraints = [NSLayoutConstraint]()
    
    open func customConstraints() {
        guard !awakeFromNibCalled else { return }
        contentView.removeConstraints(dynamicConstraints)
        dynamicConstraints = []
        
        var views: [String : Any] = ["titleLabel": titleLabel!, "rating": rating!, "valueLabel": valueLabel!]
        let metrics = ["spacing": 15.0]
        valueLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        let title = shouldShowTitle ? "-[titleLabel]" : ""
        let value = !ratingRow.shouldHideValue ? "-[valueLabel]" : ""
        
        if let imageView = imageView, let _ = imageView.image {
            views["imageView"] = imageView
            let hContraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-[imageView]\(title)-(>=0)-[rating]\(value)-|", options: .alignAllCenterY, metrics: metrics, views: views)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            dynamicConstraints.append(contentsOf: hContraints)
        } else {
            let hContraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|\(title)-(>=0)-[rating]\(value)-|", options: .alignAllCenterY, metrics: metrics, views: views)
            dynamicConstraints.append(contentsOf: hContraints)
        }
        let vContraint = NSLayoutConstraint(item: rating!, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1, constant: 0)
        dynamicConstraints.append(vContraint)
        contentView.addConstraints(dynamicConstraints)
    }
}
        
public final class RatingRow: Row<RatingCell>, RowType {
    public var shouldHideValue = false

    required public init(tag: String?) {
        super.init(tag: tag)
    }
}
