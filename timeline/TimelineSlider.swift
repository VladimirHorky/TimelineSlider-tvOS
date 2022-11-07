//
//  Copyright (c) 2022 Fubo. All rights reserved.
//

import UIKit

private let trackViewHeight: CGFloat = 5
private let thumbSize: CGFloat = 30
private let currentProgressMarkerSize: CGFloat = 30
private let animationDuration: TimeInterval = 0.3
private let defaultValue: Float = 0
private let defaultMinimumValue: Float = 0
private let defaultMaximumValue: Float = 1
private let defaultIsContinuous: Bool = true
private let defaultThumbTintColor: UIColor = .white
private let defaultTrackColor: UIColor = .gray
private let defaultMinimumTrackTintColor: UIColor = .blue
private let defaultMaximumTrackTintColor: UIColor = .clear
private let defaultFocusScaleFactor: CGFloat = 1.05
private let scrubbingTranslationMultiplier: Float = 0.15

protocol TimelineSliderDelegate: AnyObject {
    func timelineSliderDidTryToScrubBeyondMinimumLimit(_ sender: TimelineSlider)
}

/// A control used to select a single value from a continuous range of values.
public final class TimelineSlider: UIControl {

    // MARK: - Public

    weak var delegate: TimelineSliderDelegate?

    /// The slider’s current value.
    public var currentProgressValue: Float {
        get {
            return storedCurrentValue
        }
        set {
            storedCurrentValue = min(maximumValue, newValue)
            storedCurrentValue = max(minimumValue, storedCurrentValue)
            updateCurrentMarkerPosition()
        }
    }

    /// Value of thumbView
    public var thumbValue: Float {
        get {
            return storedThumbValue
        }
        set {
            if thumbValue == minimumScrubbingValue, newValue < minimumScrubbingValue {
                delegate?.timelineSliderDidTryToScrubBeyondMinimumLimit(self)
            }
            let nextValue = max(newValue, minimumScrubbingValue)
            storedThumbValue = min(maximumValue, nextValue)
            storedThumbValue = max(minimumValue, storedThumbValue)

            updateThumbPosition()
        }
    }

    /// The minimum value of the slider.
    public var minimumValue: Float = defaultMinimumValue {
        didSet {
            currentProgressValue = max(currentProgressValue, minimumValue)
        }
    }

    /// The maximum value of the slider.
    public var maximumValue: Float = defaultMaximumValue {
        didSet {
            currentProgressValue = min(currentProgressValue, maximumValue)
        }
    }

    /// A Boolean value indicating whether changes in the slider’s value generate continuous update events.
    public var isContinuous: Bool = defaultIsContinuous

    /// The color used to tint the default minimum track images.
    public var minimumTrackTintColor: UIColor? = defaultMinimumTrackTintColor {
        didSet {
            minimumTrackView.backgroundColor = minimumTrackTintColor
        }
    }

    /// The color used to tint the default maximum track images.
    public var maximumTrackTintColor: UIColor? {
        didSet {
            maximumTrackView.backgroundColor = maximumTrackTintColor
        }
    }

    /// The color used to tint the default thumb images.
    public var thumbTintColor: UIColor = defaultThumbTintColor {
        didSet {
            thumbView.backgroundColor = thumbTintColor
        }
    }

    /// Scale factor applied to the slider when receiving the focus
    public var focusScaleFactor: CGFloat = defaultFocusScaleFactor {
        didSet {
            updateStateDependantViews()
        }
    }

    /// Minimum value where user can scrub
    public var minimumScrubbingValue: Float = defaultMinimumValue

    /// Maximum value where user can scrub
    public var maximumScrubbingValue: Float = defaultMaximumValue


    /**
     Sets the slider’s current value, allowing you to animate the change visually.

     - Parameters:
        - value: The new value to assign to the value property
        - animated: Specify true to animate the change in value; otherwise, specify false to update the slider’s appearance immediately.
                Animations are performed asynchronously and do not block the calling thread.
     */
    public func setValue(_ value: Float, animated: Bool) {
        self.currentProgressValue = value
        if animated {
            UIView.animate(withDuration: animationDuration) {
                self.setNeedsLayout()
                self.layoutIfNeeded()
            }
        }
    }

    /**
     Assigns a thumb image to the specified control states.

     - Parameters:
        - image: The thumb image to associate with the specified states.
        - state: The control state with which to associate the image.
     */
    public func setThumbImage(_ image: UIImage?, for state: UIControl.State) {
        thumbViewImages[state.rawValue] = image
        updateStateDependantViews()
    }

    /// The thumb image currently being used to render the slider.
    public var currentThumbImage: UIImage? {
        return thumbView.image
    }

