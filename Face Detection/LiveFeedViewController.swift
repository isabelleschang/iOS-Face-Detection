//
//  LiveFeedViewController.swift
//  Face Detection
//
//  Created by Tomasz Baranowicz on 15/07/2020.
//  Copyright © 2020 Tomasz Baranowicz. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

class LiveFeedViewController: UIViewController {
    
    private let captureSession = AVCaptureSession() // avcapturesession is an object that is available to handle stream coming from the camera (in our case, buffer and stream from front camera but we can use other sources)
    
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession) // we'll use this to add to our view, be able to see what's going on
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var faceLayers: [CAShapeLayer] = [] // array of cashapelayer

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera() // a method that uses avfoundation to discover built-in camera (front camera)
        captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }
    
    private func setupCamera() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front) // maek sure tehre's a real device available in the system
        if let device = deviceDiscoverySession.devices.first { // if there is a device, then
            if let deviceInput = try? AVCaptureDeviceInput(device: device) { // we get ^^ form the discovery session
                if captureSession.canAddInput(deviceInput) { // and add it to captureSession! captusreSession (declared in line 15) is an avcapturesession
                    captureSession.addInput(deviceInput)
                    
                    setupPreview() // method adds preview layer to existing view and setting up details of video data output and sample buffer
                }
            }
        }
    }
    
    private func setupPreview() {
        self.previewLayer.videoGravity = .resizeAspectFill //set type of resize nd fram for preview layer
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
        
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any] // create video data output which will be provided to capture session

        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        
        let videoConnection = self.videoDataOutput.connection(with: .video) // video connection object, obtained from videodataoutput to set orientation for portrait
        videoConnection?.videoOrientation = .portrait // ^^sets portrait mode
    }
}

extension LiveFeedViewController: AVCaptureVideoDataOutputSampleBufferDelegate { //we want ot provide feed to vision framework andthen get face detection rectangle
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) { //avcapture video data output sample buffer delegate method
        //set samplebufferdelegate in line 52
        
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { //every time a frame is received from the buffer, this method is called; ensures taht image buffer is existing and available
          return
        }

        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in // create face detection request like we did in stillimageviewcontroller
            //facelandmarksrequest allows us to get face landmarks on top of just the rectangle
            //completionhandler is not in a separate method; in the same line (request and error)
            DispatchQueue.main.async { //this has to be called on main thread because we want to add some additional layers
                self.faceLayers.forEach({ drawing in drawing.removeFromSuperlayer() }) // facelayers var from line 19; adding to current feed, removing at each frame
                //each facelayer[i] will contain different fce rectangleor face landmark; draw on different layers; quickly added and deleted from preview
                //removefromsuperlayer: removes all old face layers
                if let observations = request.results as? [VNFaceObservation] { // get observations and then we'll handle those observations
                    self.handleFaceDetectionObservations(observations: observations) //calls handleFaceDetectionObservations method to handle^^
                }
            }
        })

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .leftMirrored, options: [:]) // need a requesthandler in order to handle requests
        //remeber we're using front camera, so it's like a mirror; flipped

        do {
            try imageRequestHandler.perform([faceDetectionRequest]) // provide array of requests (in our case, just one detectfaciallandmarksrequest)
        } catch {
          print(error.localizedDescription)
        }
    }
    
    private func handleFaceDetectionObservations(observations: [VNFaceObservation]) {
        for observation in observations {
            let faceRectConverted = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox) // instead of manually transforming can just call layerrectconverted method on preview layer because it's an avcapture preview layer, which contains the layerrectconverted method
            let faceRectanglePath = CGPath(rect: faceRectConverted, transform: nil) // path we trace to draw the bounding box
            
            let faceLayer = CAShapeLayer()
            faceLayer.path = faceRectanglePath
            faceLayer.fillColor = UIColor.clear.cgColor
            faceLayer.strokeColor = UIColor.yellow.cgColor
            
            self.faceLayers.append(faceLayer)
            self.view.layer.addSublayer(faceLayer)
            
            //FACE LANDMARKS
            if let landmarks = observation.landmarks { // landmarks: an array of the landmarks returned by vndetecfacelandmarksrequest, an enum?
                if let leftEye = landmarks.leftEye {
                    self.handleLandmark(leftEye, faceBoundingBox: faceRectConverted) // handle it; create another layer to draw it and put it on our live feed
                    //REMEMBER: the coordinates of this landmark are according not to the live feed but to the rectangle of the detected face
                    //provide face bounding box first, and then find points for features
                }
                if let leftEyebrow = landmarks.leftEyebrow {
                    self.handleLandmark(leftEyebrow, faceBoundingBox: faceRectConverted)
                }
                if let rightEye = landmarks.rightEye {
                    self.handleLandmark(rightEye, faceBoundingBox: faceRectConverted)
                }
                if let rightEyebrow = landmarks.rightEyebrow {
                    self.handleLandmark(rightEyebrow, faceBoundingBox: faceRectConverted)
                }

                if let nose = landmarks.nose {
                    self.handleLandmark(nose, faceBoundingBox: faceRectConverted)
                }

                if let outerLips = landmarks.outerLips {
                    self.handleLandmark(outerLips, faceBoundingBox: faceRectConverted)
                }
                if let innerLips = landmarks.innerLips {
                    self.handleLandmark(innerLips, faceBoundingBox: faceRectConverted)
                    
                }
                if let leftPupil = landmarks.leftPupil {
                    self.handleLandmark(leftPupil, faceBoundingBox: faceRectConverted)
                    
                }
            }
        }
    }
    
    private func handleLandmark(_ eye: VNFaceLandmarkRegion2D, faceBoundingBox: CGRect) {
        let landmarkPath = CGMutablePath() // new mutable coregraphics path
        let landmarkPathPoints = eye.normalizedPoints
            .map({ eyePoint in  // each point has to be mapped (mutliplied by face bounding box width and height, adjust for box origin points)
                CGPoint(
                    x: eyePoint.y * faceBoundingBox.height + faceBoundingBox.origin.x,
                    y: eyePoint.x * faceBoundingBox.width + faceBoundingBox.origin.y)
            })
        landmarkPath.addLines(between: landmarkPathPoints) //draw lines between landmarkpathpoints
        landmarkPath.closeSubpath() //close path
        let landmarkLayer = CAShapeLayer()
        landmarkLayer.path = landmarkPath
        landmarkLayer.fillColor = UIColor.clear.cgColor // clear fill
        landmarkLayer.strokeColor = UIColor.green.cgColor // green border

        self.faceLayers.append(landmarkLayer)
        self.view.layer.addSublayer(landmarkLayer)
    }
}
