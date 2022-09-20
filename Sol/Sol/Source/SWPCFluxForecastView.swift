//
//  SWPCFluxForecastView.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-18.
//

import Foundation
import SwiftUI
import os
import SolData

struct SWPCFluxForecastView: View {

	private let issuedFormatter: DateFormatter

	init() {
		issuedFormatter = DateFormatter()
		issuedFormatter.dateStyle = .medium
		issuedFormatter.timeStyle = .none
	}

	@State private var geoAlert: SWPCGeoAlert?

	var body: some View {
		List {
			if let geoAlert {
				Section("Issued") {
					Text(issuedFormatter.string(from: geoAlert.issuedDate))
				}
				Section("Alert") {
					Text(geoAlert.body)
				}
				Section("Credit") {
					Text(geoAlert.prepared).font(.caption)
				}
			}
			else {
				Text("No Data")
			}
		}
		.task {
			geoAlert = try? await SWPCDataManager.geoAlert()
		}
		.refreshable {
			geoAlert = try? await SWPCDataManager.geoAlert()
		}
		.preferredColorScheme(.dark)
	}
}

struct SWPCFluxForecastView_Previews: PreviewProvider {
	static var previews: some View {
		SWPCFluxForecastView()
	}
}
