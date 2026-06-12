//
//  ContentView.swift
//  BaoJunKey Watch App
//
//  Main watch UI: Bluetooth connect, vehicle info, lock/unlock controls
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @ObservedObject private var btManager = WatchBluetoothManager.shared
    @ObservedObject private var dataManager = WatchDataManager.shared

    var body: some View {
		VStack(alignment: .center, spacing: 8) {
            // Top: Bluetooth connect button + status
			HStack(alignment: .center) {
                Button {
                    WKInterfaceDevice.current().play(.click)
					if btManager.state == .disconnected{
						btManager.startScan()
					} else {
						btManager.disconnect()
						btManager.state = .disconnected
					}
                } label: {
                    Image("Bluetooth_capsule")
                        .imageScale(.large)
                }
				.buttonStyle(.automatic)
				.frame(width: 40, height: 40)
                .buttonBorderShape(.circle)
                .disabled(btManager.state == .scanning || btManager.state == .authorizing)

                Spacer()

                // Connection status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 8, height: 8)
                    Text(indicatorText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Center: Vehicle info
            VStack(spacing: 2) {
                if dataManager.hasKeyData {
                    Text(dataManager.carName)
                        .font(.headline)
                        .lineLimit(1)

                    if !dataManager.carModel.isEmpty {
                        Text(dataManager.carModel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Label("\(dataManager.batteryLevel)%", systemImage: "battery.75")
                            .font(.caption)
                    }
                } else {
                    Text("未同步钥匙")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("请在 iPhone 上登录并同步")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("同步: \(dataManager.lastSyncDate)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Bottom: Lock/Unlock buttons
            HStack(spacing: 16) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    btManager.CarUnlock()
                } label: {
                        Image(systemName: "lock.open.fill")
                            .font(.title2)
                }
				.buttonSizing(.automatic)
                .disabled(btManager.state != .connected)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    btManager.CarLock()
                } label: {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                }
                .disabled(btManager.state != .connected)
            }
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var indicatorColor: Color {
        switch btManager.state {
        case .disconnected, .unknown: return .red
        case .scanning: return .orange
        case .authorizing: return .yellow
        case .connected: return .green
        }
    }

    private var indicatorText: String {
        switch btManager.state {
        case .disconnected: return "未连接"
        case .scanning: return "扫描中"
        case .authorizing: return "连接中"
        case .connected: return "已连接"
        case .unknown: return "错误"
        }
    }
}

#Preview {
    ContentView()
}
