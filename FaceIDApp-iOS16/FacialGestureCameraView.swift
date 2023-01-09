//
//  FacialGestureCameraView.swift
//  FaceIDApp-iOS16
//
//  Created by Bedirhan Altun on 30.12.2022.
//

import UIKit
import AVFoundation
import MLKitVision
import MLKitFaceDetection


class FacialGestureCameraView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public var leftNodThreshold: CGFloat = 20.0
    public var rightNodThreshold: CGFloat = -4
    public var smileProbality: CGFloat = 0.8
    public var openEyeMaxProbability: CGFloat = 0.95
    public var openEyeMinProbability: CGFloat = 0.1
    private var restingFace: Bool = true
    
    
    
    private lazy var options: FaceDetectorOptions = {
        let option = FaceDetectorOptions()
        option.performanceMode = .accurate
        option.landmarkMode = .none
        option.classificationMode = .all
        option.isTrackingEnabled = false
        option.contourMode = .none
        return option
    }()
    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoOutput.connection(with: .video)?.isEnabled = true
        return videoOutput
    }()
    private let videoDataOutputQueue: DispatchQueue = DispatchQueue(label: "VideoDataOutputQueue")
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    private let captureDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    private lazy var session: AVCaptureSession = {
        return AVCaptureSession()
    }()
    
    func beginSession() {
        guard let captureDevice = captureDevice else { return }
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        layer.masksToBounds = true
        layer.addSublayer(previewLayer)
        previewLayer.frame = bounds
        
        DispatchQueue.global().async {
            self.session.startRunning()
        }
    }
    func stopSession() {
        session.stopRunning()
    }
    
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        let visionImage = VisionImage(buffer: sampleBuffer)
        let visionOrientation = visionImageOrientation(from: imageOrientation())
        visionImage.orientation = visionOrientation
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        DispatchQueue.global().async {
            self.detectFacesOnDevice(in: visionImage,
                                     width: imageWidth,
                                     height: imageHeight)
        }
    }
    private func visionImageOrientation(from imageOrientation: UIImage.Orientation) ->
    UIImage.Orientation {
        
        switch imageOrientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
            
        @unknown default:
            fatalError()
        }
    }
    private func imageOrientation(fromDevicePosition devicePosition: AVCaptureDevice.Position = .front) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown ||
            deviceOrientation == .faceUp ||
            deviceOrientation == .unknown {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            fatalError()
        }
    }
    private func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown, .none:
                return .portrait
            @unknown default:
                fatalError()
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
    
    
    public weak var delegate: FacialGestureCameraViewDelegate?
    
    private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        let faceDetector = FaceDetector.faceDetector(options: options)
        faceDetector.process(image, completion: { features, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard error == nil, let features = features, !features.isEmpty else {
                return
            }
            if let face = features.first {
                let leftEyeOpenProbability = face.leftEyeOpenProbability
                let rightEyeOpenProbability = face.rightEyeOpenProbability
                // left head nod
                if face.headEulerAngleZ > self.leftNodThreshold {
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.nodLeftDetected?()
                    }
                } else if face.headEulerAngleZ < self.rightNodThreshold {
                    //Right head tilt
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.nodRightDetected?()
                    }
                } else if leftEyeOpenProbability > self.openEyeMaxProbability &&
                            rightEyeOpenProbability < self.openEyeMinProbability {
                    // Right Eye Blink
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.rightEyeBlinkDetected?()
                    }
                } else if rightEyeOpenProbability > self.openEyeMaxProbability &&
                            leftEyeOpenProbability < self.openEyeMinProbability {
                    // Left Eye Blink
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.leftEyeBlinkDetected?()
                    }
                } else if face.smilingProbability > self.smileProbality {
                    // smile detected
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.smileDetected?()
                    }
                } else if leftEyeOpenProbability < self.openEyeMinProbability && rightEyeOpenProbability < self.openEyeMinProbability {
                    // full/both eye blink
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.doubleEyeBlinkDetected?()
                    }
                } else {
                    // Face got reseted
                    self.restingFace = true
                }
            }
        })
    }
}

@objc public protocol FacialGestureCameraViewDelegate: AnyObject {
    @objc optional func doubleEyeBlinkDetected()
    @objc optional func smileDetected()
    @objc optional func nodLeftDetected()
    @objc optional func nodRightDetected()
    @objc optional func leftEyeBlinkDetected()
    @objc optional func rightEyeBlinkDetected()
}
