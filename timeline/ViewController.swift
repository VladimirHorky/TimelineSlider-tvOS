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
        slider.minimumScrubbingValue = 0.5
        slider.currentProgressValue = 0.55
        slider.thumbValue = 0.55
        slider.delegate = self
    }

    @objc
    func sliderValueChanges(slider: TimelineSlider) {
        label.text = "\(slider.currentProgressValue)"
        thumbLabel.text = "\(slider.thumbValue)"
        currentLabel.text = "\(slider.currentProgressValue)"
    }

    private func setupView() {
        view.addSubview(thumbLabel)
        view.addSubview(currentLabel)

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
