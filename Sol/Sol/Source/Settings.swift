//
//  Settings.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-13.
//

import Foundation

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
}
