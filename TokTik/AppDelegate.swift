//
//  AppDelegate.swift
//  TokTik
//
//  Created by Oliver Letterer on 02.09.21.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let endpoint = ProcessInfo.processInfo.environment["SIGN_ENDPOINT"] {
            _Config.signEndpoint = endpoint
        }
        
        if _Config.signEndpoint == nil, URL(string: _Config.signEndpoint!) != nil {
            fatalError("Please provide a signing endpoint SIGN_ENDPOINT as environment variable")
        } else {
            print("Configured TikTok at \(_Config.signEndpoint!)")
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
