//
//  SolImageScrollView.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-15.
//

import UIKit

public class SolImageScrollView: ImageScrollView {

	override func setup() {
		super.setup()

		// We don't want the scroll view to "bounce" when a drag reaches the content end because we will use this event to "spin" the images
		// Ideally we could enable bounces for vertical edges and disable horizontal bouncing
		bounces = false

		// Configure a single touch pan gesture recognizer to allow us to track pan gestures
		let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
		panGestureRecognizer.maximumNumberOfTouches = 1
		panGestureRecognizer.delegate = self
		addGestureRecognizer(panGestureRecognizer)
	}
}

// MARK: - Actions
extension SolImageScrollView {

	@objc
	private func didPan(_ sender: UIPanGestureRecognizer) {
		let velocity = sender.velocity(in: self)
		//contentOffset '(316.0, 0.0)' contentSize '(707.7255506179761, 707.7255506179761)' bounds.size '(393.0, 852.0)
		let draggingLeft = velocity.x < 0.0
		if draggingLeft && contentOffset.x >= contentSize.width - bounds.size.width {
			print("pulling to the left")
		}
		else if !draggingLeft && contentOffset.x <= 0 {
			print("pulling to the right")
		}
		print("contentOffset '\(contentOffset)' contentSize '\(contentSize)' bounds.size '\(bounds.size)' velocity '\(velocity)'")
	}
}

extension SolImageScrollView: UIGestureRecognizerDelegate {

	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		// We want to allow the scroll view's gesture recognizers to operate in tandem with our pan gesture recognizer
		return true
	}
}
