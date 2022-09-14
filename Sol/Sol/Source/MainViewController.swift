//
//  MainViewController.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-10.
//

import UIKit
import SwiftUI
import os
import SolData

class MainViewController: UIViewController {

	deinit {
		NotificationCenter.default.removeObserver(self, name:  NSNotification.Name("com.user.login.success"), object: nil)
	}

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	func setup() {
		NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: Settings.notificationName, object: nil)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	@IBSegueAction func presentSettingsView(_ coder: NSCoder) -> UIViewController? {
		return UIHostingController(coder: coder, rootView: SettingsView())
	}

	// Settings
	@AppStorage(Settings.sdoImageSet.rawValue)
	private var settingImageSet: SDODataManager.ImageSet = .i0131
	@AppStorage(Settings.sdoResolution.rawValue)
	private var settingResolution = SDODataManager.Resolution.x1024
	@AppStorage(Settings.sdoPFSS.rawValue)
	private var settingPFSS = true
}

@objc
extension MainViewController {
	func settingsChanged() {
		Logger().info("""
Settings changed:
   settingImageSet '\(self.settingImageSet.rawValue)'
 settingResolution '\(self.settingResolution.rawValue)'
       settingPFSS '\(self.settingPFSS)'
""")
	}
}
