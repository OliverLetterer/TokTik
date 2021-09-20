//
//  _TikTokViewController.swift
//  _TikTokViewController
//
//  Created by Oliver Letterer on 02.09.21.
//

import Foundation
import UIKit
import AVFoundation
import Alamofire
import Combine

public class _TikTokViewController: UIViewController {
    public let tikTok: TikTok
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    private let usernameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .body)
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .callout)
        return label
    }()
    
    private let coverImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        return imageView
    }()
    
    private let playerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }()
    
    private var asset: AVAsset? = nil {
        didSet {
            guard asset != oldValue else {
                return
            }
            
            if let asset = asset {
                let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                playerLayer.player = player
            } else {
                playerLayer.player = nil
            }
            
            self.view.setNeedsLayout()
            _playPause()
        }
    }
    
    private let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .white
        return activityIndicator
    }()
    
    let baseURL: URL = {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("tiktoks")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }()
    
    private var profileImageURL: URL {
        return baseURL.appendingPathComponent(tikTok.author.id + ".png")
    }
    
    private var coverURL: URL {
        return baseURL.appendingPathComponent("cover-" + tikTok.video.id + ".png")
    }
    
    private var videoURL: URL {
        return baseURL.appendingPathComponent("video-" + tikTok.video.id + ".mp4")
    }
    
    private var canPlay: Bool = false {
        didSet {
            guard canPlay != oldValue else {
                return
            }
            
            self.view.setNeedsLayout()
            _playPause()
        }
    }
    
    var playDisabled: Bool = false {
        didSet {
            guard playDisabled != oldValue else {
                return
            }
            
            self.view.setNeedsLayout()
            _playPause()
        }
    }
    
    private var _AVPlayerItemDidPlayToEndTime: AnyCancellable? = nil
    private var willEnterForegroundNotification: AnyCancellable? = nil
    
    public init(tikTok: TikTok) {
        self.tikTok = tikTok
        
        super.init(nibName: nil, bundle: nil)
        
        _AVPlayerItemDidPlayToEndTime = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: nil).sink { [weak self] notification in
            guard let self = self, let playerItem = notification.object as? AVPlayerItem, self.playerLayer.player?.currentItem == playerItem else {
                return
            }
            
            playerItem.seek(to: .zero) { _ in
                self._playPause()
            }
        }
        
        willEnterForegroundNotification = NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification, object: nil).dropFirst().sink { [weak self] _ in
            guard let self = self else {
                return
            }
            
            self._playPause()
        }
        
        _loadProfileImage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        canPlay = false
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        canPlay = true
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(coverImageView)
        view.layer.addSublayer(playerLayer)
        
        view.addSubview(activityIndicator)
        view.addSubview(profileImageView)
        view.addSubview(usernameLabel)
        view.addSubview(timestampLabel)
        
        usernameLabel.text = tikTok.author.uniqueId
        timestampLabel.text = DateFormatter.localizedString(from: tikTok.createTime, dateStyle: .medium, timeStyle: .short)
        
        view.backgroundColor = .black
        
        if FileManager.default.fileExists(atPath: profileImageURL.path) {
            profileImageView.image = UIImage(contentsOfFile: profileImageURL.path)
        }
        
        if !FileManager.default.fileExists(atPath: coverURL.path) {
            activityIndicator.startAnimating()
            _downloadCover()
        } else {
            coverImageView.image = UIImage(contentsOfFile: coverURL.path)
            
            if !FileManager.default.fileExists(atPath: self.videoURL.path) {
                self._downloadVideo()
            } else {
                self.asset = AVURLAsset(url: self.videoURL)
            }
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let safeBounds = view.bounds.inset(by: view.safeAreaInsets)
        
        let activitySize = activityIndicator.sizeThatFits(view.bounds.size)
        activityIndicator.frame = CGRect(x: view.bounds.midX - activitySize.width / 2.0, y: view.bounds.midY - activitySize.height / 2.0, width: activitySize.width, height: activitySize.height)
        
        profileImageView.frame = CGRect(x: 16.0, y: safeBounds.maxY - 16.0 - 60.0, width: 60.0, height: 60.0)
        profileImageView.layer.cornerRadius = 30.0
        
        if let asset = asset, let videoTrack = asset.tracks(withMediaType: .video).first {
            playerLayer.isHidden = false
            coverImageView.isHidden = true
            
            let size = AVMakeRect(aspectRatio: videoTrack.naturalSize, insideRect: view.bounds).size
            playerLayer.frame = CGRect(x: view.bounds.midX - size.width / 2.0, y: view.bounds.midY - size.height / 2.0, width: size.width, height: size.height)
        } else if let image = coverImageView.image {
            playerLayer.isHidden = true
            coverImageView.isHidden = false
            
            let size = AVMakeRect(aspectRatio: image.size, insideRect: view.bounds).size
            coverImageView.frame = CGRect(x: view.bounds.midX - size.width / 2.0, y: view.bounds.midY - size.height / 2.0, width: size.width, height: size.height)
            playerLayer.frame = coverImageView.frame
        } else {
            playerLayer.isHidden = true
            coverImageView.isHidden = true
        }
        
        let usernameSize = usernameLabel.sizeThatFits(view.bounds.size)
        usernameLabel.frame = CGRect(x: profileImageView.frame.maxX + 8.0, y: profileImageView.frame.midY - usernameSize.height / 2.0, width: usernameSize.width, height: usernameSize.height)
        
        let timestampSize = timestampLabel.sizeThatFits(view.bounds.size)
        timestampLabel.frame = CGRect(x: profileImageView.frame.minX, y: profileImageView.frame.minY - timestampSize.height - 8.0, width: timestampSize.width, height: timestampSize.height)
    }
    
    private func _playPause() {
        if canPlay, let player = playerLayer.player, !playDisabled {
            player.play()
        } else {
            playerLayer.player?.pause()
        }
    }
}

