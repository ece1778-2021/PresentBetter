import AVKit
import UIKit

class PlaybackViewController: UIViewController {
    @IBOutlet var btnShare: UIButton!
    @IBOutlet var btnDelete: UIButton!
    @IBOutlet var btnClose: UIButton!
    @IBOutlet var imgVideoPreview: UIImageView!
    @IBOutlet var videoPreviewView: UIView!
    @IBOutlet var videoPreviewOverlay: UIView!
    
    var videoURL: URL?
    
    override func viewDidLoad() {
        btnShare.layer.cornerRadius = 10.0
        btnDelete.layer.cornerRadius = 10.0
        btnClose.layer.cornerRadius = 17.0
        btnClose.isHidden = true
        
        videoPreviewView.layer.cornerRadius = 10.0
        imgVideoPreview.layer.cornerRadius = 10.0
        videoPreviewOverlay.layer.cornerRadius = 10.0
        videoPreviewOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        videoPreviewOverlay.isHidden = true
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        videoPreviewOverlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showVideoPlayback)))
        videoPreviewOverlay.isUserInteractionEnabled = true
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeView)))
        view.isUserInteractionEnabled = true
        
        if let videoURL = videoURL {
            getThumbnailFromVideo(videoURL: videoURL) { image in
                self.imgVideoPreview.image = image
                self.videoPreviewOverlay.isHidden = false
            }
        }
    }
    
    func shareVideo(videoURL: URL) {
        let activityItems: [Any] = [videoURL, "Check out my Practice Presenting videos! #PresentBetter"]
        let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let loadingViewController = storyboard.instantiateViewController(withIdentifier: "LoadingViewController") as? LoadingViewController else {
            return
        }
        addChild(loadingViewController)
        loadingViewController.view.frame = view.bounds
        view.addSubview(loadingViewController.view)
        loadingViewController.didMove(toParent: self)
        loadingViewController.viewWillAppear(true)
        
        present(activityController, animated: true) {
            loadingViewController.myViewWillDisappear {
                loadingViewController.didMove(toParent: nil)
                loadingViewController.view.removeFromSuperview()
                loadingViewController.removeFromParent()
            }
        }
    }
    
    func getThumbnailFromVideo(videoURL: URL, completion: @escaping ((_ image: UIImage) -> Void)) {
        DispatchQueue(label: "getThumbnailFromVideo").async {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let catchTime = CMTimeMake(value: 1, timescale: 1)
            do {
                let imageRef = try imageGenerator.copyCGImage(at: catchTime, actualTime: nil)
                let image = UIImage(cgImage: imageRef)
                
                DispatchQueue.main.async {
                    completion(image)
                }
            } catch let e {
                print(e)
            }
        }
    }
    
    @objc func showVideoPlayback() {
        if let videoURL = videoURL {
            let player = AVPlayer(url: videoURL)
            let playerViewController = AVPlayerViewController()
            
            playerViewController.player = player
            playerViewController.modalTransitionStyle = .crossDissolve
            
            present(playerViewController, animated: true, completion: {
                player.play()
            })
        }
    }
    
    func deleteVideo(videoURL: URL?, completion: (() -> Void)?) {
        if let URL = videoURL {
            do {
                try FileManager.default.removeItem(at: URL)
                print("Deleted!")
            } catch let e {
                print(e)
            }
            completion?()
        }
    }
    
    @objc func closeView() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func btnCloseClicked(_ sender: UIButton) {
        closeView()
    }
    
    @IBAction func btnShareClicked(_ sender: UIButton) {
        if let videoURL = videoURL {
            shareVideo(videoURL: videoURL)
        }
    }
    
    @IBAction func btnDeleteClicked(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Delete Video", message: "Are you sure? This cannot be undone.", preferredStyle: .alert)
        
        let actionCancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(actionCancel)
        
        let actionDelete = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteVideo(videoURL: self.videoURL) {
                self.closeView()
                NotificationCenter.default.post(name: Notification.presentationVideoDeleted, object: nil)
            }
        }
        alertController.addAction(actionDelete)
        
        present(alertController, animated: true, completion: nil)
    }
}

extension PlaybackViewController {
    static func showView(_ parentViewController: UIViewController, videoURL: URL?) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let viewController = storyboard.instantiateViewController(identifier: "PlaybackViewController") as? PlaybackViewController {
            viewController.modalTransitionStyle = .crossDissolve
            viewController.modalPresentationStyle = .overFullScreen
            viewController.videoURL = videoURL
            
            parentViewController.present(viewController, animated: true, completion: nil)
        }
    }
}
