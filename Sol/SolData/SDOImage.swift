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
	let imageSet: ImageSet
	let resolution: Resolution
	let pfss: Bool
	let remoteURL: URL
	var state: State

	init(key: SDOImageKey, day: Date, imageSet: ImageSet, resolution: Resolution, pfss: Bool, remoteURL: URL, state: State = State.uninitiated) {
		self.key = key
		self.day = day
		self.imageSet = imageSet
		self.resolution = resolution
		self.pfss = pfss
		self.remoteURL = remoteURL
		self.state = state
	}

	// Unless otherwise stated, ImageSets:
	//  - do not contain 3072 resolution
	//  - do contain pfss variants
	public enum ImageSet: String, CaseIterable {
		case i0094 = "0094" // no 256 resolution
		case i0131 = "0131"
		case i0171 = "0171"
		case i0193 = "0193"
		case i0211 = "0211"
		case i0304 = "0304"
		case i0335 = "0335"
		case i1600 = "1600"
		case i1700 = "1700"
		case i4500 = "4500" // no pfss variant
		case iHMI171 = "HMI171"
		case iHMIB = "HMIB"
		case iHMII = "HMII" // no pfss variant
		case iHMID = "HMID" // no pfss variant
		case iHMIBC = "HMIBC" // no pfss variant, contains 3072 resolution
		case iHMIIF = "HMIIF" // no pfss variant, contains 3072 resolution
		case iHMIIC = "HMIIC" // no pfss variant, contains 3072 resolution
		// Composite of 0094, 0335, and 0193
		case i094335193 = "094335193"
		// Composite of 0304, 0211, and 0171
		case i304211171 = "304211171"
		// Composite of 0211, 0193, and 0171
		case i211193171 = "211193171" // contains 3072 resolution
		// Composite of 0211, 0193, and 0171, with dimmed corona
		case i211193171n = "211193171n" // no pfss variant, contains 3072 resolution
		// Appears to be the same as 211193171
		case i211193171rg = "211193171rg" // no pfss variant, contains 3072 resolution

		public func name() -> String {
			switch self {
			case .i0094: return "AIA 94 Å"
			case .i0131: return "AIA 131 Å"
			case .i0171: return "AIA 171 Å"
			case .i0193: return "AIA 193 Å"
			case .i0211: return "AIA 221 Å"
			case .i0304: return "AIA 304 Å"
			case .i0335: return "AIA 335 Å"
			case .i1600: return "AIA 1600 Å"
			case .i1700: return "AIA 1700 Å"
			case .i4500: return "AIA 4500 Å"
			case .iHMI171: return "AIA 171 Å & HMIB"
			case .iHMIB: return "HMI Magnetogram"
			case .iHMII: return "HMI Intensitygram"
			case .iHMID: return "HMI Dopplergram"
			case .iHMIBC: return "HMI Colorized Magnetogram"
			case .iHMIIF: return "HMI Intensitygram - Flattened"
			case .iHMIIC: return "HMI Intensitygram - Colored"
			case .i094335193: return "AIA 94 Å, 335 Å, 193 Å"
			case .i304211171: return "AIA 304 Å, 211 Å, 171 Å"
			case .i211193171: return "AIA 211 Å, 193 Å, 171 Å"
			case .i211193171n: return "AIA 211 Å, 193 Å, 171 Å n"
			case .i211193171rg: return "AIA 211 Å, 193 Å, 171 Å rg"
			}
		}
	}

	public enum Resolution: String, CaseIterable {
		case x256 = "256"
		case x512 = "512"
		case x1024 = "1024"
		case x2048 = "2048"
		case x3072 = "3072"
		case x4096 = "4096"
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
