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

	@IBOutlet weak var scrollView: UIScrollView!
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
	@IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
	@IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
	@IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!

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

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
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

extension MainViewController: UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return imageView
	}

	func scrollViewDidZoom(_ scrollView: UIScrollView) {
	  updateConstraintsForSize(view.bounds.size)
	}

	func updateConstraintsForSize(_ size: CGSize) {
	  let yOffset = max(0, (size.height - imageView.frame.height) / 2)
	  imageViewTopConstraint.constant = yOffset
	  imageViewBottomConstraint.constant = yOffset

	  let xOffset = max(0, (size.width - imageView.frame.width) / 2)
	  imageViewLeadingConstraint.constant = xOffset
	  imageViewTrailingConstraint.constant = xOffset

	  view.layoutIfNeeded()
	}
}

// Zooming
extension MainViewController {
	func updateMinZoomScaleForSize(_ size: CGSize) {
	  let widthScale = size.width / imageView.bounds.width
	  let heightScale = size.height / imageView.bounds.height
	  let minScale = min(widthScale, heightScale)

	  scrollView.minimumZoomScale = minScale
	  scrollView.zoomScale = minScale
	}

	override func viewWillLayoutSubviews() {
	  super.viewWillLayoutSubviews()
	  updateMinZoomScaleForSize(view.bounds.size)
	}
}
