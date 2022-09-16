//
//  SettingsView.swift
//  Sol
//
//  Created by Levi Brown on 2022-09-13.
//

import SwiftUI
import SolData
import os

struct SettingsView: View {

	// Image Sets
	struct SDOImageSet: Identifiable, Hashable {
		let name: String
		let image: UIImage
		let id: SDOImage.ImageSet

		init(_ imageSet: SDOImage.ImageSet) {
			self.name = imageSet.name()
			if let image = UIImage(named: imageSet.rawValue) {
				self.image = image
			}
			else {
				self.image = UIImage()
				Logger().error("Unable to find image asset '\(imageSet.rawValue)'.")
			}
			id = imageSet
		}
	}

	private let imageSets = SDOImage.ImageSet.allCases.map { SDOImageSet($0) }

	@AppStorage(Settings.sdoImageSet.rawValue)
	private var settingImageSet = SDODataManager.ImageSet.i0171

	// Resolutions
	struct SDOResolution: Identifiable, Hashable {
		let name: String
		let id: SDOImage.Resolution

		init(_ resolution: SDOImage.Resolution) {
			self.name = "\(resolution.rawValue)"
			id = resolution
		}
	}

	private let resolutions = SDOImage.Resolution.allCases.map { SDOResolution($0) }

	@AppStorage(Settings.sdoResolution.rawValue)
	private var settingResolution = SDODataManager.Resolution.x1024
	@State private var selectedResolution = SDODataManager.Resolution.x1024

	// PFSS
	@AppStorage(Settings.sdoPFSS.rawValue)
	private var settingPFSS = true
	@State private var selectedPFSS = false

	//TODO: It would be a nicer user experience if channel selection would disable resolutions which are not available.

	var body: some View {
		NavigationView {
			List() {
				Section(header: Text("Resolution"), footer: Text("Smaller resolutions are faster to load and take less space.")) {
					Picker("Resolution", selection: $selectedResolution) {
						ForEach(resolutions) { resolution in
							Text(resolution.name)
						}
					}
				}
				.pickerStyle(.segmented)
				.onChange(of: selectedResolution) { _ in
					settingResolution = selectedResolution
					Settings.postChangeNotification()
				}
				Section(header: Text("Flux Lines"), footer: Text("Flux line images are not available for all channels.")) {
					Toggle("PFSS", isOn: $selectedPFSS)
						.onChange(of: selectedPFSS) { _ in
							settingPFSS = selectedPFSS
							Settings.postChangeNotification()
						}
				}
				Section(header: Text("Channels")) {
					ForEach(imageSets) { imageSet in
						HStack {
							Image(uiImage: imageSet.image)
								.resizable()
								.frame(width: 64, height: 64, alignment: .center)
							Text(imageSet.name)
							Spacer()
							Image(systemName: settingImageSet == imageSet.id ? "checkmark.circle" : "circle").font(.title)
						}
						.onTapGesture {
							settingImageSet = imageSet.id
							Settings.postChangeNotification()
						}
					}
				}
			}
			.navigationTitle("Settings")
		}
		.preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
	}
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
	}
}
