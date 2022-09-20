//
//  SpaceWeatherView.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import SwiftUI
import os

struct SpaceWeatherView: View {

	struct Weather: Identifiable, Hashable {
		enum Tab: String, CaseIterable {
			case geophysicalAlert
			case apForecast

			func name() -> String {
				switch self {
				case .geophysicalAlert: return "Geophysical Alert"
				case .apForecast: return "AP & Flux Forecasts"
				}
			}

			@ViewBuilder
			func createView() -> some View {
				switch self {
				case .geophysicalAlert:
					SWPCFluxForecastView()
				case .apForecast:
					SWPCAPForecastView()
				}
			}
		}

		let name: String
		let id: Tab

		init(_ tab: Tab) {
			self.name = tab.name()
			id = tab
		}

		// User Defaults
		static let defaultsKey = "SpaceWeather.Weather"

		static func selectedWeather() -> Weather {
			guard let string = UserDefaults.standard.string(forKey: Weather.defaultsKey), let tab = Tab(rawValue: string) else {
				return Weather(Tab.geophysicalAlert)
			}
			return Weather(tab)
		}

		static func setSelectedWeather(_ weather: Weather) {
			UserDefaults.standard.set(weather.id.rawValue, forKey: Weather.defaultsKey)
		}
	}

	private let weathers = Weather.Tab.allCases.map { Weather($0) }

	@State private var selectedWeatherTab = Weather.selectedWeather().id

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack {
			Spacer()
			HStack {
				Spacer()
				Button("Done") {
					dismiss()
				}
			}
			Picker("Space Weather", selection: $selectedWeatherTab) {
				ForEach(weathers) { weather in
					Text(weather.name)
				}
			}
			.pickerStyle(.segmented)
			.onChange(of: selectedWeatherTab) { _ in
				Logger().info("Selected space weather '\(selectedWeatherTab.rawValue)'")
				Weather.setSelectedWeather(Weather(selectedWeatherTab))
			}
			selectedWeatherTab.createView()
			Spacer()
		}
		.padding(.horizontal)
		.preferredColorScheme(.dark)
	}
}

struct SpaceWeather_Previews: PreviewProvider {
	static var previews: some View {
		SpaceWeatherView()
	}
}
