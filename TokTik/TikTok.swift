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
    
    private static var script: String {
        let url = Bundle.main.url(forResource: "signer", withExtension: "js")!
        return String(data: try! Data(contentsOf: url), encoding: .utf8)!
    }
    
    public var id: String
    public var createTime: Date
    public var video: Video
    public var author: Author
    public var isAd: Bool
    
    public struct SignResponse: Codable {
        public struct Data: Codable {
            public struct Navigator: Codable {
                public var user_agent: String
            }
            
            public var signed_url: URL
            public var navigator: Navigator
        }
        
        public var status: String
        public var data: Data
    }
    
    public static func sign(url: String, completion: @escaping (Result<SignResponse, Error>) -> Void) {
        var request = try! URLRequest(url: _Config.signEndpoint!, method: .post)
        request.httpBody = url.data(using: .utf8)!

        AF.request(request).responseDecodable(of: SignResponse.self) { response in
            guard let body = response.value else {
                completion(.failure(response.error ?? URLError(.badServerResponse)))
                return
            }

            completion(.success(body))
        }
    }
}
