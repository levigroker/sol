//
//  AppDelegate.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-10.
//

import UIKit
import SolData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		// Kick off a pre-fetch of what is configured in User Defaults
		// NOTE: we don't care if this fails or need to await it here... we just want to ensure we have a head start on the expected data needs
		Task {
			try? await SDODataManager.shared.prefetchImages(date: Date(), imageSet: Settings.sdoImageSet(), resolution: Settings.sdoResolution(), pfss: Settings.sdoPFSS())
		}

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
}
