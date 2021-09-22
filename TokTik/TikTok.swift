//
//  TikTok.swift
//  TikTok
//
//  Created by Oliver Letterer on 02.09.21.
//

import Foundation
import Alamofire
import UIKit
import WebKit

public struct TikTok: Codable, Equatable, Hashable {
    public struct Video: Codable, Equatable, Hashable {
        public var id: String
        public var cover: URL
        public var playAddr: URL
        public var downloadAddr: URL
        public var format: String
    }
    
    public struct Author: Codable, Equatable, Hashable {
        public var id: String
        public var uniqueId: String
        public var nickname: String
        public var avatarThumb: URL
        public var avatarMedium: URL
        public var avatarLarger: URL
        public var signature: String
        public var verified: Bool
        public var secUid: String
    }
    
    private static var acrawler: String {
        let url = Bundle.main.url(forResource: "acrawler", withExtension: "js")!
        return String(data: try! Data(contentsOf: url), encoding: .utf8)!
    }
    
    private static var ttParams: String {
        let url = Bundle.main.url(forResource: "tt-params", withExtension: "js")!
        return String(data: try! Data(contentsOf: url), encoding: .utf8)!
    }
    
    public var id: String
    public var createTime: Date
    public var video: Video
    public var author: Author
    public var isAd: Bool
    
    public struct InfluencerPostsResponse: Decodable {
        public struct Post: Decodable {
            public struct Video: Decodable {
                public struct InfoData: Decodable {
                    public var url_list: [URL]
                }
                
                public var play_addr: InfoData
                public var cover: InfoData
                public var download_addr: InfoData
            }
            
            public struct Author: Decodable {
                public struct Image: Decodable {
                    public var url_list: [URL]
                }
                
                public var uid: String
                public var unique_id: String
                public var nickname: String
                public var avatar_thumb: Image
                public var avatar_medium: Image
                public var avatar_larger: Image
                public var signature: String
                public var sec_uid: String
            }
            
            public var aweme_id: String
            public var create_time: Date
            public var video: Video
            public var author: Author
        }
        
        public var data: [Post]
        
        public var tikToks: [TikTok] {
            return data.map { post -> TikTok in
                return TikTok(
                    id: post.aweme_id,
                    createTime: post.create_time,
                    video: TikTok.Video(
                        id: post.aweme_id,
                        cover: post.video.cover.url_list.first!,
                        playAddr: post.video.play_addr.url_list.first!,
                        downloadAddr: post.video.download_addr.url_list.first!,
                        format: "unkown"
                    ),
                    author: TikTok.Author(id: post.author.uid,
                                          uniqueId: post.author.unique_id,
                                          nickname: post.author.nickname,
                                          avatarThumb: post.author.avatar_thumb.url_list.first!,
                                          avatarMedium: post.author.avatar_medium.url_list.first!,
                                          avatarLarger: post.author.avatar_larger.url_list.first!,
                                          signature: post.author.signature,
                                          verified: true,
                                          secUid: post.author.sec_uid
                                         ),
                    isAd: false
                )
            }
        }
    }
    
    public struct Signature {
        public var signedURL: URL
        public var ttParams: String
        public var userAgent: String
    }
    
    public static func sign(url unverifiedURL: String, completion: @escaping (Result<Signature, Error>) -> Void) {
        DispatchQueue.main.async {
            var components = URLComponents(string: unverifiedURL)!
            components.queryItems!.append(.init(name: "verifyFp", value: "verify_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")))
            
            let url = components.url!.absoluteString
            
            let window = UIWindow(windowScene: UIApplication.shared.connectedScenes.first! as! UIWindowScene)
            window.rootViewController = UIViewController()
            window.rootViewController!.view.backgroundColor = .white
            window.windowLevel = UIWindow.Level(-1.0)
            
            window.makeKeyAndVisible()
            
            let webView = WKWebView(frame: window.rootViewController!.view.bounds)
            window.rootViewController!.view.addSubview(webView)
            
            class NavigationDelegate: NSObject, WKNavigationDelegate {
                let url: String
                var completion: ((Result<Signature, Error>) -> Void)! = nil
                
                init(url: String) {
                    self.url = url
                }
                
                func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                    webView.evaluateJavaScript(TikTok.acrawler) { _, error in
                        assert(error == nil)
                        
                        webView.evaluateJavaScript(TikTok.ttParams) { _, error in
                            assert(error == nil)
                            
                            webView.evaluateJavaScript("window.navigator.userAgent") { userAgent, error in
                                webView.evaluateJavaScript("window.byted_acrawler.sign({ url: \"\(self.url)\" })") { result, error in
                                    guard let signature = result as? String else {
                                        DispatchQueue.main.async {
                                            self.completion(.failure(error ?? URLError(.badServerResponse)))
                                        }
                                        
                                        return
                                    }
                                    
                                    var components = URLComponents(string: self.url)!
                                    components.queryItems!.append(.init(name: "_signature", value: signature))
                                    
                                    var params: [String: String] = [:]
                                    components.queryItems!.forEach({ params[$0.name] = $0.value! })
                                    
                                    let dictionary = String(data: try! JSONEncoder().encode(params), encoding: .utf8)!
                                    
                                    webView.evaluateJavaScript("window.genXTTParams(\(dictionary))") { result, error in
                                        DispatchQueue.main.async {
                                            if let ttParams = result as? String {
                                                self.completion(.success(Signature(signedURL: components.url!, ttParams: ttParams, userAgent: userAgent as! String)))
                                            } else {
                                                self.completion(.failure(error ?? URLError(.badServerResponse)))
                                            }
                                            
                                            let _ = self
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            let delegate = NavigationDelegate(url: url)
            
            delegate.completion = { result in
                switch result {
                case let .failure(error):
                    completion(.failure(error))
                case let .success(signature):
                    completion(.success(signature))
                }
                
                let _ = window
                delegate.completion = nil
            }
            
            webView.navigationDelegate = delegate
            webView.load(URLRequest(url: URL(string: "https://www.tiktok.com/@rihanna?lang=en")!))
        }
    }
}
