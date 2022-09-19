//
//  SWPCAPForecast.swift
//  SolData
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import os

struct SWPCAPForecast: Codable {

	enum SWPCAPForecastError: Error {
		case badURL(message: String)
	}

	let issuedDate: Date

	let forecastAP: String
	let forecastFlux: String

	static func swpcDataURL() throws -> URL {
		guard let _swpcDataURL else {
			guard let url = URL(string: swpcDataURLTxt) else {
				throw SWPCAPForecastError.badURL(message: "Unexpectedly unable create URL from '\(swpcDataURLTxt)'")
			}
			Self._swpcDataURL = url
			return url
		}
		return _swpcDataURL
	}
	private static let swpcDataURLTxt = "https://services.swpc.noaa.gov/text/45-day-ap-forecast.txt"
	private static var _swpcDataURL: URL?
}
