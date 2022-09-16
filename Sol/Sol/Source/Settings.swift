//
//  Settings.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-13.
//

import Foundation
import SolData

public enum Settings: String {
	case sdoImageSet
	case sdoResolution
	case sdoPFSS

	static func postChangeNotification() {
		NotificationCenter.default.post(name: Settings.notificationName, object: nil)
	}

	static var notificationName: Notification.Name {
		return Notification.Name("Sol_settings_changed")
	}

	enum `default` {
		static let sdoImageSet = SDOImage.ImageSet.i0131
		static let sdoResolution = SDOImage.Resolution.x1024
		static let sdoPFSS = false
	}
}
