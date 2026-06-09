//
//  CarControl.swift
//  carkey
//
//  Created by Shilapi Chen on 9/29/25.
//

import SwiftUI
import MapKit

struct CarControlsView: View {
	@State private var isConnected = true
	@State private var isLocked = true
	@State var dataManager = DataManager.shared
	
	var body: some View {
		NavigationView {
			ZStack {
				// 更简洁的背景
				LinearGradient(
					gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.6)]),
					startPoint: .top,
					endPoint: .bottom
				).ignoresSafeArea()
				
				ScrollView {
					VStack(spacing: 20) {
						// 1. 顶部状态栏
						HeaderView(isConnected: $isConnected)
						
						// 2. 车辆视觉展示
						CarDisplayView().frame(
							height: 170
						)
						
						// 3. 核心控制区 (锁定/解锁)
						PrimaryControlsView(isLocked: $isLocked)
						
						// 4. 分组功能网格
						ActionGridView()
						
						CarLocationView()
						
						ApiStatusView(error: nil, lastUpdateTime: dataManager.appData.carData?.updateDate ?? "从未更新")
						
						Spacer()
					}
					.padding()
				}
				.refreshable {
					DataManager.shared.fetchAndLoadCarData()
				}
			}
			.navigationBarHidden(true)
		}
		.preferredColorScheme(.dark)
	}
}

enum StatusState {
	case ok
	case warning(issues: [String])
	case error(issues: [String])
	
	var iconName: String {
		switch self {
		case .ok: return "checkmark"
		case .warning: return "exclamationmark"
		case .error: return "xmark"
		}
	}
	
	var color: Color {
		switch self {
		case .ok: return .green
		case .warning: return .orange
		case .error: return .red
		}
	}
	
	var title: String {
		switch self {
		case .ok: return "车辆状态正常"
		case .warning: return "发现车辆异常"
		case .error: return "出现错误"
		}
	}
}

// MARK: - Subviews

struct CarDisplayView: View {
	@ObservedObject private var dataManager = DataManager.shared

	var body: some View {

		// 1. 使用 ZStack 作为根容器来实现层叠效果
		ZStack(alignment: .topLeading) {  // 默认对齐方式设为左上
//			// 文字层 (VStack)
//			VStack(alignment: .leading, spacing: -20) {
//				Text("ALL")
//				Text("GOOD")
//			}
//			// 将字体样式统一应用到 VStack，它会自动传递给内部的 Text
//			.font(
//				.system(size: 75, weight: .heavy, design: .default)
//			)
//			.frame(maxWidth: .infinity, alignment: .leading)  // 确保 VStack 在 ZStack 内靠左

			// 图片层 (Image)
			Image("EQ100")  // 确保你的项目中有名为 "EQ100" 的图片资源
				.resizable()
				.scaledToFit()
				.frame(height: 300)  // 给图片一个合适的尺寸
				.frame(
					maxWidth: .infinity,
					maxHeight: .infinity,
					alignment: .bottom
				)
			Color.clear.frame(height: 240)
		}
	}
}

struct InfoIndicator: View {
	let state: StatusState
	
	@State private var isShowingDetail = false // 控制详情弹窗的显示
	
	var body: some View {
		if #available(iOS 26.0, *) {
			Button(action: {
				isShowingDetail.toggle()
			}) {
				Image(systemName: state.iconName)
					.font(.system(size: 24, weight: .bold))
					.foregroundColor(state.color)
					.frame(width: 50, height: 50)
			}
			.glassEffect()
			.popover(isPresented: $isShowingDetail, attachmentAnchor: .point(.leading), arrowEdge: .trailing) {
				StatusDetailView(state: state)
					.presentationCompactAdaptation(.popover)
					.presentationBackgroundInteraction(.enabled)
					.presentationCornerRadius(100)
			}
		} else {
			Button(action: {
				isShowingDetail.toggle()
			}) {
				Image(systemName: state.iconName)
					.font(.system(size: 24, weight: .bold))
					.foregroundColor(state.color)
					.frame(width: 50, height: 50)
			}
			.shadow(radius: 5)
			.popover(isPresented: $isShowingDetail, arrowEdge: .top) {
				StatusDetailView(state: state)
					.presentationCompactAdaptation(.popover)
			}
		}
	}
}

struct HeaderView: View {
	@Binding var isConnected: Bool
	@State private var scanningTask: Task<Void, Error>?
	@ObservedObject var bluetoothManager = BluetoothManager.shared
	
