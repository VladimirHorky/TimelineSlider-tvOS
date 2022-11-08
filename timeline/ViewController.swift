//
//  ViewController.swift
//  timeline
//
//  Created by Vladimír Horký on 04.11.2022.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var slider: TimelineSlider!

    private let thumbLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let currentLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        slider.addTarget(self, action: #selector(sliderValueChanges), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderDidBeginEditing), for: .editingDidBegin)
        slider.addTarget(self, action: #selector(sliderDidEndEditing), for: .editingDidEnd)
        slider.minimumScrubbingValue = 0.5
        slider.currentProgressValue = 0.55
        slider.thumbValue = 0.6
        slider.maximumScrubbingValue = 0.9
        slider.delegate = self
        slider.thumbnailProvider = self
    }

    @objc
    func sliderValueChanges(_ slider: TimelineSlider) {
        thumbLabel.text = "\(slider.thumbValue)"
        currentLabel.text = "\(slider.currentProgressValue)"
    }

    @objc
    func sliderDidBeginEditing(_ slider: TimelineSlider) {
        print("begin editing!")
    }

    @objc
    func sliderDidEndEditing(_ slider: TimelineSlider) {
        print("end editing!")
        slider.isScrubbingEnabled = false
    }

    @IBAction func toggleScrubbingMode(_ sender: Any) {
        slider.isScrubbingEnabled.toggle()
        label.text = slider.isScrubbingEnabled ? "scrubbing enabled" : "scrubbing disabled"
    }


    private func setupView() {
        view.addSubview(thumbLabel)
        view.addSubview(currentLabel)

        label.text = slider.isScrubbingEnabled ? "scrubbing enabled" : "scrubbing disabled"

        NSLayoutConstraint.activate([
            thumbLabel.centerXAnchor.constraint(equalTo: slider.thumbView.centerXAnchor),
            thumbLabel.topAnchor.constraint(equalTo: slider.thumbView.bottomAnchor, constant: 20),
            currentLabel.centerXAnchor.constraint(equalTo: slider.currentProgressMarker.centerXAnchor),
            currentLabel.topAnchor.constraint(equalTo: slider.currentProgressMarker.bottomAnchor, constant: 20)
        ])
    }
}

extension ViewController: TimelineSliderDelegate {
    func timelineSliderDidTryToScrubBeyondMinimumLimit(_ sender: TimelineSlider) {
        print("trying to scrub beyond minimum!")
    }
}

extension ViewController: ThumbnailViewDataSource {
    func thumbnail(at value: Float) -> UIImage {
        UIColor.random().image()
    }
}

extension UIColor {
    func image(_ size: CGSize = CGSize(width: 160, height: 90)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}

extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension UIColor {
    static func random() -> UIColor {
        return UIColor(
           red:   .random(),
           green: .random(),
           blue:  .random(),
           alpha: 1.0
        )
    }
}
