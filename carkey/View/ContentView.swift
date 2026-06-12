import Foundation
import LogView
import OSLog
import SwiftUI

let loggerView = Logger(
	subsystem: "com.sleepyshark.carkey",
	category: "view"
)

// MARK：- haptic helper

func simpleHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
	let generator = UINotificationFeedbackGenerator()
	generator.notificationOccurred(type)
}

func simpleImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
	let generator = UIImpactFeedbackGenerator(style: style)
	generator.impactOccurred()
}

// MARK: - Reusable UI Components

/// 用于显示“左边粗体标签，右边值”的通用行视图
struct InfoRowView: View {
	let label: String
	let value: String

	var body: some View {
		HStack {
			Text(label)
				.bold()
			Spacer()
			Text(value)
				.foregroundColor(.secondary)
		}
	}
}

struct ApiStatusView: View {
	let error: Error?
	let lastUpdateTime: String?

	var body: some View {
		if #available(iOS 26.0, *) {
			Text(statusText)
				.font(.footnote)  // 使用小号字体
				.foregroundColor(.secondary)
				.frame(minWidth: statusText.size(withAttributes: [.font: UIFont.systemFont(ofSize: 14)]).width + 20, minHeight: 40)
				.glassEffect()
		} else {
			Text(statusText)
				.font(.footnote)  // 使用小号字体
				.foregroundColor(.secondary)
		}
	}

	private var statusText: String {
		if error != nil {
			return "API获取失败"
		}
		return "数据更新日期: \(lastUpdateTime ?? "从未刷新")"
	}
}

// MARK: - Tab Views

// --- 车辆信息 Tab ---

// --- 蓝牙密钥二级页面 ---
struct CarKeyInfoView: View {
	@ObservedObject private var dataManager = DataManager.shared

	var body: some View {
		List {
			Section(header: Text("蓝牙密钥详情")) {
				if let keyData = dataManager.appData.carKeyData {
					InfoRowView(
						label: "密钥ID",
						value: keyData.keyId.masked(percentage: 0.7)
					)
					InfoRowView(label: "密钥类型", value: keyData.keyType)
					InfoRowView(
						label: "VIN码",
						value: keyData.vin.masked(percentage: 0.7)
					)
					InfoRowView(
						label: "用户ID",
						value: keyData.userId.masked(percentage: 0.7)
					)
					InfoRowView(
						label: "蓝牙MAC",
						value: keyData.bleMac.masked(percentage: 0.7)
					)
					InfoRowView(label: "失效时间", value: keyData.endTime)
					InfoRowView(label: "采集时间", value: keyData.collectTime)
				} else {
					Text("请下拉刷新或从Debug页注入数据")
				}
			}
		}
		.navigationTitle("密钥详情")
		.refreshable {
			// 在这里调用您的刷新逻辑
			loggerView.debug("refetching car key data")
			dataManager.fetchAndLoadKeyData()
		}
	}
}

// MARK: - 显示帮助用，记得分离出去

extension String {

	/// 对字符串按照百分比进行打码
	/// - Parameters:
	///   - percentage: 需要打码的百分比，取值范围 0.0 到 1.0。
	///   - maskCharacter: 用于打码的字符，默认为 '*'。
	/// - Returns: 打码后的新字符串。
	func masked(percentage: Double, maskCharacter: Character = "*") -> String {
		// 1. 保证百分比在 0.0 和 1.0 之间
		let clampedPercentage = max(0.0, min(1.0, percentage))

		// 2. 计算需要打码的字符数量
		let totalCount = self.count
		let maskCount = Int(Double(totalCount) * clampedPercentage)

		// 如果不需要打码，直接返回原字符串
		guard maskCount > 0 else {
			return self
		}

		// 如果全部需要打码，返回一串打码字符
		guard maskCount < totalCount else {
			return String(repeating: maskCharacter, count: totalCount)
		}

		// 3. 计算前后保留的明文数量
		let clearCount = totalCount - maskCount
		let prefixCount = clearCount / 2
		let suffixCount = clearCount - prefixCount  // 这样可以处理奇数明文的情况

		// 4. 拼接字符串
		let prefix = self.prefix(prefixCount)
		let suffix = self.suffix(suffixCount)
		let maskedPart = String(repeating: maskCharacter, count: maskCount)

		return "\(prefix)\(maskedPart)\(suffix)"
	}
}

// --- 用户信息 Tab ---
struct UserInfoView: View {
	@ObservedObject private var dataManager = DataManager.shared
	
	@State private var accesstoken_input = ""
	@State private var userid_input = ""
	@State private var secret_input = ""
	@State private var name_input = ""
	
	var canContinue:Bool {
		if accesstoken_input.isEmpty { return false }
		if userid_input.isEmpty { return false }
		if secret_input.isEmpty { return false }
		if name_input.isEmpty { return false }
		return true
	}

