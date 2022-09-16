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

	@IBOutlet private var imageScrollView: ImageScrollView!

	deinit {
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name("com.user.login.success"), object: nil)
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
		guard let image = UIImage(named: "placeholder") else {
			Logger().error("Unable to load placeholder image.")
			return
		}
		imageScrollView.display(image: image)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		Task {
			do {
				let sdoImages = try await SDODataManager.shared.sdoImages(date: Date(), imageSet: settingImageSet, resolution: settingResolution, pfss: settingPFSS)
				guard !sdoImages.isEmpty else {
					Logger().warning("No images for today.")
					return
				}
				let image = try await SDODataManager.shared.image(sdoImages[0])
				imageScrollView.display(image: image)
			}
			catch {
				Logger().error("\(error)")
			}
		}
	}

	@IBSegueAction
	func presentSettingsView(_ coder: NSCoder) -> UIViewController? {
		return UIHostingController(coder: coder, rootView: SettingsView())
	}

	// Settings
	@AppStorage(Settings.sdoImageSet.rawValue)
	private var settingImageSet: SDOImage.ImageSet = Settings.default.sdoImageSet // swift compiler gets confused without specifying the type here

	@AppStorage(Settings.sdoResolution.rawValue)
	private var settingResolution = Settings.default.sdoResolution

	@AppStorage(Settings.sdoPFSS.rawValue)
	private var settingPFSS = Settings.default.sdoPFSS
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
