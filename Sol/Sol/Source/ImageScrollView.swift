//
//  ImageScrollView.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-15.
//  Adapted from https://developer.apple.com/library/archive/samplecode/PhotoScroller
//

import UIKit

public class ImageScrollView: UIScrollView {

	var zoomView: UIImageView?
	var imageSize = CGSize.zero
	var pointToCenterAfterResize = CGPoint.zero
	var scaleToRestoreAfterResize: CGFloat = 0

	override public init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	func setup() {
		imageSize = CGSize.zero
		showsVerticalScrollIndicator = false
		showsHorizontalScrollIndicator = false
		bouncesZoom = true
		decelerationRate = UIScrollView.DecelerationRate.fast
		delegate = self
	}

	override public func layoutSubviews() {
		super.layoutSubviews()

		// center the zoom view as it becomes smaller than the size of the screen
		let boundsSize = bounds.size
		var frameToCenter = zoomView?.frame ?? CGRect.zero

		// center horizontally
		if frameToCenter.size.width < boundsSize.width {
			frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
		}
		else {
			frameToCenter.origin.x = 0
		}

		// center vertically
		if frameToCenter.size.height < boundsSize.height {
			frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
		}
		else {
			frameToCenter.origin.y = 0
		}

		zoomView?.frame = frameToCenter
	}

	override public var frame: CGRect {
		get {
			return super.frame
		}
		set {
			let sizeChanging = !CGSizeEqualToSize(newValue.size, frame.size)

			if sizeChanging {
				//prepareToResize()
			}

			super.frame = newValue

			if sizeChanging {
				//recoverFromResizing()
			}
		}
	}

	public func display(image: UIImage) {
		// clear the previous image
		zoomView?.removeFromSuperview()
		zoomView = nil

		// reset our zoomScale to 1.0 before doing any further calculations
		zoomScale = 1.0

		// make a new UIImageView for the new image
		let imageView = UIImageView(image: image)
		zoomView = imageView
		addSubview(imageView)

		configureForImage(size: image.size)
	}

	func configureForImage(size: CGSize) {
		imageSize = size
		contentSize = imageSize
		setMaxMinZoomScalesForCurrentBounds()
		zoomScale = minimumZoomScale
	}

	func setMaxMinZoomScalesForCurrentBounds() {
		let boundsSize = bounds.size

		// calculate min/max zoomscale
		let xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
		let yScale = boundsSize.height / imageSize.height;   // the scale needed to perfectly fit the image height-wise

		// fill width if the image and device are both portrait or both landscape; otherwise take smaller scale
		let imagePortrait = imageSize.height > imageSize.width
		let devicePortrait = boundsSize.height > boundsSize.width
		var minScale = imagePortrait == devicePortrait ? xScale : min(xScale, yScale)

		// on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
		// maximum zoom scale to 0.5.
		//		let maxScale = 1.0 / UIScreen.main.scale
		let maxScale = 3.0

		// don't let minScale exceed maxScale. (If the image is smaller than the screen, we don't want to force it to be zoomed.)
		if minScale > maxScale {
			minScale = maxScale
		}

		maximumZoomScale = maxScale
		minimumZoomScale = minScale
	}

	func prepareToResize() {
		let boundsCenter = CGPoint(x: bounds.midX, y: bounds.midY)
		pointToCenterAfterResize = convert(boundsCenter, to: zoomView)
		scaleToRestoreAfterResize = zoomScale

		// If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
		// allowable scale when the scale is restored.
		if  scaleToRestoreAfterResize <= minimumZoomScale + CGFloat(Float.ulpOfOne) {
			scaleToRestoreAfterResize = 0
		}
	}

	func recoverFromResizing() {
		setMaxMinZoomScalesForCurrentBounds()

		// Step 1: restore zoom scale, first making sure it is within the allowable range.
		let maxZoomScale = max(minimumZoomScale, scaleToRestoreAfterResize)
		zoomScale = min(maximumZoomScale, maxZoomScale)

		// Step 2: restore center point, first making sure it is within the allowable range.

		// 2a: convert our desired center point back to our own coordinate space
		let boundsCenter = convert(pointToCenterAfterResize, from: zoomView)

		// 2b: calculate the content offset that would yield that center point
		var offset = CGPoint(x: boundsCenter.x - bounds.size.width / 2, y: boundsCenter.y - bounds.size.height / 2)

		// 2c: restore offset, adjusted to be within the allowable range
		let maxOffset = maximumContentOffset()
		let minOffset = minimumContentOffset()

		var realMaxOffset = min(maxOffset.x, offset.x)
		offset.x = max(minOffset.x, realMaxOffset)

		realMaxOffset = min(maxOffset.y, offset.y)
		offset.y = max(minOffset.y, realMaxOffset)

		contentOffset = offset
	}

	func maximumContentOffset() -> CGPoint {
		return CGPoint(x: contentSize.width - bounds.size.width, y: contentSize.height - bounds.size.height)
	}

	func minimumContentOffset() -> CGPoint {
		return CGPoint.zero
	}
}

extension ImageScrollView: UIScrollViewDelegate {

	public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return zoomView
	}
}
