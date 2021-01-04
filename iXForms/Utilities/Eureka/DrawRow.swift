//
//  DrawRow.swift
//  iXForms
//
//  Created by Gareth Bestor on 29/09/20.
//  Copyright © 2020 Xiphware. All rights reserved.
//

import Eureka
import Foundation
import UIKit
import os
import SwiftyDraw

open class DrawViewController: UIViewController, TypedRowControllerType  {
    public var row: RowOf<UIImage>!
    public var onDismissCallback: ((UIViewController) -> ())?
    
    let drawView = SwiftyDrawView()
    let colors: [UIColor] = [.black, .red, .yellow, .blue, .orange, .green, .purple, .white]
    var color = UIColor() // current selected pen color
    let colorPicker = UIViewController()
    var swatchBottomConstraint: NSLayoutConstraint? // must set this dynamically because UIToolBar height varies
    
    // Toolbar buttons. Some icons are dynamic and and target (self) must be set after init
    let pencilButton = UIBarButtonItem(image: nil, style: .plain, target: nil, action: #selector(selectTool(_:)))
    let markerButton = UIBarButtonItem(image: nil, style: .plain, target: nil, action: #selector(selectTool(_:)))
    let eraseButton = UIBarButtonItem(image: nil, style: .plain, target: nil, action: #selector(selectTool(_:)))
    let colorButton = UIBarButtonItem(image: UIImage(named: "icons8-filled-circle-33")?.withRenderingMode(.alwaysTemplate), style: .plain, target: nil, action: #selector(showColors(_:)))
    let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: #selector(clear))

    open override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.title = "Drawing"
        
        /*
        // Annotation: add image background
        if let image = row.value {
            let background = UIImageView(image: image)
            background.frame = self.view.frame
            background.contentMode = .scaleAspectFit
            background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.addSubview(background)
        }
        */
        
        // Drawing view
        drawView.frame = self.view.bounds
        self.view.addSubview(drawView)
        drawView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Navigation bar
        let doneButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        navigationItem.rightBarButtonItems = [doneButton]

        // Toolbar
        pencilButton.target = self
        markerButton.target = self
        colorButton.target = self
        eraseButton.target = self
        deleteButton.target = self
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        self.toolbarItems = [pencilButton, space, markerButton, space, colorButton, space, eraseButton, space, deleteButton]
        
        // Color picker
        colorPicker.modalPresentationStyle = .overCurrentContext
        colorPicker.modalTransitionStyle = .coverVertical
        colorPicker.view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        let swatch = UIStackView()
        swatch.axis = .vertical
        swatch.distribution = .equalSpacing
        swatch.spacing = 5
        for uiColor in colors {
            let button = UIButton(type: .custom)
            button.setImage(UIImage(named: "icons8-filled-circle-33")?.withRenderingMode(.alwaysTemplate), for: .normal)
            button.addTarget(self, action: #selector(setColor(_:)), for: .touchUpInside)
            button.tintColor = uiColor
            swatch.addArrangedSubview(button)
        }
        colorPicker.view.addSubview(swatch)
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.centerXAnchor.constraint(equalTo: colorPicker.view.centerXAnchor).isActive = true
        swatchBottomConstraint = swatch.bottomAnchor.constraint(equalTo: colorPicker.view.bottomAnchor, constant: 0) // will set distance when present colorPicker!
        swatchBottomConstraint!.isActive = true
        // TODO shrink height/reduce spacing so top of swatch remains visible on phone when in landscape
        
        color = drawView.brush.color.uiColor
        colorButton.tintColor = color
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isToolbarHidden = false
        selectTool(pencilButton) // start with pencil
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.isToolbarHidden = true
    }
    
    // MARK: Drawing tools
    
    // Select drawing tool
    @objc func selectTool(_ sender: UIBarButtonItem) {
        for button in [pencilButton, markerButton, eraseButton] {
            if button == sender {
                // change brush and highlighted icon
                switch button {
                case pencilButton:
                    button.image = UIImage(named: "icons8-pencil-drawing-filled-24")
                    drawView.brush.width = 3
                    drawView.brush.color = Color(color.withAlphaComponent(1.0))
                    drawView.brush.blendMode = .normal // undo eraser
                    
                case markerButton:
                    button.image = UIImage(named: "icons8-chisel-tip-marker-filled-24")
                    drawView.brush.width = 10
                    drawView.brush.color = Color(color.withAlphaComponent(0.3))
                    drawView.brush.blendMode = .normal // undo eraser
                    
                case eraseButton:
                    button.image = UIImage(named: "icons8-pencil-eraser-filled-24")
                    drawView.brush = .eraser
                    drawView.brush.width = 10
                    
                default: break
                }
            } else {
                // unhighlighted icon
                switch button {
                case pencilButton: button.image = UIImage(named: "icons8-pencil-drawing-24")
                case markerButton: button.image = UIImage(named: "icons8-chisel-tip-marker-24")
                case eraseButton: button.image = UIImage(named: "icons8-pencil-eraser-24")
                default: break
                }
            }
        }
        colorButton.isEnabled = (sender != eraseButton) // disable selecting colors when erasing
    }
    
    @objc func showColors(_ sender: UIBarButtonItem) {
        swatchBottomConstraint?.constant = -(self.navigationController!.toolbar.frame.size.height) - 5.0 // position swatch above toolbar
        // TODO re-adjust if change orientation when presenting color picker because UITabBar height changes!
        self.navigationController?.present(colorPicker, animated: true, completion: nil)
    }
    
    @objc func setColor(_ sender: UIButton) {
        color = sender.tintColor // get new color from sender button's tintColor
        drawView.brush.color = Color(color.withAlphaComponent(drawView.brush.color.uiColor.alpha)) // re-apply previous pen vs marker alpha
        colorButton.tintColor = color // show new color on toolbar
        colorPicker.dismiss(animated: true, completion: nil)
    }
    
    @objc func clear() {
        drawView.clear()
        selectTool(pencilButton) // reset to pencil
    }
    
    @objc func save() {
        // https://github.com/Awalz/SwiftyDraw/issues/18
        UIGraphicsBeginImageContextWithOptions(drawView.bounds.size, false, 0)
        drawView.drawHierarchy(in: drawView.bounds, afterScreenUpdates: true)
        row.value = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        onDismissCallback?(self)
    }
}

// https://github.com/xmartlabs/eureka#custom-presenter-rows
open class GenericImageRow<Cell: CellType>: OptionsRow<Cell>, PresenterRowType, ImageRowProtocol where Cell: BaseCell, Cell.Value == UIImage {
    public typealias PresenterRow = DrawViewController
    
    open var presentationMode: PresentationMode<PresenterRow>?
    open var onPresentCallback: ((FormViewController, PresenterRow) -> Void)?
    open var placeholderImage: UIImage?
    open var thumbnailImage: UIImage?
    
    public required init(tag: String?) {
        super.init(tag: tag)
        
        presentationMode = .show(controllerProvider: ControllerProvider.callback(builder: { () -> DrawViewController in
            return DrawViewController()
            }),
            onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            })
        
        self.displayValueFor = nil
    }
    
    public override func customDidSelect() {
        super.customDidSelect()
        
        guard let presentationMode = presentationMode, !isDisabled else { return }
        if let controller = presentationMode.makeController() {
            controller.row = self
            controller.title = selectorTitle ?? controller.title
            onPresentCallback?(cell.formViewController()!, controller)
            presentationMode.present(controller, row: self, presentingController: self.cell.formViewController()!)
        } else {
            presentationMode.present(nil, row: self, presentingController: self.cell.formViewController()!)
        }
    }
    
    open override func prepare(for segue: UIStoryboardSegue) {
        super.prepare(for: segue)
        guard let rowVC = segue.destination as? PresenterRow else { return }
        rowVC.title = selectorTitle ?? rowVC.title
        rowVC.onDismissCallback = presentationMode?.onDismissCallback ?? rowVC.onDismissCallback
        onPresentCallback?(cell.formViewController()!, rowVC)
        rowVC.row = self
    }
}

public class ImageCell: PushSelectorCell<UIImage> {
    public override func setup() {
        super.setup()
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        imageView.contentMode = .scaleAspectFit
        accessoryView = imageView
        editingAccessoryView = accessoryView
    }
    
    public override func update() {
        super.update()
        selectionStyle = row.isDisabled ? .none : .default
        (accessoryView as? UIImageView)?.image = row.value ?? (row as? ImageRowProtocol)?.thumbnailImage ?? (row as? ImageRowProtocol)?.placeholderImage
    }
}

//public final class DrawRow: _DrawRow<SignatureCell>, RowType {
public final class DrawRow: GenericImageRow<ImageCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}
