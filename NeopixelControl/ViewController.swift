//
//  ViewController.swift
//  NeopixelControl
//
//  Created by Carl Peto on 17/04/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

import UIKit
import Combine

class ViewController: UIViewController {
    @IBOutlet weak var hueSlider: UISlider!
    @IBOutlet weak var hueColour: UIView!
    @IBOutlet weak var valueSlider: UISlider!
    @IBOutlet weak var bluetoothStateLabel: UILabel!
    @IBOutlet weak var sendButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        hueSlider.transform = CGAffineTransform(rotationAngle: .pi / 2)
        updateViewColour()
        Bluetooth.shared.start()

        let bluetoothStatus = NotificationCenter.Publisher(
            center: .default,
            name: Bluetooth.bluetoothStateChange,
            object: nil)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[Bluetooth.bluetoothStateKey] as? Bluetooth.State }

        let bluetoothStatusName = bluetoothStatus.map { $0?.rawValue }
        let bluetoothStateLabelSubscriber = Subscribers.Assign(object: bluetoothStateLabel, keyPath: \.text)
        bluetoothStatusName.subscribe(bluetoothStateLabelSubscriber)

        let bluetoothTransmitEnable = bluetoothStatus.map { $0 == .gotCharacteristics }
        let sendButtonEnabledSubscriber = Subscribers.Assign(object: sendButton, keyPath: \.isEnabled)
        bluetoothTransmitEnable.subscribe(sendButtonEnabledSubscriber)
    }

    private func updateViewColour() {
        let c = UIColor(hue: CGFloat(currentHue) / 255.0, saturation: 1.0, brightness: CGFloat(currentValue) / 100.0, alpha: 1.0)
        hueColour.backgroundColor = c
    }

    @IBAction func hueSliderChanged(_ sender: UISlider) {
        currentHue = CGFloat(sender.value)
    }

    @IBAction func valueSliderChanged(_ sender: UISlider) {
        currentValue = CGFloat(sender.value)
    }

    @IBAction func sendValues(_ sender: UIButton) {
        Bluetooth.shared.send(data: getColourData())
    }

    private func getColourData() -> Data {
        let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 4)
        buffer[0] = Character("H").asciiValue!
        buffer[1] = UInt8(truncatingIfNeeded: Int(currentHue))
        buffer[2] = Character("V").asciiValue!
        buffer[3] = UInt8(truncatingIfNeeded: Int(currentValue))
        return Data(buffer: buffer)
    }

    var currentHue: CGFloat = 10 {
        didSet {
            updateViewColour()
        }
    }

    var currentValue: CGFloat = 100 {
        didSet {
            updateViewColour()
        }
    }
}
