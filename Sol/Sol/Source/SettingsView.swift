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

	@State private var selectedImageSet = Settings.sdoImageSet()

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

	@State private var selectedResolution = Settings.sdoResolution()

	// PFSS
	@State private var selectedPFSS = Settings.sdoPFSS()

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
					Settings.setSDOResolution(resolution: selectedResolution)
				}
				Section(header: Text("Flux Lines"), footer: Text("Flux line images are not available for all channels.")) {
					Toggle("PFSS", isOn: $selectedPFSS)
						.onChange(of: selectedPFSS) { _ in
							Settings.setSDOPFSS(pfss: selectedPFSS)
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
							Image(systemName: selectedImageSet == imageSet.id ? "checkmark.circle" : "circle").font(.title)
						}
						.onTapGesture {
							Settings.setSDOImageSet(imageSet: imageSet.id)
							selectedImageSet = imageSet.id
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
