//
//  SceneDelegate.swift
//  WhisperkitProtypeApp
//
//  Created by AlbertKh on 19.10.2025.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
      
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: TranscriptionViewController())
        self.window = window
        window.makeKeyAndVisible()
        
        print("🚀 App launched with TranscriptionViewController")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Освобождаем ресурсы при отключении сцены
        print("📱 Scene disconnected - cleaning up resources")
        // Обработка отключения сцены будет реализована через делегаты
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Восстанавливаем активность приложения
        print("📱 Scene became active - resuming operations")
        // Обработка восстановления активности будет реализована через делегаты
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Приостанавливаем операции при потере активности
        print("📱 Scene will resign active - pausing operations")
        // Обработка приостановки будет реализована через делегаты
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Восстанавливаем состояние при возврате из background
        print("📱 Scene will enter foreground - restoring state")
        // Обработка возврата из background будет реализована через делегаты
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Сохраняем состояние при переходе в background
        print("📱 Scene did enter background - saving state")
        // Обработка перехода в background будет реализована через делегаты
    }


}

