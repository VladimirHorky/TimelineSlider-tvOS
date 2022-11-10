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
private let defaultFocusScaleFactor: CGFloat = 2
private let scrubbingTranslationMultiplier: Float = 0.15

protocol TimelineSliderDelegate: AnyObject {
    func timelineSliderDidTryToScrubBeyondMinimumLimit(_ sender: TimelineSlider)
}

protocol ThumbnailViewDataSource: AnyObject {
    func thumbnail(at value: Float) -> UIImage
}

/// A control used to select a single value from a continuous range of values.
public final class TimelineSlider: UIControl {

    // MARK: - Public

    weak var delegate: TimelineSliderDelegate?
    weak var thumbnailProvider: ThumbnailViewDataSource? {
        didSet {
            updateThumbnailVisibility()
        }
    }

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
            storedThumbValue = min(maximumScrubbingValue, nextValue)

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


    /// A Boolean value indicating whether thumbnail view is enabled
    public var isThumbnailsEnabled: Bool = true {
        didSet {
            guard oldValue != isThumbnailsEnabled else { return }
            thumbnailView.isHidden = isThumbnailsEnabled

            updateThumbnailVisibility()
        }
    }

    /// A Boolean value indicating whether scrubbing is enabled or not.
    public var isScrubbingEnabled: Bool = false {
        didSet {
            guard oldValue != isScrubbingEnabled else { return }
            updateThumbViewVisibility()
            updateThumbnailVisibility()
        }
    }

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

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        updateThumbPosition()
        updateCurrentMarkerPosition()
    }

    public override func didUpdateFocus(
        in context: UIFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator
    ) {
        mode = .normal

        coordinator.addCoordinatedAnimations({
            self.updateStateDependantViews()
        }, completion: { [weak self] in
            guard let self = self else { return }
            if context.nextFocusedView == self {
                self.addParallaxMotionEffects()
            } else {
                self.thumbValue = self.currentProgressValue
                self.motionEffects = []
            }
        })
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 35)
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

    // MARK: - Private

    private typealias ControlState = UInt

    private var storedCurrentValue: Float = defaultValue
    private var storedThumbValue: Float = defaultValue

    /// Indicates the mode of the timeline
    private var mode: Mode = .normal {
        didSet {
            guard oldValue != mode else { return }
            switch mode {
            case .normal:
                self.addParallaxMotionEffects()
            case .scrubbing:
                self.motionEffects = []
            }
        }
    }

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

    private var thumbnailView: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = 5
        view.backgroundColor = .black
        return view
    }()

    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var tapGestureRecognizer: UITapGestureRecognizer!

    private var thumbViewCenterXConstraint: NSLayoutConstraint!
    private var currentProgressMarkerCenterXConstraint: NSLayoutConstraint!

    private weak var deceleratingTimer: Timer?
    private var deceleratingVelocity: Float = 0

    private var thumbViewCenterXConstraintConstant: Float = 0

    private func setUpView() {
        addSubview(trackView)
        trackView.addSubview(maximumTrackView)
        trackView.addSubview(minimumTrackView)
        addSubview(currentProgressMarker)
        addSubview(thumbView)
        addSubview(thumbnailView)

        setUpTrackView()
        setUpMinimumTrackView()
        setUpMaximumTrackView()
        setUpCurrentProgressMarker()
        setUpThumbView()
        setUpThumbnailView()

        setUpGestures()
        updateStateDependantViews()

        updateThumbnailVisibility()
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

    private func setUpThumbnailView() {
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            thumbnailView.widthAnchor.constraint(equalToConstant: 160),
            thumbnailView.heightAnchor.constraint(equalToConstant: 90),
            thumbnailView.centerXAnchor.constraint(equalTo: thumbView.centerXAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: thumbView.topAnchor, constant: -20)
        ])
    }

    private func setUpGestures() {
        panGestureRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(panGestureWasTriggered(panGestureRecognizer:))
        )
        panGestureRecognizer.delegate = self
        addGestureRecognizer(panGestureRecognizer)


        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureTriggered))
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        addGestureRecognizer(tapGestureRecognizer)

    }

    private func updateStateDependantViews() {

        thumbView.image = thumbViewImages[state.rawValue] ?? thumbViewImages[UIControl.State.normal.rawValue]

        if isFocused {
            trackView.transform = CGAffineTransform(scaleX: 1.0, y: focusScaleFactor)
        }
        else {
            trackView.transform = CGAffineTransform.identity
        }

        updateThumbViewVisibility()
        updateThumbnailVisibility()
    }

    private func addParallaxMotionEffects(tiltValue : CGFloat = 0.25, panValue: CGFloat = 5) {
        var yTilt = UIInterpolatingMotionEffect()
        yTilt = UIInterpolatingMotionEffect(keyPath: "layer.transform.rotation.x", type: .tiltAlongVerticalAxis)
        yTilt.minimumRelativeValue = -tiltValue
        yTilt.maximumRelativeValue = tiltValue

        var yPan = UIInterpolatingMotionEffect()
        yPan = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        yPan.minimumRelativeValue = -panValue
        yPan.maximumRelativeValue = panValue

        let motionGroup = UIMotionEffectGroup()
        motionGroup.motionEffects = [yTilt, yPan]
        self.addMotionEffect( motionGroup )
    }

    private func isVerticalGesture(_ recognizer: UIPanGestureRecognizer) -> Bool {
        let translation = recognizer.translation(in: self)
        if abs(translation.y) > abs(translation.x) {
            return true
        }
        return false
    }

    private func updateThumbnailVisibility() {
        if isScrubbingEnabled, isThumbnailsEnabled, isFocused, thumbnailProvider != nil {
            updateThumbnailViewAlpha(to: 1.0, animated: true)
        } else {
            updateThumbnailViewAlpha(to: 0, animated: true)
        }
    }

    private func updateThumbViewVisibility() {
        if isScrubbingEnabled, isFocused {
            updateThumbViewAlpha(to: 1.0, animated: true)
        } else {
            updateThumbViewAlpha(to: 0, animated: true)
        }
    }

    private func updateThumbViewAlpha(to alpha: CGFloat, animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0.0) { [weak self] in
                self?.thumbView.alpha = alpha
            }
        } else {
            thumbView.alpha = alpha
        }
    }

    private func updateThumbnailViewAlpha(to alpha: CGFloat, animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0.0) { [weak self] in
                self?.thumbnailView.alpha = alpha
            }
        } else {
            thumbnailView.alpha = alpha
        }
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
            if mode != .scrubbing {
                sendActions(for: .editingDidBegin)
            }
            mode = .scrubbing
        case .changed:
            let centerX = thumbViewCenterXConstraintConstant + translationX * scrubbingTranslationMultiplier
            let percent = centerX / Float(trackView.frame.width)
            let nextValue = minimumValue + ((maximumValue - minimumValue) * percent)
            thumbValue = nextValue
            if isContinuous {
                sendActions(for: .valueChanged)
            }
            thumbnailView.image = thumbnailProvider?.thumbnail(at: thumbValue)
        case .ended, .cancelled:
            thumbViewCenterXConstraintConstant = Float(thumbViewCenterXConstraint.constant)
        default:
            break
        }
    }

    @objc
    private func tapGestureTriggered(_ sender: UITapGestureRecognizer) {
        setValue(thumbValue, animated: true)
        mode = .normal
        sendActions(for: .editingDidEnd)
    }
}

extension TimelineSlider: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard isScrubbingEnabled else { return false }

        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        if gestureRecognizer === tapGestureRecognizer {
            return mode == .scrubbing
        }

        return true
    }
}

extension TimelineSlider {
    public enum Mode {
        case normal
        case scrubbing
    }
}
