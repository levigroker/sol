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

	static func sdoImageSet() -> SDOImage.ImageSet {
		guard let string = UserDefaults.standard.string(forKey: sdoImageSet.rawValue), let value = SDOImage.ImageSet(rawValue: string) else {
			return Settings.default.sdoImageSet
		}
		return value
	}

	static func setSDOImageSet(imageSet: SDOImage.ImageSet) {
		UserDefaults.standard.set(imageSet.rawValue, forKey: sdoImageSet.rawValue)
		postChangeNotification()
	}

	static func sdoResolution() -> SDOImage.Resolution {
		guard let string = UserDefaults.standard.string(forKey: sdoResolution.rawValue), let value = SDOImage.Resolution(rawValue: string) else {
			return Settings.default.sdoResolution
		}
		return value
	}

	static func setSDOResolution(resolution: SDOImage.Resolution) {
		UserDefaults.standard.set(resolution.rawValue, forKey: sdoResolution.rawValue)
		postChangeNotification()
	}

	// NOTE: We are using a String for the type of PFSS (as opposed to Bool) so we can properly assign a default value if UserDefaults does not have a value
	// (it will return `false` for a query against Bool if the key is not present)
	// While our default.sdoPFSS _is_ false now, this could change and if so we would want to ensure we are assiging the desired default
	static func sdoPFSS() -> Bool {
		guard let string = UserDefaults.standard.string(forKey: sdoPFSS.rawValue), let value = Bool(string) else {
			return Settings.default.sdoPFSS
		}
		return value
	}

	static func setSDOPFSS(pfss: Bool) {
		UserDefaults.standard.set(pfss.description, forKey: sdoPFSS.rawValue)
		postChangeNotification()
	}

	static func postChangeNotification() {
		NotificationCenter.default.post(name: notificationName, object: nil)
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
