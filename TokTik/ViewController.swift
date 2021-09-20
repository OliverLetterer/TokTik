//
//  ViewController.swift
//  TokTik
//
//  Created by Oliver Letterer on 02.09.21.
//

import UIKit
import Combine
import AVFoundation
import Alamofire
import ProgressHUD

class ViewController: UIViewController {
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    private var tikToks: [TikTok] {
        didSet {
            guard tikToks != oldValue else {
                return
            }
            
            if isViewLoaded {
                if let tikTok = tikToks.first {
                    if let previous = pageViewController.viewControllers?.first as? _TikTokViewController {
                        if previous.tikTok.id != tikTok.id {
                            pageViewController.setViewControllers([ _TikTokViewController(tikTok: tikTok) ], direction: .reverse, animated: true, completion: nil)
                            (pageViewController.viewControllers!.first! as! _TikTokViewController).playDisabled = playDisabled
                        }
                    } else {
                        pageViewController.setViewControllers([ _TikTokViewController(tikTok: tikTok) ], direction: .reverse, animated: false, completion: nil)
                        (pageViewController.viewControllers!.first! as! _TikTokViewController).playDisabled = playDisabled
                    }
                } else {
                    let viewController = UIViewController()
                    viewController.view.backgroundColor = .black
                    pageViewController.setViewControllers([ viewController ], direction: .forward, animated: false, completion: nil)
                }
            }
        }
    }
    
    private var _isReloading: Bool = false
    
    private var playDisabled: Bool = false {
        didSet {
            guard playDisabled != oldValue else {
                return
            }
            
            pageViewController.viewControllers?.compactMap({ $0 as? _TikTokViewController }).forEach({ $0.playDisabled = playDisabled })
        }
    }
    
    private let pageViewController: UIPageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .vertical, options: nil)
    private var willEnterForegroundNotification: AnyCancellable? = nil
    
    public init() {
        self.tikToks = _Config.tikToks.sorted(by: { $0.createTime < $1.createTime }).reversed()
        
        super.init(nibName: nil, bundle: nil)
        
        pageViewController.delegate = self
        pageViewController.dataSource = self
        
        addChild(pageViewController)
        pageViewController.didMove(toParent: self)
        
        willEnterForegroundNotification = NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification, object: nil).dropFirst().sink { [weak self] _ in
            guard let self = self else {
                return
            }
            
            self._reloadData(_checkLastRefresh: true)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        view.addSubview(pageViewController.view)
        view.backgroundColor = .black
        
        if let tikTok = tikToks.first {
            pageViewController.setViewControllers([ _TikTokViewController(tikTok: tikTok) ], direction: .forward, animated: false, completion: nil)
            (pageViewController.viewControllers!.first! as! _TikTokViewController).playDisabled = playDisabled
        } else {
            let viewController = UIViewController()
            viewController.view.backgroundColor = .black
            pageViewController.setViewControllers([ viewController ], direction: .forward, animated: false, completion: nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        _reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        pageViewController.view.frame = view.bounds
    }
}

extension ViewController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewController = viewController as? _TikTokViewController, let index = tikToks.firstIndex(where: { $0.id == viewController.tikTok.id }), index < tikToks.count - 1 else {
            return nil
        }
        
        let result = _TikTokViewController(tikTok: tikToks[index + 1])
        result.playDisabled = playDisabled
        return result
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewController = viewController as? _TikTokViewController, let index = tikToks.firstIndex(where: { $0.id == viewController.tikTok.id }), index > 0 else {
            return nil
        }
        
        let result = _TikTokViewController(tikTok: tikToks[index - 1])
        result.playDisabled = playDisabled
        return result
    }
}

private extension ViewController {
    func amIBeingDebugged() -> Bool {
        var info = kinfo_proc()
        var mib : [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        assert(junk == 0, "sysctl failed")
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    func _reloadData(_checkLastRefresh: Bool = false) {
        guard !_isReloading else {
            return
        }
        
        if amIBeingDebugged() || _checkLastRefresh, let lastRefresh = _Config.lastRefresh {
            guard lastRefresh > Date.now || abs(lastRefresh.timeIntervalSince(.now)) > 120.0 || tikToks.count == 0 else {
                return
            }
        }
        
        _isReloading = true
        playDisabled = true
        
        ProgressHUD.animationType = .systemActivityIndicator
        ProgressHUD.show()
        
        _reloadProfiles(_Config.profiles) { result in
            self._isReloading = false
            self.playDisabled = false
            ProgressHUD.dismiss()
            
            switch result {
            case let .failure(error):
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            case let .success(tikToks):
                _Config.tikToks = tikToks
                _Config.lastRefresh = .now
                
                self.tikToks = tikToks
            }
        }
    }
    
    func _reloadProfiles(_ profiles: [_Config.TikTokProfile], _tikToks: [TikTok] = [], completion: @escaping (Result<[TikTok], Error>) -> Void) {
        guard let profile = profiles.first else {
            completion(.success(_tikToks.sorted(by: { $0.createTime < $1.createTime }).reversed()))
            return
        }
        
        TikTok.sign(url: "https://m.tiktok.com/api/post/item_list/?aid=1988&count=30&id=\(profile.id)&cursor=0&type=1&secUid=\(profile.secUid)") { result in
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success(body):
                struct TikTokResponse: Codable {
                    var statusCode: Int
                    var itemList: [TikTok]
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                
                AF.request(body.data.signed_url, method: .get, headers: [ .userAgent(body.data.navigator.user_agent) ]).responseDecodable(of: TikTokResponse.self, decoder: decoder) { response in
                    guard let tikToks = response.value?.itemList.prefix(10) else {
                        completion(.failure(response.error ?? URLError(.badServerResponse)))
                        return
                    }
                    
                    var _profiles = profiles
                    _profiles.removeAll(where: { $0.id == profile.id })
                    
                    let result = _tikToks + tikToks
                    self._reloadProfiles(_profiles, _tikToks: result, completion: completion)
                }
            }
        }
    }
}
