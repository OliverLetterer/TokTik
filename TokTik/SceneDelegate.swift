//
//  SceneDelegate.swift
//  TokTik
//
//  Created by Oliver Letterer on 02.09.21.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
    }
}