	private func startScanningLoop() {
		// 防止重复创建任务
		guard scanningTask == nil else { return }
		
		loggerView.debug("ble scan task started")
		
		scanningTask = Task.detached {
			while !Task.isCancelled {
				BluetoothManager.shared.startScan()
				try await Task.sleep(for: .seconds(9))
			}
			loggerView.debug("ble scan task ended")
		}
	}
	
	private func stopScanningLoop() {
		loggerView.debug("ble scan task ending")
		scanningTask?.cancel()
		scanningTask = nil
	}
	
	private var indicatorColor: Color {
		switch bluetoothManager.state {
		case .disconnected, .unknown:
			return .red
		case .scanning:
			return .red
		case .authorizing:
			return .orange
		case .connected:
			return .green
		}
	}
	
	private var indicatorText: String {
		switch bluetoothManager.state {
		case .disconnected:
			return "未连接"
		case .scanning:
			return "扫描中"
		case .authorizing:
			return "连接中"
		case .connected:
			return "已连接"
		case .unknown:
			return "出现错误"
		}
	}
	var body: some View {
		HStack {
			VStack(alignment: .leading) {
				Text(DataManager.shared.appData.carData?.carInfo.carName ?? "☁️")
					.font(.system(size: 28, weight: .bold, design: .serif))
					.foregroundColor(.white)
				
				HStack(spacing: 8) {
					StateIndicator(indicatorColor: indicatorColor, indicatorText: indicatorText)
						.animation(.easeInOut, value: indicatorColor)
				}
				.onAppear(perform: startScanningLoop)
				.onDisappear(perform: stopScanningLoop)
			}.padding()
			Spacer()
			InfoIndicator(state: .ok)
				.padding()
		}.onTapGesture {
			loggerView.debug("force ble scan")
			bluetoothManager.startScan()
		}
	}
}

struct StateIndicator: View {
	let indicatorColor: Color
	let indicatorText: String
	
	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(indicatorColor) // 直接使用 color
				.frame(width: 8, height: 8)
				.shadow(color: indicatorColor, radius: 5)
			
			Text(indicatorText) // 直接使用 text
				.font(.subheadline)
				.foregroundColor(.gray)
		}
	}
}

struct PrimaryControlsView: View {
	@Binding var isLocked: Bool
	
	private var controlDisabled: Bool {
		switch BluetoothManager.shared.state {
		case .connected:
			return false
		default:
			return true
		}
	}
	
	private var shouldShowBlue: Bool {
		loggerView.debug("\(String(describing: !controlDisabled && isLocked))")
		return !controlDisabled && isLocked

	}
	
	var body: some View {
		if #available(iOS 26.0, *) {
			HStack(spacing: 20) {
				// 解锁按钮
				Button(action: {
					simpleHaptic(type: .success)
					withAnimation { isLocked = false }
					BluetoothManager.shared.CarUnlock()
				}) {
					Label("解锁", systemImage: "lock.open.fill")
						.font(.headline)
						.foregroundColor(.white)
						.frame(maxWidth: .infinity)
						.padding()
				}
				.disabled(controlDisabled)
				.glassEffect(.regular.tint(shouldShowBlue ? Color.clear : Color.blue).interactive())
				.scaleEffect(isLocked ? 0.95 : 1.0)
				
				// 锁定按钮
				Button(action: {
					simpleHaptic(type: .success)
					withAnimation { isLocked = true }
					BluetoothManager.shared.CarLock()
				}) {
					Label("锁定", systemImage: "lock.fill")
						.font(.headline)
						.foregroundColor(.white)
						.frame(maxWidth: .infinity)
						.padding()
				}
				.disabled(controlDisabled)
				.glassEffect(.regular.tint(shouldShowBlue ? Color.blue : Color.clear).interactive())
				.scaleEffect(shouldShowBlue ? 1.0 : 0.95)
			}
			.animation(.spring(), value: isLocked)
		} else {
			HStack(spacing: 20) {
				// 解锁按钮
				Button(action: {
					withAnimation { isLocked = false }
					simpleHaptic(type: .success)
					BluetoothManager.shared.CarUnlock()
				}) {
					Label("解锁", systemImage: "lock.open.fill")
						.font(.headline)
						.foregroundColor(.white)
						.frame(maxWidth: .infinity)
						.padding()
						.background(shouldShowBlue ? Color.clear : Color.blue)
						.cornerRadius(20)
				}
				.disabled(controlDisabled)
				.scaleEffect(shouldShowBlue ? 0.95 : 1.0)
				
				
				// 锁定按钮
				Button(action: {
					withAnimation { isLocked = true }
					simpleHaptic(type: .success)
					BluetoothManager.shared.CarLock()
				}) {
					Label("锁定", systemImage: "lock.fill")
						.font(.headline)
						.foregroundColor(.white)
						.frame(maxWidth: .infinity)
						.padding()
						.background(shouldShowBlue ? Color.blue : Color.clear)
						.cornerRadius(20)
				}
				.disabled(controlDisabled)
				.scaleEffect(shouldShowBlue ? 1.0 : 0.95)
			}
			.animation(.spring(), value: shouldShowBlue)
		}
	}
}

