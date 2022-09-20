//
//  MainViewController.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-10.
//

import UIKit
import SwiftUI
import os

enum Sol: Error, CustomStringConvertible {
	case error(message: String)

	var description: String {
		switch self {
		case .error(let message):
			return "error: \(message)"
		}
	}
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
		// Start off with the content hidden
		solImageScrollView.alpha = 0
		activityIndicatorView.startAnimating()

		// Kick off a task to display the latest actual image
		Task {
			do {
				let image = try await solActor.updateSDOImages()
				solImageScrollView.display(image: image)
			}
			catch {
				Logger().error("Error attempting to update SDO images: \(error)")
			}
			// Animate the content into visibility
			UIView.animate(withDuration: 0.25, delay: 0) {
				self.solImageScrollView.alpha = 1
			}
			activityIndicatorView.stopAnimating()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}

	@IBSegueAction
	func presentSettingsView(_ coder: NSCoder) -> UIViewController? {
		return UIHostingController(coder: coder, rootView: SettingsView())
	}

	@IBSegueAction
	func presentSpaceWeatherView(_ coder: NSCoder) -> UIViewController? {
		return UIHostingController(coder: coder, rootView: SpaceWeatherView())
	}

	private let solActor = SolActor()
	private var spinTask: Task<Void, Error>?
}

extension MainViewController: SolImageScrollViewDelegate {
	func imageRequested(direction: SolImageScrollView.TimeDirection) {
		Task {
			Logger().info("imageRequested \(direction.rawValue)")
			let image: UIImage
			do {
				switch direction {
				case .older:
					image = try await solActor.nextOlderImage()
				case .newer:
					image = try await solActor.nextNewerImage()
				}
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

	func spinRequested(direction: SolImageScrollView.TimeDirection, velocity: Float) {
		Logger().info("spinRequested direction '\(direction.rawValue)' velocity: '\(velocity)'")
		spinTask?.cancel()
		spinTask = Task {
			var run = true
			while run {
				try Task.checkCancellation()

				let image: UIImage
				do {
					switch direction {
					case .older:
						image = try await solActor.nextOlderImage()
					case .newer:
						image = try await solActor.nextNewerImage()
					}
					try Task.checkCancellation()
					solImageScrollView.display(image: image)
					activityIndicatorView.stopAnimating()
					try await Task.sleep(nanoseconds: 100_000_000 /* 0.1 second */)
				}
				catch {
					Logger().error("spinRequested \(direction.rawValue) encountered error: \(error)")
					switch error {
					case SolActorError.inProgress:
						activityIndicatorView.startAnimating()
						try await Task.sleep(nanoseconds: 1_100_000_000 /* 1.0 second */)
					default:
						run = false
					}
				}
			}
		}
	}

	func spinStop() {
		spinTask?.cancel()
		spinTask = nil
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
