//
//  ViewController.swift
//  SemanticSegmentation
//
//  Created by Tigran VIasyan on 30.01.23.
//

import UIKit
import CoreML
import Vision
import AVFAudio

class ViewController: UIViewController {
    
    @IBOutlet weak var segmentedImage: UIImageView!
    @IBOutlet weak var secondSegmentedImage: UIImageView!
    
    var images = ["img1","img2","img3","img4","img5","img6","img7","img8"]
    var i = 0
    var j = 0
    var timerOne: Timer?
    var timerTwo: Timer?
    let audioEngine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    
    lazy var model: DeepLabV3 = {
        return makeModel()
    }()!
    
    func runModel(on imageName: String) -> UIImage {
        var image = UIImage(named: imageName)
        
        image = image?.resized(to: CGSize(width: 513, height: 513))
        
        if image == nil { return UIImage() }
        
        guard let pixelBuffer = image?.pixelBuffer(width: Int((image?.size.width)!), height: Int((image?.size.height)!)),
              let outputPredictionImage = try? model.prediction(image: pixelBuffer),
              // CoreMLHelpers -> MLMultiArray+Image
              let outputImage = outputPredictionImage.semanticPredictions.image(min: 0, max: 1, axes: (0, 0, 1)),
              let outputCIImage = CIImage(image: outputImage),
              // CIImage extension helper method
              let maskImage = outputCIImage.removeWhitePixels(),
              let resizedCIImage = CIImage(image: image!),
              // (Optional) Blur image a bit if you want to avoid sharpness
              let maskBlurImage = maskImage.applyBlurEffect() else { return UIImage() }
        
        // After we get a final background image we are going to use it as a mask for composing with the resized image.
        guard let compositedImage = resizedCIImage.composite(with: maskBlurImage) else { return UIImage() }
        let rootImage = UIImage(named: imageName)!
        return UIImage(ciImage: compositedImage)
            .resized(to: CGSize(width: rootImage.size.width, height: rootImage.size.height))
    }
    
    private func makeModel() -> DeepLabV3? {
        let modelURL = Bundle.main.url(forResource: "DeepLabV3", withExtension: "mlmodelc")
        do {
            let model = try DeepLabV3(contentsOf: modelURL!)
            return model
        } catch {
            print(error)
        }
        
        return nil
    }
    
    func playMusic() {
        let url = Bundle.main.url(forResource: "music", withExtension: "aac")!
        do {
            let audioFile = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: .init(audioFile.length)) else { return }
            try audioFile.read(into: buffer)
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: buffer.format)
            try audioEngine.start()
            player.play()
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            
        } catch {
            print(error)
        }
    }
    
    override func viewDidLoad()  {
        super.viewDidLoad()
        playMusic()
        segmentedImage.image = UIImage(named: images[i])
        timerOne = Timer.scheduledTimer(timeInterval: 1.20, target:self, selector: #selector(changeSegmentImage), userInfo: nil, repeats: true)
    }
    
    @objc func changeFullImage() {
        if j == images.count {
            player.stop()
            timerTwo?.invalidate()
        }
        if j < images.count {
            self.segmentedImage.image = UIImage(named: images[j])
        }
        self.j += 1
    }
    
    @objc func changeSegmentImage() {
        if i == images.count {
            timerOne?.invalidate()
        }
        if i < images.count {
            self.secondSegmentedImage.image = self.runModel(on: self.images[self.i])
        }
        self.i += 1
        timerTwo = Timer.scheduledTimer(timeInterval: 0.40, target:self, selector: #selector(changeFullImage), userInfo: nil, repeats: false)
    }
}
