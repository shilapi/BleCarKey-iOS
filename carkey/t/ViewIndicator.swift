import SwiftUI

// StatusState 和 StatusDetailView 保持不变，请确保它们在你的代码中。
// 这里为了示例完整性再次提供，如果你已经有了可以跳过。

// MARK: 1. 状态管理模型 (Enum) - 保持不变


// MARK: 2. 状态详情弹窗视图 - 保持不变
struct StatusDetailView: View {
	let state: StatusState
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(state.title)
				.font(.headline)
				.padding(.bottom, 0)
			
			
			
			switch state {
			case .ok:
				Text("")
					.fontWidth(.none)
					.padding(.bottom, -20)
			case .warning(let issues):
				Divider()
				ForEach(issues, id: \.self) { issue in
					Text("· \(issue)")
						.font(.body)
				}.padding(.bottom, 5)
				
			case .error(let issues):
				Divider()
				ForEach(issues, id: \.self) { issue in
					Text("· \(issue)")
						.font(.body)
				}.padding(.bottom, 5)
			}
		}
		.frame(minHeight: 50)
		.padding()
		.padding(.bottom, 20)
		.padding(.top, 20)
		.padding(.leading, 15)
		.padding(.trailing, 15)
	}
}


// MARK: 3. 可交互的圆形状态按钮 - 核心修改在这里
struct StatusButton: View {
	let state: StatusState
	
	var body: some View {
		Menu {
			StatusDetailView(state: state)
		} label: {
		}
	}
}


// MARK: 3.1. 修正后的 StatusButton (推荐 iOS 16+)
/// 圆形状态按钮组件，使用 `popover` 和 `presentationCompactAdaptation`
struct StatusButtonWithAdaptedPopover: View {
	let state: StatusState
	
	@State private var isShowingDetail = false // 控制详情弹窗的显示
	
	var body: some View {
		Button(action: {
			isShowingDetail.toggle()
		}) {
			ZStack {
				Circle()
					.fill(state.color)
					.shadow(radius: 5)
				Image(systemName: state.iconName)
					.font(.system(size: 24, weight: .bold))
					.foregroundColor(.white)
			}
			.frame(width: 50, height: 50)
		}
		.popover(isPresented: $isShowingDetail) {
			StatusDetailView(state: state)
				.presentationCompactAdaptation(.popover)
		}
	}
}

// MARK: 4. 示例和预览
struct ContentView: View {
	@State private var currentState: StatusState = .ok
	
	var body: some View {
		VStack(spacing: 40) {
			// 使用新的 StatusButtonWithAdaptedPopover
			StatusButtonWithAdaptedPopover(state: currentState)
			
			Text("点击上方按钮查看详情")
				.font(.caption)
				.foregroundColor(.secondary)
			
			VStack(spacing: 15) {
				Button("设置为“正常”") {
					currentState = .ok
				}
				.buttonStyle(.borderedProminent)
				.tint(.green)
				
				Button("设置为“警告”") {
					currentState = .warning(issues: ["网络信号弱", "电池电量低于20%"])
				}
				.buttonStyle(.borderedProminent)
				.tint(.orange)
				
				Button("设置为“错误”") {
					currentState = .error(issues: ["无法连接服务器", "数据同步失败", "权限验证错误"])
				}
				.buttonStyle(.borderedProminent)
				.tint(.red)
			}
		}
		.padding()
	}
}


#Preview {
	ContentView()
}
