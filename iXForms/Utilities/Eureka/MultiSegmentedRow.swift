//
//  MultiSegmentedRow.swift
//  iXForms
//
//  Created by Gareth Bestor on 08/02/21.
//  Copyright © 2021 Xiphware. All rights reserved.
//
// https://github.com/yonat/MultiSelectSegmentedControl

import Eureka

// MARK: MultiSegmentedCell

// open class PushSelectorCell<T: Equatable> : Cell<T>, CellType {

open class MultiSegmentedCell<T: Equatable> : Cell<T>, CellType {
    @IBOutlet public weak var multiSegmentedControl: MultiSelectSegmentedControl!
    @IBOutlet public weak var titleLabel: UILabel?

    private var dynamicConstraints = [NSLayoutConstraint]()
    fileprivate var observingTitleText = false
    private var awakeFromNibCalled = false

    open var optionsProvider: OptionsProvider<T>?
    
    required public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let multiSegmentedControl = MultiSelectSegmentedControl()
        multiSegmentedControl.allowsMultipleSelection = true
        //multiSegmentedControl.allowsMultipleSelection = false // HACK
        multiSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        multiSegmentedControl.setContentHuggingPriority(UILayoutPriority(rawValue: 250), for: .horizontal)
        self.multiSegmentedControl = multiSegmentedControl

        self.titleLabel = self.textLabel
        self.titleLabel?.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel?.setContentHuggingPriority(UILayoutPriority(rawValue: 500), for: .horizontal)
        self.titleLabel?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let me = self else { return }
            guard me.observingTitleText else { return }
            me.titleLabel?.removeObserver(me, forKeyPath: "text")
            me.observingTitleText = false
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let me = self else { return }
            guard !me.observingTitleText else { return }
            me.titleLabel?.addObserver(me, forKeyPath: "text", options: [.new, .old], context: nil)
            me.observingTitleText = true
        }

        NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.titleLabel = self?.textLabel
            self?.setNeedsUpdateConstraints()
        }
        contentView.addSubview(titleLabel!)
        contentView.addSubview(multiSegmentedControl)
        titleLabel?.addObserver(self, forKeyPath: "text", options: [.old, .new], context: nil)
        observingTitleText = true
        imageView?.addObserver(self, forKeyPath: "image", options: [.old, .new], context: nil)

        contentView.addConstraint(NSLayoutConstraint(item: multiSegmentedControl, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1, constant: 0))

    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        awakeFromNibCalled = true
    }

    deinit {
        multiSegmentedControl.removeTarget(self, action: nil, for: .allEvents)
        if !awakeFromNibCalled {
            if observingTitleText {
                titleLabel?.removeObserver(self, forKeyPath: "text")
            }
            imageView?.removeObserver(self, forKeyPath: "image")
            NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIContentSizeCategory.didChangeNotification, object: nil)
        }

    }

    open override func setup() {
        super.setup()
        selectionStyle = .none
        multiSegmentedControl.addTarget(self, action: #selector(MultiSegmentedCell.valueChanged), for: .valueChanged)
    }

    open override func update() {
        super.update()
        detailTextLabel?.text = nil

        updateSegmentedControl()
        multiSegmentedControl.selectedSegmentIndexes = selectedIndexes()
        multiSegmentedControl.isEnabled = !row.isDisabled
    }

    @objc func valueChanged() {
        var values = Set<String>()
        for selectedIndex in multiSegmentedControl.selectedSegmentIndexes {
            guard let value = (row as! MultiSegmentedRow<String>).options?[selectedIndex] else { continue }
            values.insert(value)
        }
        row.value = values as? T
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let obj = object as AnyObject?

        if let changeType = change, let _ = keyPath, ((obj === titleLabel && keyPath == "text") || (obj === imageView && keyPath == "image")) &&
            (changeType[NSKeyValueChangeKey.kindKey] as? NSNumber)?.uintValue == NSKeyValueChange.setting.rawValue, !awakeFromNibCalled {
            setNeedsUpdateConstraints()
            updateConstraintsIfNeeded()
        }
    }

    func updateSegmentedControl() {
        multiSegmentedControl.removeAllSegments()

        (row as! MultiSegmentedRow<String>).options?.reversed().forEach {
            multiSegmentedControl.insertSegment(withTitle: $0, at: 0, animated: false)
            /*
            if let image = $0 as? UIImage {
                multiSegmentedControl.insertSegment(with: image, at: 0, animated: false)
            } else {
                multiSegmentedControl.insertSegment(withTitle: $0, at: 0, animated: false)
            }
 */
        }
    }

    open override func updateConstraints() {
        guard !awakeFromNibCalled else {
            super.updateConstraints()
            return
        }
        contentView.removeConstraints(dynamicConstraints)
        dynamicConstraints = []
        var views: [String: AnyObject] =  ["segmentedControl": multiSegmentedControl]

        var hasImageView = false
        var hasTitleLabel = false

        if let imageView = imageView, let _ = imageView.image {
            views["imageView"] = imageView
            hasImageView = true
        }

        if let titleLabel = titleLabel, let text = titleLabel.text, !text.isEmpty {
            views["titleLabel"] = titleLabel
            hasTitleLabel = true
            dynamicConstraints.append(NSLayoutConstraint(item: titleLabel, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1, constant: 0))
        }

        dynamicConstraints.append(NSLayoutConstraint(item: multiSegmentedControl!, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: contentView, attribute: .width, multiplier: 0.3, constant: 0.0))

        if hasImageView && hasTitleLabel {
            dynamicConstraints += NSLayoutConstraint.constraints(withVisualFormat: "H:[imageView]-(15)-[titleLabel]-[segmentedControl]-|", options: [], metrics: nil, views: views)
        } else if hasImageView && !hasTitleLabel {
            dynamicConstraints += NSLayoutConstraint.constraints(withVisualFormat: "H:[imageView]-[segmentedControl]-|", options: [], metrics: nil, views: views)
        } else if !hasImageView && hasTitleLabel {
            dynamicConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-[titleLabel]-[segmentedControl]-|", options: .alignAllCenterY, metrics: nil, views: views)
        } else {
            dynamicConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-[segmentedControl]-|", options: .alignAllCenterY, metrics: nil, views: views)
        }
        contentView.addConstraints(dynamicConstraints)
        super.updateConstraints()
    }

    func selectedIndexes() -> IndexSet {
        var indexes = IndexSet()
        let options = (row as! MultiSegmentedRow<String>).options
        if let values = row.value as? Set<String> {
            for value in values {
                guard let index = options?.firstIndex(of: value) else { continue }
                indexes.update(with: index)
            }
        }
        return indexes
    }
}

