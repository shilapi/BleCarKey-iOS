//
//  ContentView.swift
//  carkey
//
//  Created by Shilapi Chen on 9/8/25.
//

import SwiftUI


struct ContentView: View {
    @EnvironmentObject var carData: CarData
    @EnvironmentObject var userData: UserData
    @EnvironmentObject var oauthinfo: SGMWUnifiedOAuth
    
    var body: some View {
    VStack(alignment: .leading) {
            Text("—— Auth info ——")
            Text("signature:\n\(oauthinfo.signature)")
            Text("nounce:\n\(oauthinfo.nounce)")
            Text("timestamp:\n\(oauthinfo.timestamp)")
            Text("\n")
            
            Text("—— User info ——")
            Text("accessToken:\n\(oauthinfo.accesstoken)")
            Text("clientSecret:\n\(oauthinfo.clientsecret)")
            Button("Refresh Oauth data") {
                DataManager.shared.userData.login(userName: "Shilapi", accessToken: "117575535718012C1R7N2W482I7A1V9B96AB7C083D40028FA72523943396CFU6", clientSecret: "c5ad2a4290faa3df39683865c2e10310", userID: "18501754337")
                oauthinfo.generateAuth()
            }
            Button("Fetch car data") {
                NetworkManager.shared.requestBaojun(BaojunEndpoint.queryDefaultCarStatus, completion: debugCallBack)
            }
            Button("Fetch key data") {
                NetworkManager.shared.requestBaojun(BaojunEndpoint.queryBleKey(vin: DataManager.shared.carData.vin, userId: DataManager.shared.userData.userID), completion: debugCallBack)
            }
        }
    .padding()
    .navigationTitle("debug")
    }
}

func debugCallBack(result: Result<Data, Error>) {
    switch result {
        case .success(let data):
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
        case .failure(let error):
            print("Error: \(error)")
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager.shared.carData)
        .environmentObject(DataManager.shared.userData)
        .environmentObject(DataManager.shared.sgmwUnifiedOAuth)
}
