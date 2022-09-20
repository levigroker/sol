//
//  SWPCAPForecastView.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import SwiftUI
import Charts
import os
import SolData

struct SWPCAPForecastView: View {

	private let issuedDateFormatter: DateFormatter
	private let chartDateFormatter: DateFormatter

	init() {
		issuedDateFormatter = DateFormatter()
		issuedDateFormatter.dateStyle = .medium
		issuedDateFormatter.timeStyle = .none

		chartDateFormatter = DateFormatter()
		chartDateFormatter.dateStyle = .short
		chartDateFormatter.timeStyle = .none
	}

	struct ChartData: Identifiable {
		let id: TimeInterval
		let date: String
		let value: Int
		let type: String

		init(forecastData: SWPCAPForecast.ForecastData, type: String, dateFormatter: DateFormatter) {
			id = forecastData.id
			date = dateFormatter.string(from: forecastData.date)
			value = forecastData.value
			self.type = type
		}
	}
	@State private var chartData = [ChartData]()

	@State private var apForecast: SWPCAPForecast?

	func update() async {
		do {
			let forecast = try await SWPCDataManager.apForecast()
			apForecast = forecast

			chartData = [ChartData]()
			let apChartData = forecast.forecastAP.map { forcastData in
				ChartData(forecastData: forcastData, type: "AP", dateFormatter: chartDateFormatter)
			}
			chartData.append(contentsOf: apChartData)

			let fluxChartData = forecast.forecastFlux.map { forcastData in
				ChartData(forecastData: forcastData, type: "f10.7cm Flux", dateFormatter: chartDateFormatter)
			}
			chartData.append(contentsOf: fluxChartData)
		}
		catch {
			Logger().error("Unable to update data. Error: \(error)")
		}
	}

	var body: some View {
		List {
			if let apForecast {
				Section("Issued") {
					Text(issuedDateFormatter.string(from: apForecast.issuedDate))
				}
				Section("45 Day Forecast") {
					Chart {
						ForEach(chartData) {
							LineMark(
								x: .value("Date", $0.date),
								y: .value("Value", $0.value)
							)
							.foregroundStyle(by: .value("Type", "Series \($0.type)"))
						}
					}
					.chartXAxis {
						AxisMarks(position: .bottom, values: .automatic) { value in
							AxisGridLine(centered: true, stroke: StrokeStyle(dash: [1, 2]))
							AxisTick(centered: true, stroke: StrokeStyle(dash: [1, 2]))
							AxisValueLabel(collisionResolution: .greedy, orientation: .verticalReversed)
						}
					}
					.frame(height: 250)
				}
				Section("Credit") {
					Text(apForecast.prepared).font(.caption)
				}
			}
			else {
				Text("No Data")
			}
		}
		.task {
			await update()
		}
		.refreshable {
			await update()
		}
		.preferredColorScheme(.dark)
	}
}

struct SWPCAPForecastView_Previews: PreviewProvider {
	static var previews: some View {
		SWPCAPForecastView()
	}
}