// MARK: MultiSegmentedRow

// See https://github.com/xmartlabs/Eureka/blob/master/Source/Rows/MultipleSelectorRow.swift
// open class GenericMultipleSelectorRow<T, Cell: CellType>: Row<Cell>, PresenterRowType, NoValueDisplayTextConformance, OptionsProviderRow where Cell: BaseCell, Cell.Value == Set<T> {
// open class _MultipleSelectorRow<T, Cell: CellType>: GenericMultipleSelectorRow<T, Cell> where Cell: BaseCell, Cell.Value == Set<T> {
// public final class MultipleSelectorRow<T: Hashable> : _MultipleSelectorRow<T, PushSelectorCell<Set<T>>>, RowType {

// Could not get OptionsRow superclass to work because it cant handle Set<T> Cell type, tries to makes options list same as Cell base type (ie Set<T>), yadda, yadda
// public final class SegmentedRow<T: Equatable>: OptionsRow<SegmentedCell<T>>, RowType { ... }
// public final class MultiSegmentedRow<T: Hashable>: OptionsRow<MultiSegmentedCell<Set<T>>>, RowType { ... }

open class _MultiSegmentedRow<T, Cell: CellType>: GenericMultipleSelectorRow<T, Cell> where Cell: BaseCell, Cell.Value == Set<T> {
    
    open override func customDidSelect() { } // GenericMultipleSelectorRow pushes corresponding SelectorViewController when select cell. Do nothing instead!
    
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class MultiSegmentedRow<T: Hashable> : _MultiSegmentedRow<T, MultiSegmentedCell<Set<T>>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}
