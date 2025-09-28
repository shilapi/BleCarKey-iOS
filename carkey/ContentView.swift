import SwiftUI
import Foundation
import OSLog

let loggerView = Logger(
	subsystem: "logger.carkey.com",
	category: "view"
)

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
        Section(){
            HStack {
                Spacer()
                Text(statusText)
                    .font(.footnote) // 使用小号字体
                    .foregroundColor(.secondary) // 使用非常柔和的灰色
                Spacer()
            }
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
struct CarInfoView: View {
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        NavigationView {
            List {
				if dataManager.appData.carData != nil {
                    // 1. 使用 ZStack 作为根容器来实现层叠效果
                    ZStack(alignment: .topLeading) { // 默认对齐方式设为左上
                        
                        // 背景层：为了撑开 ZStack 的高度，并让图片有对齐的参考空间
                        // 我们用一个透明色块来隐式定义高度
                        Color.clear.frame(height: 180) // 你可以根据需要调整这个高度
                        
                        // 文字层 (VStack)
                        VStack(alignment: .leading, spacing: -20) {
                                Text("ALL")
                                Text("GOOD")
                            }
                            // 将字体样式统一应用到 VStack，它会自动传递给内部的 Text
                            .font(.system(size: 75, weight: .heavy, design: .default))
                            .frame(maxWidth: .infinity, alignment: .leading) // 确保 VStack 在 ZStack 内靠左
                        
                        // 图片层 (Image)
                        Image("EQ100") // 确保你的项目中有名为 "EQ100" 的图片资源
                            .resizable()
                            .scaledToFit()
                            .frame(width: 400) // 给图片一个合适的尺寸
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.bottom, -50)
                            .padding(.trailing, -50)
                        Color.clear.frame(height: 240)
                    }
                    // 这两个修改器应用在 ZStack 上，确保它在 List 中正确显示
                    .listRowInsets(EdgeInsets()) // 移除 List 的默认行边距，让 ZStack 占满整个宽度
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("核心状态")) {
					if let status = dataManager.appData.carData?.carStatus {
                        InfoRowView(label: "车辆状态", value: status.statusName)
                        InfoRowView(label: "剩余续航", value: "\(status.remainingMileage ?? 0) KM")
                        InfoRowView(label: "电池电量", value: "\(status.batterySOCPercentage ?? 0)%")
                        InfoRowView(label: "总里程", value: "\(status.mileage) KM")
                        InfoRowView(label: "车内温度", value: "\(status.interiorTemp ?? 0)°C")
                    } else {
                        Text("请下拉刷新或从Debug页注入数据")
                    }
                }
                
                Section(header: Text("车辆信息")) {
					if let info = dataManager.appData.carData?.carInfo {
                        InfoRowView(label: "车型", value: info.carTypeName)
                        InfoRowView(label: "车名", value: info.carName)
                        InfoRowView(label: "颜色", value: info.colorName)
                        
                        // 二级菜单入口
                        NavigationLink(destination: CarKeyInfoView()) {
                            Text("查看蓝牙密钥详情").bold()
                        }
                    } else {
                        Text("无车辆信息")
                    }
                }
				
				ApiStatusView(error: nil, lastUpdateTime: dataManager.appData.carData?.carStatus.collectTime)
                .listRowSeparator(.hidden)
                .padding(.vertical)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: -10, leading: 0, bottom: 20, trailing: 0))
                
            }
            // .navigationTitle("车辆信息")
            //.scrollContentBackground(.hidden)
            .refreshable {
                // 在这里调用您的刷新逻辑
				loggerView.debug("refetching car info data")
                dataManager.fetchAndLoadCarData()
            }
        }
    }
}

// --- 蓝牙密钥二级页面 ---
struct CarKeyInfoView: View {
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        List {
            Section(header: Text("蓝牙密钥详情")) {
				if let keyData = dataManager.appData.carKeyData {
                    InfoRowView(label: "密钥ID", value: keyData.keyId.masked(percentage: 0.7))
                    InfoRowView(label: "密钥类型", value: keyData.keyType)
                    InfoRowView(label: "VIN码", value: keyData.vin.masked(percentage: 0.7))
                    InfoRowView(label: "用户ID", value: keyData.userId.masked(percentage: 0.7))
                    InfoRowView(label: "蓝牙MAC", value: keyData.bleMac.masked(percentage: 0.7))
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
        let suffixCount = clearCount - prefixCount // 这样可以处理奇数明文的情况
        
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
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("账户信息")) {
					if let user = dataManager.appData.userData {
                        InfoRowView(label: "用户名", value: user.userName)
                        InfoRowView(label: "用户ID (手机)", value: user.userID.masked(percentage: 0.7))
                        InfoRowView(label: "Access Token", value: String(user.accessToken.prefix(10) + "...").masked(percentage: 0.7))
                    } else {
                        Text("请从Debug页注入数据或登录")
                        Button(action: {
                            DataManager.shared.login(userName: "Shilapi", accessToken: "117582730164062Q137Z2B48227S1Y67FA99C2E07843D0A6F24DBC730990C6P6", clientSecret: "c5ad2a4290faa3df39683865c2e10310", userID: "18501754337")
                        }) {
                            Text("登录")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("用户信息")
        }
    }
}

// --- Debug Tab (仅在 DEBUG 模式下编译) ---
#if DEBUG
struct DebugView: View {
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
                
                Section(header: Text("蓝牙")) {
                    Text("当前状态： \(String(describing: bt.state))")
                    
                    Section(header: Text("发现的设备 (\(bt.avaliblePeripherals.count))")) {
                        if bt.avaliblePeripherals.isEmpty {
                            Text( "请开始扫描来发现附近的设备...")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(bt.avaliblePeripherals) {device in
                                Text(device.id)
                            }
                        }
                    }
                    
                    Button("开始扫描", action: {
						BluetoothManager.shared.startScan()
                    })
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
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }
    
    var body: some View {
        TabView {
            CarInfoView()
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
