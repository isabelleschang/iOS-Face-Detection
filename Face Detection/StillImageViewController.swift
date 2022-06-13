//
//  StillImages.swift
//  Face Detection
//
//  Created by Tomasz Baranowicz on 15/07/2020.
//  Copyright © 2020 Tomasz Baranowicz. All rights reserved.
//

import UIKit
import Vision

class StillImageViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    var scaledImageRect: CGRect? // this will contain exact size of input image after it's scaled
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let image = UIImage(named: "iprofile") {
            imageView.image = image
            
            guard let cgImage = image.cgImage else {
                return
            }
    
            calculateScaledImageRect()
            
            // ^^this calculates original and size of image in ui imageview; vision framework doesn't really know its position
            performVisionRequest(image: cgImage)
            // ^^this send ui image to vision framework, asks it to detect a face
            // parameter: cgimage aka core graphics image; feeding this one into vision because it has more information than the ui imag
        }
    }
    
    private func calculateScaledImageRect() {
        guard let image = imageView.image else {
            return
        }

        guard let cgImage = image.cgImage else {
            return
        }
        
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)

        let imageFrame = imageView.frame
        let widthRatio = originalWidth / imageFrame.width
        let heightRatio = originalHeight / imageFrame.height

        // ScaleAspectFit
        let scaleRatio = max(widthRatio, heightRatio)

        let scaledImageWidth = originalWidth / scaleRatio
        let scaledImageHeight = originalHeight / scaleRatio

        let scaledImageX = (imageFrame.width - scaledImageWidth) / 2
        let scaledImageY = (imageFrame.height - scaledImageHeight) / 2
        
        self.scaledImageRect = CGRect(x: scaledImageX, y: scaledImageY, width: scaledImageWidth, height: scaledImageHeight)
    }
    
    private func performVisionRequest(image: CGImage) {
         
         let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleFaceDetectionRequest)
        //let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleFaceDetectionRequest)
        //can request for multiple things like contours, face landmarks, etc...
        //face landmarks in live feed
        //we need completionhandler as parameter
        //can sive time by sending multiple requests at once

         let requests = [faceDetectionRequest] // put all requests you want in an array to save time! but in our cae here, we only have one request aka facedetectionequest which is a detectfacerectanglesrequest
         let imageRequestHandler = VNImageRequestHandler(cgImage: image, // this is used to handle the array of requests from vision
                                                         orientation: .up,
                                                         options: [:])
         
         DispatchQueue.global(qos: .userInitiated).async { // call code ansynchronously as to not block ui main thread and keep app responsible
             do {
                 try imageRequestHandler.perform(requests)
             } catch let error as NSError {
                 print(error)
                 return
             }
         }
     }
    
    private func handleFaceDetectionRequest(request: VNRequest?, error: Error?) { //completion handler is being called
        if let requestError = error as NSError? { //first ensure there's no error
            print(requestError)
            return
        }
        
        guard let imageRect = self.scaledImageRect else { // ensure that we've counted scaledimage rect
            return
        }
            
        let imageWidth = imageRect.size.width //get image width
        let imageHeight = imageRect.size.height //get image height
        
        DispatchQueue.main.async { //create an overlay over the ui imageview, have to call this code in main thread
            
            self.imageView.layer.sublayers = nil // in case it was called previoulsy, remove all sublayers; nil = absence of a value of a certain type
            if let results = request?.results as? [VNFaceObservation] { // question mark = value is optional; just making sure that return to results array is not nil
                //vision framework returns results, whcih is an array of vision face obseration
                //if wer'e calling different rquests, also have to handle different types like vnbarcodeobservations
                
                for observation in results { //for loop going through all results reutnred from vision; each observation is a vision faceobservation object
                    
                    //tricky part: ui view starting point is top left corner (0,0) and (max,max) is in bottom right, but vision observations are being returned with startingpoint (0,0) in bottom left and (max,max) in top right
                    // so we have to flip result from vision
                    // result contains bounding box with range from 0.0 to 1.0; bounding box is a rectangle that acts as a reference point for an object; used in obj detection
                    print(observation.boundingBox)
                    
                    var scaledObservationRect = observation.boundingBox // sor is a rectangle drawn around the face; we do this by using boundingbox object
                    //since input image and vision have different orientations, need to do some transformations to the rectangle (next four lines)
                    scaledObservationRect.origin.x = imageRect.origin.x + (observation.boundingBox.origin.x * imageWidth) //box origin point x coordinate
                    scaledObservationRect.origin.y = imageRect.origin.y + (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * imageHeight //box origin point y coordinate
                    scaledObservationRect.size.width *= imageWidth // box length
                    scaledObservationRect.size.height *= imageHeight // box height
                    //obersavation rectangle complete!
                    let faceRectanglePath = CGPath(rect: scaledObservationRect, transform: nil) //coregraphics path to be drawn on the newly greated layer
                    
                    let faceLayer = CAShapeLayer() // create a layer at this path
                    faceLayer.path = faceRectanglePath // add the path
                    faceLayer.fillColor = UIColor.clear.cgColor // transparent
                    faceLayer.strokeColor = UIColor.yellow.cgColor // stroke color yellow
                    self.imageView.layer.addSublayer(faceLayer) // add layer to uiimageview
                }
            }
        }
    }
}