	var body: some View {
		NavigationView {
			VStack(alignment:.leading, spacing: 45) {
					if let user = dataManager.appData.userData {
						List{
							InfoRowView(label: "用户名", value: user.userName)
							InfoRowView(
								label: "用户ID (手机)",
								value: user.userID.masked(percentage: 0.7)
							)
							InfoRowView(
								label: "Access Token",
								value: String(user.accessToken.prefix(10) + "...")
									.masked(percentage: 0.7)
							)
							Button{
								DataManager.shared.logout()
							} label: {
								Text("Logout")
							}.foregroundStyle(.red)
						}
					} else {
						VStack(alignment: .leading, spacing: 15) {
							Text("请获取token登录")
								.font(.callout)
								.foregroundColor(.secondary)
								.padding(.vertical, 10)
							TextField("昵称", text: $name_input)
								.textFieldStyle(.plain)
								.padding(.vertical, 18)
								.padding(.horizontal, 10)
								.background(Color(.secondarySystemBackground))
								.cornerRadius(20)
								.autocapitalization(.none)
								.disableAutocorrection(true)
							
							TextField("AccessToken", text: $accesstoken_input)
								.textFieldStyle(.plain)
								.padding(.vertical, 18)
								.padding(.horizontal, 10)
								.background(Color(.secondarySystemBackground))
								.cornerRadius(20)
								.autocapitalization(.none)
								.disableAutocorrection(true)
							
							TextField("ClientSecret", text: $secret_input)
								.textFieldStyle(.plain)
								.padding(.vertical, 18)
								.padding(.horizontal, 10)
								.background(Color(.secondarySystemBackground))
								.cornerRadius(20)
								.autocapitalization(.none)
								.disableAutocorrection(true)

							TextField("手机号码", text: $userid_input)
								.textFieldStyle(.plain)
								.padding(.vertical, 18)
								.padding(.horizontal, 10)
								.background(Color(.secondarySystemBackground))
								.cornerRadius(20)
								.autocapitalization(.none)
								.disableAutocorrection(true)
							
							Spacer()
							
							Button(action: {
								DataManager.shared.login(
									userName: name_input,
									accessToken: accesstoken_input,
									clientSecret: secret_input,
									userID: userid_input
								)
							}) {
								Text("登录")
									.font(.headline)
									.foregroundColor(.white)
									.frame(maxWidth: .infinity)
									.padding(.vertical, 18)
									.background(canContinue ? .blue : Color(.systemGray3))
									.cornerRadius(20)
							}.padding(.bottom, 20)
							

						}.padding(.horizontal)
					}
			}
			.navigationTitle("用户信息")
		}
	}
}

// --- Debug Tab (仅在 DEBUG 模式下编译) ---
#if DEBUG
	struct DebugView: View {
		@State var logViewPresented: Bool = false
		@ObservedObject private var bt = BluetoothManager.shared

		var body: some View {
			NavigationView {
				List {
					Section("数据注入") {
						Button(action: {
							DataManager.shared.injectMockData()
						}) {
							Text("注入所有模拟数据")
							//.frame(maxWidth: .infinity, alignment: .center)
						}
						//.buttonStyle(.borderless)

						Button(action: {
							DataManager.shared.clearAllData()
						}) {
							Text("清除所有数据")
							//.frame(maxWidth: .infinity, alignment: .center)
						}
						//.buttonStyle(.borderless)
					}

					Section("Live log") {
						Button(
							"Show log",
							action: {
								logViewPresented = true
							}
						)
						Text("logs")
							.onAppear {
								// Setup predicate to get only my application log, otherwise you get tons of apple system logs
								LogView.predicate = .subystemIn(
									["com.sleepyshark.carkey"],
									orNil: false
								)
							}
							.sheet(
								isPresented: $logViewPresented,
								content: {
									NavigationView {
										if #available(iOS 15.0, *) {
											LogView()
										} else {
											Text(
												"Run your app on iOS 15 and upper"
											)
										}
									}
								}
							)
					}

					Section(header: Text("蓝牙")) {
						Text("当前状态： \(String(describing: bt.state))")

						Section(
							header: Text(
								"发现的设备 (\(bt.avaliblePeripherals.count))"
							)
						) {
							if bt.avaliblePeripherals.isEmpty {
								Text("请开始扫描来发现附近的设备...")
									.foregroundColor(.gray)
									.padding()
							} else {
								ForEach(bt.avaliblePeripherals) { device in
									Text(device.id)
								}
							}
						}

						Button(
							"开始扫描",
							action: {
								BluetoothManager.shared.startScan()
							}
						)
					}
				}
				.navigationTitle("DEBUG")
			}
		}
	}

#endif

// MARK: - Main TabView
/// App 的主 Tab 视图
struct MainTabView: View {

	// 检查是否正在为 SwiftUI 预览运行
	private var isRunningForPreviews: Bool {
		#if DEBUG
			return ProcessInfo.processInfo.environment[
				"XCODE_RUNNING_FOR_PREVIEWS"
			] == "1"
		#else
			return false
		#endif
	}

	var body: some View {
		TabView {
			CarControlsView()
				.tabItem {
					Label("车辆", systemImage: "car.fill")
				}

			UserInfoView()
				.tabItem {
					Label("我的", systemImage: "person.fill")
				}

			// 仅在 DEBUG 模式下编译，且仅在预览时显示
			#if DEBUG

				DebugView()
					.tabItem {
						Label("调试", systemImage: "ladybug.fill")
					}

			#endif
		}
	}
}

// MARK: - Preview
#Preview {
	// 为了预览，我们需要一个 DataManager 的实例
	// 这里可以直接使用单例
	MainTabView()
		.environmentObject(DataManager.shared)
		.environmentObject(BluetoothManager.shared)
}
