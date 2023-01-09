//
//  ViewController.swift
//  FaceIDApp-iOS16
//
//  Created by Bedirhan Altun on 30.12.2022.
//

import UIKit
import AVFoundation
import MLKitFaceDetection
import MLKitVision


class ViewController: UIViewController {
    
    @IBOutlet weak var detectActionLabel: UILabel!
    @IBOutlet weak var cameraView: FacialGestureCameraView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        addCameraViewDelegate()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startGestureDetection()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopGestureDetection()
    }
}





extension ViewController: FacialGestureCameraViewDelegate {
    func doubleEyeBlinkDetected() {
        DispatchQueue.main.async {
            self.detectActionLabel.text = "İki göz kırpıldı 👀"
        }
    }
    func smileDetected() {
        DispatchQueue.main.async {
            self.detectActionLabel.text = "Güldü 😁"
        }
    }
    func nodLeftDetected() {
        DispatchQueue.main.async {
            self.detectActionLabel.text = "Kafa sola çevrildi."
        }
    }
    func nodRightDetected() {
        DispatchQueue.main.async {
            self.detectActionLabel.text = "Kafa sağa çevrildi."
        }
    }
    func leftEyeBlinkDetected() {
        DispatchQueue.main.async {
            self.detectActionLabel.text = "Sol göz kırpıldı."
        }
    }
    func rightEyeBlinkDetected() {
        DispatchQueue.main.async {
            self.detectActionLabel.text = "Sağ göz kırpıldı."
        }
    }
}

extension ViewController {
    func addCameraViewDelegate() {
        cameraView.delegate = self
    }
    func startGestureDetection() {
        cameraView.beginSession()
    }
    func stopGestureDetection() {
        cameraView.stopSession()
    }
}
