//
//  SolImageScrollView.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-15.
//

import UIKit
import os

public protocol SolImageScrollViewDelegate: AnyObject {
	func imageRequested(direction: SolImageScrollView.TimeDirection)
	func spinRequested(direction: SolImageScrollView.TimeDirection, velocity: Float)
	func spinStop()
}

public class SolImageScrollView: ImageScrollView {

	public enum TimeDirection: String {
		case older
		case newer
	}

	public weak var solImageScrollViewDelegate: SolImageScrollViewDelegate?

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

	// The last x position considered as a "move"
	private var panGestureLastMoveX = CGFloat.zero
	// The last event's x position
	private var panGestureLastX = CGFloat.zero
	private var panGestureLastDeltaX = CGFloat.zero

	// The increment needed for a pan to be considered a "move"
	static let panGestureDeltaThreshold: CGFloat = 0.5
	// The threshold to consider a spin requested
	static let spinThreshold: CGFloat = 1.0
}

// MARK: - Actions
extension SolImageScrollView {

	@objc
	private func didPan(_ sender: UIPanGestureRecognizer) {
		let velocityX = sender.velocity(in: self).x
		let translationX = sender.translation(in: self).x

		// Allow panning of the scroll view to take place normally unless it's up against either side,
		// in which case we will interpret that as a desire for older/newer content
		if contentOffset.x <= 0 || contentOffset.x >= floor(contentSize.width) - bounds.size.width {
			// Stop any active automated spinning now that the user is in control
			solImageScrollViewDelegate?.spinStop()
			// Only consider the pan "moved" if it has moved accross a threshold boundary
			// NOTE: This is not a delta between pan events, but an event describing a transition accross a threshold value, which is why we only update panGestureLastX on a "move"
			let moved = abs(translationX - panGestureLastMoveX) >= Self.panGestureDeltaThreshold
			if moved {
				panGestureLastMoveX = translationX
			}
			let direction: TimeDirection = velocityX > 0 ? .newer : .older
			switch sender.state {
			case .changed:
				panGestureLastDeltaX = translationX - panGestureLastX
				panGestureLastX = translationX
				if moved {
					solImageScrollViewDelegate?.imageRequested(direction: direction)
				}
			case .ended:
				let lastDelta = abs(panGestureLastDeltaX)
				if lastDelta > Self.spinThreshold {
					solImageScrollViewDelegate?.spinRequested(direction: direction, velocity: Float(lastDelta))
				}
			default:
				break // Do nothing
			}
		}
	}
}

extension SolImageScrollView: UIGestureRecognizerDelegate {

	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		// We want to allow the scroll view's gesture recognizers to operate in tandem with our pan gesture recognizer
		return true
	}
}
