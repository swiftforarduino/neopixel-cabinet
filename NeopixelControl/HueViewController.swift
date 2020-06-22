//
//  HueViewController.swift
//  NeopixelControl
//
//  Created by Carl Peto on 17/04/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

import UIKit
import Combine

//private func interpret

private func getColourData(hue: CGFloat, value: CGFloat) -> Data {
    let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 4)
    buffer[0] = Character("H").asciiValue!
    buffer[1] = UInt8(truncatingIfNeeded: Int(hue))
    buffer[2] = Character("V").asciiValue!
    buffer[3] = UInt8(truncatingIfNeeded: Int(value))
    return Data(buffer: buffer)
}

private func interpretColourData(data: Data) -> (hue: CGFloat, value: CGFloat)? {
    if data.count >= 4 {
        return data.withUnsafeBytes { (buffer: UnsafePointer<UInt8>) -> (CGFloat, CGFloat) in
            var hue: CGFloat = 0
            var value: CGFloat = 0

            if buffer[0] == Character("H").asciiValue {
                hue = CGFloat(Int(buffer[1]))
            }

            if buffer[2] == Character("V").asciiValue {
                value = CGFloat(Int(buffer[3]))
            }

            return (hue, value)
        }
    } else {
        return nil
    }
}

// for some reason, the app sometimes gets stuck saying "connecting"
// which corresponds to the scanning state
// next time this happens, see if killing the app and restarting it fixes it
// if so it's an ios app problem and not the s4a program hanging or similar

extension Bluetooth.State: CustomStringConvertible {
    var description: String {
        switch self {
        case .undefined:
            return "---"
        case .disabled:
            return "DISABLED"
        case .disconnected:
            return "not connected"
        case .scanning:
            return "connecting"
        case .connecting:
            return "connecting."
        case .connected:
            return "connecting.."
        case .discoveredServices:
            return "connecting..."
        case .gotCharacteristics:
            return "connecting...."
        case .notifying:
            return "connected"
        }
    }
}

class HueViewController: UIViewController {
    @IBOutlet weak var hueSlider: UISlider!
    @IBOutlet weak var hueColour: UIView!
    @IBOutlet weak var valueSlider: UISlider!
    @IBOutlet weak var bluetoothStateLabel: UILabel!
    @IBOutlet weak var sendButton: UIButton!

    private var btEnabledStateObserver: AnyCancellable?

    private func setupSubscribers() {
        // base publishers
        let bluetoothStatus = NotificationCenter.Publisher(
            center: .default,
            name: Bluetooth.bluetoothStateChange,
            object: nil)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[Bluetooth.bluetoothStateKey] as? Bluetooth.State }

        let colour = NotificationCenter.Publisher(
            center: .default,
            name: Bluetooth.bluetoothUARTRX,
            object: nil)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[Bluetooth.bluetoothUARTDataKey] as? Data }
            .compactMap({$0})
            .map(interpretColourData)

        // derived publishers
        let bluetoothStatusName = bluetoothStatus.map { $0?.description }
        let bluetoothTransmitEnabled = bluetoothStatus.map{$0 == .notifying}
        let hue = colour.map({$0?.hue})
        let value = colour.map({$0?.value})
        let hueF = hue.compactMap{$0}.map{Float($0)}
        let valueF = value.compactMap{$0}.map{Float($0)}
        // slight hack: create a publisher that needs at least one value from colour and status so we know we have
        // received a value for the colour from the board before we show the controls for the first time
        let showControls = Publishers.CombineLatest(bluetoothTransmitEnabled, colour).map{$0.0}
        let controlsDisabled = showControls.map { !$0 }

        // subscribers
        hueObserver = hue.assign(to: \.currentHue, on: self)
        valueObserver = value.assign(to: \.currentValue, on: self)
        bluetoothStatusName.subscribe(Subscribers.Assign(object: bluetoothStateLabel, keyPath: \.text))
        bluetoothTransmitEnabled.subscribe(Subscribers.Assign(object: sendButton, keyPath: \.isEnabled))
        hueF.subscribe(Subscribers.Assign(object: hueSlider, keyPath: \.value))
        valueF.subscribe(Subscribers.Assign(object: valueSlider, keyPath: \.value))
        controlsDisabled.subscribe(Subscribers.Assign(object: hueColour, keyPath: \.isHidden))
        controlsDisabled.subscribe(Subscribers.Assign(object: hueSlider, keyPath: \.isHidden))
        controlsDisabled.subscribe(Subscribers.Assign(object: valueSlider, keyPath: \.isHidden))

        // when bluetooth becomes available, ask what the current colour is
        btEnabledStateObserver = bluetoothTransmitEnabled.sink { enabled in
            if enabled {
                // ask for current state
                Bluetooth.shared.send(data: "?".data(using: .ascii)!)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        hueSlider.transform = CGAffineTransform(rotationAngle: .pi / 2)

        // setup the reactive views
        setupSubscribers()

        // start bluetooth
        Bluetooth.shared.start()
    }

    private var hueObserver: AnyCancellable?
    private var valueObserver: AnyCancellable?

    private func updateViewColour() {
        guard let hue = currentHue, let value = currentValue else {
            return
        }

        let c = UIColor(hue: CGFloat(hue) / 255.0, saturation: 1.0, brightness: CGFloat(value) / 100.0, alpha: 1.0)
        hueColour.backgroundColor = c
    }

    @IBAction func hueSliderChanged(_ sender: UISlider) {
        currentHue = CGFloat(sender.value)
    }

    @IBAction func valueSliderChanged(_ sender: UISlider) {
        currentValue = CGFloat(sender.value)
    }

    @IBAction func sendValues(_ sender: UIButton) {
        guard let hue = currentHue, let value = currentValue else {
            return
        }

        Bluetooth.shared.send(data: getColourData(hue: hue, value: value))
    }

    var currentHue: CGFloat? {
        didSet {
            updateViewColour()
        }
    }

    var currentValue: CGFloat? {
        didSet {
            updateViewColour()
        }
    }
}
