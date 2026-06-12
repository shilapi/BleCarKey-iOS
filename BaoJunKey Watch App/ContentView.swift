//
//  ContentView.swift
//  BaoJunKey Watch App
//
//  Created by Shilapi Chen on 6/11/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
			Button{
				
			} label: {
				Image("Bluetooth_capsule")
					.imageScale(.large)
			}.buttonBorderShape(.circle)
			
			Text("Current connectivity:")
			
			HStack{
				Button{
					
				} label: {
					Image(systemName: "lock.open.fill")
				}
				
				Button{
					
				} label: {
					Image(systemName: "lock.fill")
				}
			}
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
