//
//  CodableSettingsValue.swift
//  core
//
//  Created by Oliver Letterer on 04.09.20.
//  Copyright © 2020 Monkeyspot. All rights reserved.
//

import Foundation

@propertyWrapper public struct CodableSettingsValue<T: Codable> {
    let defaults: UserDefaults
    let key: String
    
    private var storage: T
    public var wrappedValue: T {
        get {
            return storage
        }
        
        set {
            storage = newValue
            
            defaults.setValue(try! JSONEncoder().encode(newValue), forKey: key)
            defaults.synchronize()
        }
    }
    
    public init(defaults: UserDefaults, key: String, defaultValue: T) {
        self.defaults = defaults
        self.key = key
        
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(T.self, from: data) {
            self.storage = value
        } else {
            self.storage = defaultValue
        }
    }
}