extension _TikTokViewController {
    private func _loadProfileImage() {
        let download: () -> Void = {
            AF.request(self.tikTok.author.avatarLarger).responseData { response in
                guard let data = response.data else {
                    return
                }
                
                if response.response?.statusCode == 200, UIImage(data: data) != nil {
                    try? FileManager.default.removeItem(at: self.profileImageURL)
                    try? data.write(to: self.profileImageURL)
                }
                
                self.profileImageView.image = UIImage(contentsOfFile: self.profileImageURL.path)
                self.view.setNeedsLayout()
            }
        }
        
        if !FileManager.default.fileExists(atPath: profileImageURL.path) {
            download()
        } else if let creationDate = try? FileManager.default.attributesOfItem(atPath: profileImageURL.path)[.creationDate] as? Date {
            if creationDate < Date.now.addingTimeInterval(-24.0 * 60.0 * 60.0) {
                download()
            }
        }
    }
    
    private func _downloadCover() {
        let destination: DownloadRequest.Destination = { _, _ in
            return (self.coverURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        AF.download(self.tikTok.video.cover, to: destination).response { response in
            if let image = UIImage(contentsOfFile: self.coverURL.path) {
                self.activityIndicator.stopAnimating()
                self.coverImageView.image = image
                
                self.view.setNeedsLayout()
            }
            
            if !FileManager.default.fileExists(atPath: self.videoURL.path) {
                self._downloadVideo()
            }
        }
    }
    
    private func _downloadVideo() {
        let destination: DownloadRequest.Destination = { _, _ in
            return (self.videoURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        let headers: HTTPHeaders = [
            HTTPHeader(name: "Accept", value: "*/*"),
            HTTPHeader(name: "Accept-Encoding", value: "identity;q=1, *;q=0"),
            HTTPHeader(name: "Accept-Language", value: "en-US;en;q=0.9"),
            HTTPHeader(name: "Cache-Control", value: "no-cache"),
            HTTPHeader(name: "Connection", value: "keep-alive"),
            HTTPHeader(name: "Pragma", value: "no-cache"),
            HTTPHeader(name: "Range", value: "bytes=0-"),
            HTTPHeader(name: "Referer", value: "https://www.tiktok.com/"),
        ]
        
        AF.download(tikTok.video.playAddr, headers: headers, to: destination).response { response in
            self.asset = AVURLAsset(url: self.videoURL)
        }
    }
}
