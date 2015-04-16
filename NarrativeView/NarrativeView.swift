//
//  NarrativeView.swift
//  FlowField
//
//  Created by Robert Manson on 2/16/15.
//  Copyright (c) 2015 Benny. All rights reserved.
//

import UIKit

public protocol NarrativeViewDelegate {
    /**
    Called after all fields were validated.
    
    :param: wereValid is true if all fields were valid
    */
    func narrativeViewDidValidate(allWereValid: Bool)
    /**
    Done button was pressed on keyboard indicating that we might want to proceed to the next onboarding step.
    
    :param: wereValid is true if all fields were valid
    
    :returns: Should dismiss keyboard
    */
    func narrativeViewDoneButtonPressed(allWereValid: Bool) -> Bool
}

public class NarrativeView: UIScrollView, UITextFieldDelegate {
    /**
    Sets background colors of contained views to alternating colors for easier layout debugging.
    */
    private let debugViewLayout = false
    private var flowItems: [UIView] = []
    private let layoutHelper: NarrativeLayout
    private let layoutFrame: CGRect

    /**
    *  Comprised of layout items.
    */
    private struct Layout {
        private(set) var items: [NarrativeItem] = []
        mutating func append(item: NarrativeItem) {
            self.items.append(item)
        }
        mutating func append(items: [NarrativeItem]) {
            self.items += items
        }
        func layoutItem(#forView: UIView) -> NarrativeItem? {
            for item in items {
                switch item {
                case let .Field(textfield, _):
                    if textfield == forView {
                        return item
                    }
                case let .Button(button, _):
                    if button == forView {
                        return item
                    }
                default:
                    continue
                }
            }
            return nil
        }
        func nextLayoutItem(#forView: UIView) -> NarrativeItem? {
            var foundItem = false
            for item in items {
                switch item {
                case let .Field(textfield, _):
                    if !foundItem {
                        if textfield == forView {
                            foundItem = true
                        }
                    } else {
                        return item
                    }
                default:
                    continue
                }
            }
            return nil
        }
    }
    private var layout: Layout = Layout()
    public init(frame: CGRect, rowHeight: CGFloat) {
        let edgeInsets = UIEdgeInsets(top: 48, left: 13, bottom: 64, right: 13)
        layoutFrame = UIEdgeInsetsInsetRect(frame, edgeInsets)
        layoutHelper = NarrativeLayout(origin: layoutFrame.origin, rowWidth: layoutFrame.width, rowHeight: rowHeight)
        super.init(frame: frame)
        scrollEnabled = true
        bounces = true
        alwaysBounceVertical = true
        keyboardDismissMode = UIScrollViewKeyboardDismissMode.OnDrag
    }
    required public init(coder decoder: NSCoder) {
        assert(false, "Init coder not implemented")
        layoutFrame = CGRectZero
        layoutHelper = NarrativeLayout(origin: layoutFrame.origin, rowWidth: layoutFrame.width, rowHeight: 0)
        super.init(coder: decoder)
    }
    override public var isAccessibilityElement: Bool {
        get {
            return false
        }
        set {
            assert(false, "You should not attempt to set this property on FlowFormView")
        }
    }
    override public func layoutSubviews() {
        layoutHelper.layout(layout.items) ?? []
    }
    /// Delegate for the flow form
    public var narrativeViewDelegate: NarrativeViewDelegate?
    /**
    Add a dynamically resizing text field to the layout.
    
    :param: createTextField  closure to create the text field
    :param: valueChanged Closure called when value changes, should return or not the field is consider valid
    
    :returns: The class instance
    */
    public func textField(#createTextField: () -> UITextField, valueChanged: UITextField -> Bool) -> Self {
        let textField = createTextField()
        layout.append(NarrativeItem.Field(textField: textField, valueChangedClosure: valueChanged))
        return self
    }
    /**
    Add static label text to the layout.
    
    :param: createLabel closure to create a UILabel
    :param: text The label text
    
    :returns: The class instance
    */
    public func label(#createLabel: Void -> UILabel, text: String) -> Self {
        let words = split(text) { $0 == " " }
        let labels: [UILabel] = words.map { word in
            let label = createLabel()
            label.text = word
            label.sizeToFit()
            return label
        }
        layout.append(labels.map { label in NarrativeItem.Label(label) })
        return self
    }
    /**
    Add a button to the layout.
    
    :param: makeButton closure to make a button
    
    :returns: The class instance
    */
    public func button(makeButton: () -> UIButton, buttonPressed: () -> Void) -> Self {
        let button = makeButton()
        layout.append(NarrativeItem.Button(button, buttonPressedClosure: buttonPressed))
        return self
    }
    /**
    Initialize the flow layout, adding all subviews to this scrollview.
    
    :returns: The class instance
    */
    public func initialLayout() {
        accessibilityElements = []
        for subView in subviews {
            subView.removeFromSuperview()
        }
        flowItems = layoutHelper.layout(layout.items) ?? []
        accessibilityElements = accessibilityItems(containerView: self)
        for item in flowItems {
            addSubview(item)
            if let textField = item as? UITextField {
                textField.addTarget(self, action: "textFieldEditingChanged:", forControlEvents: UIControlEvents.EditingChanged)
                textField.delegate = self
            } else if let button = item as? UIButton {
                button.addTarget(self, action: "onFlowButtonPressed:", forControlEvents: UIControlEvents.TouchUpInside)
            }
        }
        if debugViewLayout {
            backgroundColor = UIColor.whiteColor()
            var backgroundColorAlternator = 1
            for item in flowItems {
                if let textField = item as? UITextField {
                    textField.backgroundColor = UIColor.greenColor()
                } else if let textLabel = item as? UILabel {
                    textLabel.backgroundColor = backgroundColorAlternator++ % 2 == 0 ? UIColor.yellowColor() : UIColor.lightGrayColor()
                }
            }
        } else {
            backgroundColor = UIColor.clearColor()
        }
        contentSize = CGSize(width: bounds.width, height: bounds.height + 10)
    }
    //MARK: - Accessibility
    private class AccessibleLabelSpan {
        let containerView: UIView
        var spanningFrame: CGRect
        var spanningLabelText: String
        var accessibilityElement: UIAccessibilityElement {
            let element = UIAccessibilityElement(accessibilityContainer: containerView)
            element.accessibilityFrame = spanningFrame
            element.accessibilityLabel = spanningLabelText
            return element
        }
        init(containerView: UIView, frame: CGRect, text: String?) {
            self.containerView = containerView
            spanningLabelText = text ?? ""
            spanningFrame = frame
        }
        func extend(#frame: CGRect, text: String?) -> Bool {
            if spanningFrame.origin.y == frame.origin.y {
                self.spanningFrame = CGRect(origin: spanningFrame.origin, size: CGSize(width: spanningFrame.width + frame.width, height: spanningFrame.height))
                if let text = text {
                    spanningLabelText += " " + text
                }
                return true
            } else {
                return false
            }
        }
    }
    /**
    Create an array of accesibilty items for a given container view.
    
    :param: containerView The view containing the flow layout
    
    :returns: An array of accesibility items
    */
    private func accessibilityItems(#containerView: UIView) -> [AnyObject] {
        var accesibleItems: [AnyObject] = []
        var accessibleLabelSpan: AccessibleLabelSpan?
        let appendItem: AccessibleLabelSpan -> Void = { item in
            accesibleItems.append(item.accessibilityElement)
            accessibleLabelSpan = nil
        }
        for item in layout.items {
            switch item {
            case let .Field(textField, _):
                accessibleLabelSpan.map(appendItem)
                accesibleItems.append(textField)
            case let .Button(button, _):
                accessibleLabelSpan.map(appendItem)
                accesibleItems.append(button)
            case .Label(let label):
                if let labelSpan = accessibleLabelSpan {
                    if !labelSpan.extend(frame: label.frame, text: label.text) {
                        // New row
                        accessibleLabelSpan.map(appendItem)
                        accessibleLabelSpan = AccessibleLabelSpan(containerView: containerView, frame: label.frame, text: label.text)
                    }
                } else {
                    accessibleLabelSpan = AccessibleLabelSpan(containerView: containerView, frame: label.frame, text: label.text)
                }
            }
        }
        accessibleLabelSpan.map(appendItem)
        return accesibleItems
    }
    //MARK: - UIAccessibilityContainer
    override public func accessibilityElementCount() -> Int {
        let count = accessibilityElements != nil ? accessibilityElements.count : 0;
        return count
    }
    override public func accessibilityElementAtIndex(index: Int) -> AnyObject! {
        return accessibilityElements[index]
    }
    //MARK: - Text field events
    func textFieldEditingChanged(textField: UITextField) {
        if !UIAccessibilityIsVoiceOverRunning() {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    //MARK: - UITextFieldDelegate
    public func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        if let nextItem = layout.nextLayoutItem(forView: textField) {
            textField.returnKeyType = UIReturnKeyType.Next
        } else {
            textField.returnKeyType = UIReturnKeyType.Done
        }
        return true
    }
    private func validateAllFields() -> Int {
        var invalidItemCount = 0
         for item in layout.items {
            switch item {
            case let .Field(textField, validate):
                let isValid = validate(textField)
                let settableTF = textField as? NarrativeTextFieldSettableAppearance
                if isValid {
                    settableTF?.appearance = .Valid
                } else {
                    if textField.text != "" {
                        settableTF?.appearance = .Invalid
                    } else {
                        settableTF?.appearance = .Ready
                    }
                    invalidItemCount++
                }
            default:
                continue
            }
        }
        return invalidItemCount
    }
    public func textFieldDidEndEditing(textField: UITextField) {
        narrativeViewDelegate?.narrativeViewDidValidate(validateAllFields() == 0 ? true : false)
    }
    // Set state of currently editing layoutItem after the user has hit return
    // If the current field we are editing is valid:
    // Select the next field in the flow or signal the form view delegate that we might be done
    // If current field is invalid, lower the keyboard
    public func textFieldShouldReturn(textField: UITextField) -> Bool {
        if let item = layout.layoutItem(forView: textField) {
            switch item {
            case let .Field(textField, validate):
                let isValid = validate(textField)
                let settableTF = textField as? NarrativeTextFieldSettableAppearance
                if isValid {
                    settableTF?.appearance = .Valid
                    if let nextItem = layout.nextLayoutItem(forView: textField) {
                        switch nextItem {
                        case let .Field(nextTextField, _) :
                            nextTextField.becomeFirstResponder()
                        default:
                            // Should not happen
                            break
                        }
                    } else {
                        let willResign = validateAllFields() == 0 ? true : false
                        if narrativeViewDelegate?.narrativeViewDoneButtonPressed(willResign) ?? false {
                            textField.resignFirstResponder()
                        }
                    }
                } else {
                    settableTF?.appearance = .Invalid
                    textField.resignFirstResponder()
                }
            default:
                break
            }
        }
        return false
    }
    //MARK: - Actions
    func onFlowButtonPressed(sender: UIButton) {
        if let item = layout.layoutItem(forView: sender) {
            switch item {
            case let .Button(button, onPressed):
                onPressed()
            default:
                break
            }
        }
    }
}