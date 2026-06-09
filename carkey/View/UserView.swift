//
//  UserView.swift
//  carkey
//
//  Created by Shilapi Chen on 9/30/25.
//

import SwiftUI

struct ProfileView: View {
	var body: some View {
		NavigationView {
			ZStack {
				Color.black.edgesIgnoringSafeArea(.all)
				
				VStack {
					Image(systemName: "person.crop.circle.fill")
						.resizable()
						.frame(width: 120, height: 120)
						.foregroundColor(.gray)
						.padding(.top, 50)
					
					Text("User Name")
						.font(.largeTitle)
						.fontWeight(.bold)
						.foregroundColor(.white)
						.padding()
					
					List {
						Section(header: Text("设置").foregroundColor(.gray)) {
							ProfileRow(icon: "key.fill", title: "数字钥匙管理")
							ProfileRow(icon: "bell.fill", title: "通知设置")
							ProfileRow(icon: "questionmark.circle.fill", title: "帮助与反馈")
						}
						.listRowBackground(Color.gray.opacity(0.2))
						
						Section {
							Button(action: {
								// 退出登录逻辑
							}) {
								Text("退出登录")
									.foregroundColor(.red)
									.frame(maxWidth: .infinity, alignment: .center)
							}
						}
						.listRowBackground(Color.gray.opacity(0.2))
					}
					.listStyle(InsetGroupedListStyle())
				}
				.navigationTitle("我的")
				.navigationBarHidden(true)
			}
		}.preferredColorScheme(.dark)
	}
}

struct ProfileRow: View {
	let icon: String
	let title: String
	
	var body: some View {
		HStack {
			Image(systemName: icon)
				.foregroundColor(.blue)
			Text(title)
				.foregroundColor(.white)
			Spacer()
			Image(systemName: "chevron.right")
				.foregroundColor(.gray)
		}
		.padding(.vertical, 8)
	}
}

struct ProfileView_Previews: PreviewProvider {
	static var previews: some View {
		ProfileView()
	}
}