    public private(set) var thumbView: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = thumbSize/2
        view.backgroundColor = defaultThumbTintColor
        return view
    }()

    public private(set) var currentProgressMarker: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = thumbSize/2
        view.backgroundColor = .orange
        return view
    }()

    // MARK: - Initializers

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUpView()
    }


    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUpView()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        print("layout subviews")
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        updateThumbPosition()
        updateCurrentMarkerPosition()
    }

    // MARK: - UIControlStates

    public override var isEnabled: Bool {
        didSet {
            panGestureRecognizer.isEnabled = isEnabled
            updateStateDependantViews()
        }
    }

    public override var isSelected: Bool {
        didSet {
            updateStateDependantViews()
        }
    }

    public override var isHighlighted: Bool {
        didSet {
            updateStateDependantViews()
        }
    }

    public override func didUpdateFocus(
        in context: UIFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator
    ) {
        coordinator.addCoordinatedAnimations({
            self.updateStateDependantViews()
        }, completion: nil)
    }

    // MARK: - Private

    private typealias ControlState = UInt

    private var storedCurrentValue: Float = defaultValue
    private var storedThumbValue: Float = defaultValue

    private var thumbViewImages: [ControlState: UIImage] = [:]

    private var trackView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = trackViewHeight/2
        view.backgroundColor = defaultTrackColor
        return view
    }()

    private var minimumTrackView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = trackViewHeight/2
        view.backgroundColor = defaultMinimumTrackTintColor
        return view
    }()

    private var maximumTrackView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = trackViewHeight/2
        view.backgroundColor = defaultMaximumTrackTintColor
        return view
    }()

    private var panGestureRecognizer: UIPanGestureRecognizer!

    private var thumbViewCenterXConstraint: NSLayoutConstraint!
    private var currentProgressMarkerCenterXConstraint: NSLayoutConstraint!

    private weak var deceleratingTimer: Timer?
    private var deceleratingVelocity: Float = 0

    private var thumbViewCenterXConstraintConstant: Float = 0

    private func setUpView() {
        addSubview(trackView)
        addSubview(maximumTrackView)
        addSubview(minimumTrackView)
        addSubview(currentProgressMarker)
        addSubview(thumbView)

        setUpTrackView()
        setUpMinimumTrackView()
        setUpMaximumTrackView()
        setUpCurrentProgressMarker()
        setUpThumbView()

        setUpGestures()
        updateStateDependantViews()
    }

    private func setUpThumbView() {
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        thumbViewCenterXConstraint = thumbView.centerXAnchor.constraint(
            equalTo: trackView.leadingAnchor,
            constant: CGFloat(thumbValue)
        )
        NSLayoutConstraint.activate([
            thumbView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: thumbSize),
            thumbView.heightAnchor.constraint(equalToConstant: thumbSize),
            thumbViewCenterXConstraint
        ])
    }

    private func updateThumbPosition() {
        let position = CGFloat((storedThumbValue - minimumValue) / (maximumValue - minimumValue))
        var offset = trackView.bounds.width * position
        offset = min(trackView.bounds.width, offset)
        thumbViewCenterXConstraint.constant = offset
    }

    private func updateCurrentMarkerPosition() {
        let position = CGFloat((storedCurrentValue - minimumValue) / (maximumValue - minimumValue))
        var offset = trackView.bounds.width * position
        offset = min(trackView.bounds.width, offset)
        currentProgressMarkerCenterXConstraint.constant = offset
    }

    private func setUpCurrentProgressMarker() {
        currentProgressMarker.translatesAutoresizingMaskIntoConstraints = false
        currentProgressMarkerCenterXConstraint = currentProgressMarker.centerXAnchor.constraint(
            equalTo: trackView.leadingAnchor,
            constant: CGFloat(currentProgressValue)
        )
        NSLayoutConstraint.activate([
            currentProgressMarker.centerYAnchor.constraint(equalTo: centerYAnchor),
            currentProgressMarker.widthAnchor.constraint(equalToConstant: currentProgressMarkerSize),
            currentProgressMarker.heightAnchor.constraint(equalToConstant: currentProgressMarkerSize),
            currentProgressMarkerCenterXConstraint
        ])
    }

    private func setUpTrackView() {
        trackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.heightAnchor.constraint(equalToConstant: trackViewHeight)
        ])
    }

    private func setUpMinimumTrackView() {
        minimumTrackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            minimumTrackView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            minimumTrackView.trailingAnchor.constraint(equalTo: currentProgressMarker.centerXAnchor),
            minimumTrackView.centerYAnchor.constraint(equalTo:trackView.centerYAnchor),
            minimumTrackView.heightAnchor.constraint(equalToConstant: trackViewHeight)
        ])
    }

    private func setUpMaximumTrackView() {
        maximumTrackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            maximumTrackView.leadingAnchor.constraint(equalTo: thumbView.centerXAnchor),
            maximumTrackView.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),
            maximumTrackView.centerYAnchor.constraint(equalTo:trackView.centerYAnchor),
            maximumTrackView.heightAnchor.constraint(equalToConstant: trackViewHeight)
        ])
    }

    private func setUpGestures() {
        panGestureRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(panGestureWasTriggered(panGestureRecognizer:))
        )
        addGestureRecognizer(panGestureRecognizer)
    }

    private func updateStateDependantViews() {

        thumbView.image = thumbViewImages[state.rawValue] ?? thumbViewImages[UIControl.State.normal.rawValue]

        if isFocused {
            transform = CGAffineTransform(scaleX: focusScaleFactor, y: focusScaleFactor)
        }
        else {
            transform = CGAffineTransform.identity
        }
    }

    private func isVerticalGesture(_ recognizer: UIPanGestureRecognizer) -> Bool {
        let translation = recognizer.translation(in: self)
        if abs(translation.y) > abs(translation.x) {
            return true
        }
        return false
    }

    // MARK: - Actions
    @objc
    private func panGestureWasTriggered(panGestureRecognizer: UIPanGestureRecognizer) {
        if self.isVerticalGesture(panGestureRecognizer) {
            return
        }

        let translationX = Float(panGestureRecognizer.translation(in: self).x)

        switch panGestureRecognizer.state {
        case .began:
            thumbViewCenterXConstraintConstant = Float(thumbViewCenterXConstraint.constant)
        case .changed:
            let centerX = thumbViewCenterXConstraintConstant + translationX * scrubbingTranslationMultiplier
            let percent = centerX / Float(trackView.frame.width)
            let nextValue = minimumValue + ((maximumValue - minimumValue) * percent)
            thumbValue = nextValue
            if isContinuous {
                sendActions(for: .valueChanged)
            }
        case .ended, .cancelled:
            thumbViewCenterXConstraintConstant = Float(thumbViewCenterXConstraint.constant)
        default:
            break
        }
    }
}
