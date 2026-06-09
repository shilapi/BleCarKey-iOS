//
//  ViewMap.swift
//  carkey
//
//  Created by Shilapi Chen on 9/29/25.
//

import SwiftUI
import MapKit

// 为了代码的整洁和可重用性，我们首先定义一个结构体来存放位置信息
struct Location: Identifiable {
	let id = UUID()
	let name: String
	let coordinate: CLLocationCoordinate2D
}

struct MapContentView: View {
	// 设置地图的初始相机位置
	@State private var position: MapCameraPosition = .automatic
	
	// 创建一个包含我们想要聚焦的位置的数组
	let locations = [
		Location(name: "Apple Park", coordinate: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090))
	]
	
	var body: some View {
		Map(position: $position) {
			// 遍历位置数组并在地图上添加标记
			ForEach(locations) { location in
				Marker(location.name, coordinate: location.coordinate)
			}
		}
		.onAppear {
			// 当视图出现时，将地图的相机位置设置为我们指定的位置
			// .region() 适用于显示一个区域，如果只有一个点，可以直接设置中心
			position = .region(MKCoordinateRegion(
				center: locations[0].coordinate,
				span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
			))
		}
		.edgesIgnoringSafeArea(.all)
	}
}

#Preview {
	MapContentView()
}
