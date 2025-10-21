//
//  AppDelegate.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
       
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Background/Foreground Handling
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Останавливаем аудио запись при переходе в background
        print("📱 App entered background - stopping audio recording")
        // Обработка перехода в background будет реализована через делегаты
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Восстанавливаем состояние при возврате из background
        print("📱 App will enter foreground - checking audio session")
        // Обработка возврата из background будет реализована через делегаты
    }
}

