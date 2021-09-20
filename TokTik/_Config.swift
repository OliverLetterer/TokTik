//
//  _Config.swift
//  _Config
//
//  Created by Oliver Letterer on 02.09.21.
//

import Foundation

public struct _Config {
    public struct TikTokProfile {
        public var id: String
        public var username: String
        public var secUid: String
    }
    
    public static let profiles: [TikTokProfile] = [
        .init(id: "6829332199004062725", username: "theevaelfie", secUid: "MS4wLjABAAAA70IeB6pal_oQkG4sUKQTs-Mz2xcOakKdxNDY2d8L0QNASlMGwOhrn9xbYOMRebrU"),
        .init(id: "6946620569643500549", username: "ryukahr", secUid: "MS4wLjABAAAAiPQCRk23WZyW4B9nW_6g4VZ49Fy15Pr1J5N3M1GMYku2TtZBnmqkfUug7dSE40iN"),
    ]
    
    public static var signEndpoint: String? {
        get {
            return UserDefaults.standard.string(forKey: "settings.signEndpoint")
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "settings.signEndpoint")
        }
    }
    
    public static var lastRefresh: Date? {
        get {
            return UserDefaults.standard.value(forKey: "settings.lastRefresh") as? Date
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "settings.lastRefresh")
        }
    }
    
    @CodableSettingsValue<[TikTok]>(defaults: .standard, key: "settings.tiktoks", defaultValue: []) public static var tikToks: [TikTok]
}
