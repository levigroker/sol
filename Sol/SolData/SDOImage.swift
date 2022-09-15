//
//  SDOImage.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-14.
//

import UIKit

public struct SDOImage: Comparable {
	let key: SDOImageKey
	let day: Date
	let remoteURL: URL
	var state: State

	init(key: SDOImageKey, day: Date, remoteURL: URL, state: State = State.uninitiated) {
		self.key = key
		self.day = day
		self.remoteURL = remoteURL
		self.state = state
	}

	enum State {
		case uninitiated
		// Still loading
		case awaiting(Task<UIImage, Error>)
		// Available currently
		case cached(UIImage)
	}

	// Equatable and Comparable can solely use `key` because we know `key` to be structured, like  "20220909_034253_1024_1700pfss.jpg", which sorts by date properly
	// ("20220909_034253" being the date-timestamp)
	public static func == (lhs: SDOImage, rhs: SDOImage) -> Bool {
		lhs.key == rhs.key
	}
	public static func < (lhs: SDOImage, rhs: SDOImage) -> Bool {
		lhs.key < rhs.key
	}
}
typealias SDOImageKey = String
