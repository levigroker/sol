//
//  MainViewController.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-10.
//

import UIKit
import SwiftUI
import os

enum Sol: Error {
	case error(message: String)
}

@MainActor
class MainViewController: UIViewController {

	@IBOutlet private var activityIndicatorView: UIActivityIndicatorView!
	@IBOutlet private var solImageScrollView: SolImageScrollView!

	deinit {
		NotificationCenter.default.removeObserver(self, name: Settings.notificationName, object: nil)
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
		solImageScrollView.solImageScrollViewDelegate = self

		// Kick off a task to display the latest actual image
		Task {
			if let image = try? await solActor.updateSDOImages() {
				solImageScrollView.display(image: image)
			}
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}

	@IBSegueAction
	func presentSettingsView(_ coder: NSCoder) -> UIViewController? {
		return UIHostingController(coder: coder, rootView: SettingsView())
	}

	private let solActor = SolActor()
}

extension MainViewController: SolImageScrollViewDelegate {
	func imageRequested(direction: SolImageScrollView.TimeDirection) {
		switch direction {
		case .older:
			Logger().info("leadingImageRequested")
			Task {
				do {
					let image = try await solActor.nextOlderImage()
					solImageScrollView.display(image: image)
					activityIndicatorView.stopAnimating()
				}
				catch {
					Logger().error("imageRequested \(direction.rawValue) encountered error: \(error)")
					switch error {
					case SolActorError.inProgress:
						activityIndicatorView.startAnimating()
					default:
						break
					}
				}
			}
		case .newer:
			Logger().info("trailingImageRequested")
			Task {
				do {
					let image = try await solActor.nextNewerImage()
					solImageScrollView.display(image: image)
					activityIndicatorView.stopAnimating()
				}
				catch {
					Logger().error("imageRequested \(direction.rawValue) encountered error: \(error)")
					switch error {
					case SolActorError.inProgress:
						activityIndicatorView.startAnimating()
					default:
						break
					}
				}
			}
		}
	}

	func spinRequested(direction: SolImageScrollView.TimeDirection, velocity: Float) {
		Logger().info("spinRequested direction '\(direction.rawValue)' velocity: '\(velocity)'")
	}
}

@objc
extension MainViewController {
	func settingsChanged() {
		Task {
			do {
				let image = try await self.solActor.updateSDOImages()
				solImageScrollView.display(image: image)
			}
			catch {
				//TODO: Present user with error and options to proceed
				Logger().error("\(error)")
			}
		}
	}
}