struct ActionGridView: View {
	// 分组操作
	let primaryActions: [(icon: String, label: String)] = [
		("power", "下电"),
		("headlight.low.beam.fill", "开灯"),
		("fanblades.fill", "空调"),
		("arrowshape.left.arrowshape.right.fill", "闪灯")
	]
	
	let secondaryActions: [(icon: String, label: String)] = [
		("car.side.rear.open.fill", "后备箱"),
		("car.side.front.open.fill", "前备箱")
	]
	
	var body: some View {
		if #available(iOS 26.0, *) {
			VStack(spacing: 15) {
				// 第一组操作
				ActionGroupView(title: "常用操作", actions: primaryActions)
				
				// 第二组操作
				ActionGroupView(title: "车门控制", actions: secondaryActions)
			}
			.padding()
			.glassEffect(in: .rect(cornerRadius: 20), )
		} else {
			VStack(spacing: 15) {
				// 第一组操作
				ActionGroupView(title: "常用操作", actions: primaryActions)
				
				// 第二组操作
				ActionGroupView(title: "车门控制", actions: secondaryActions)
			}
			.padding()
			.background(Color.gray.opacity(0.15))
			.cornerRadius(20)
		}
	}
}

struct ActionGroupView: View {
	let title: String
	let actions: [(icon: String, label: String)]
	
	private let gridColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
	
	var body: some View {
		VStack(alignment: .leading) {
			Text(title)
				.font(.caption)
				.foregroundColor(.gray)
				.padding(.leading, 10)
			
			LazyVGrid(columns: gridColumns, spacing: 15) {
				ForEach(actions, id: \.label) { action in
					Button(action: {
						// 🚗 根据 action.label 执行相应指令
					}) {
						VStack(spacing: 8) {
							Image(systemName: action.icon)
								.font(.title2)
							Text(action.label)
								.font(.caption)
						}
						.frame(maxWidth: .infinity, minHeight: 60)
						.foregroundColor(.white)
					}
				}
			}
		}
	}
}

extension CLLocationCoordinate2D {
	static let carLocation: Self = .init(
		latitude: 40.730610,
		longitude: -73.935242
	)
}

struct CarLocationView: View {
	var body: some View {
		
		if #available(iOS 26.0, *) {
			VStack(alignment: .leading) {
				Text("车辆位置")
					.font(.caption)
					.foregroundColor(.gray)
					.padding(.leading, 10)
				Map(bounds: MapCameraBounds(minimumDistance: 200)) {
					Annotation("车辆位置", coordinate: GPSTool.gps84_To_Gcj02(lon: Double(DataManager.shared.appData.carData?.carStatus.longitude ?? "0") ?? 00.00, lat: Double(DataManager.shared.appData.carData?.carStatus.latitude ?? "0") ?? 00.00) ?? CLLocationCoordinate2D(latitude: 31, longitude: 128)){
						Image(systemName: "car.fill")
							.foregroundStyle(.white)
							.padding()
							.background(.thickMaterial)
							.clipShape(Circle())
							.imageScale(.small)
					}.tint(.gray)
				}
				.mapControlVisibility(.visible)
				.frame(minHeight: 200)
				.cornerRadius(10)
				.padding(.leading, 5)
				.padding(.trailing, 5)
				.padding(.bottom, 5)
			}
			.padding()
			.glassEffect(in: .rect(cornerRadius: 20))
		} else {
			VStack(spacing: 15) {
				Text("车辆位置")
					.font(.caption)
					.foregroundColor(.gray)
					.padding(.leading, 10)
			}
			.padding()
			.background(Color.gray.opacity(0.15))
			.cornerRadius(20)
		}
	}
}

// MARK: - Preview
struct CarControlsView_Previews: PreviewProvider {
	static var previews: some View {
		CarControlsView()
	}
}
