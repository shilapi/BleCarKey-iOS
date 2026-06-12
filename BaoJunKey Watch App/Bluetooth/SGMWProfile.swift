//
//  SGMWProfile.swift
//  BaoJunKey Watch App
//
//  Ported BLE service/characteristic UUIDs from carkey/Data/SGMW.swift
//

import Foundation
import CoreBluetooth

enum SGMWBLEProfile {
    enum AuthorizeService {
        static let uuid = CBUUID(string: "181A")

        enum Characteristics {
            static let Request  = CBUUID(string: "2A6E")
            static let Response = CBUUID(string: "2A6F")
        }
    }

    enum ControlService {
        static let uuid = CBUUID(string: "182A")

        enum Characteristics {
            static let Request  = CBUUID(string: "2A7E")
            static let Response = CBUUID(string: "2A7F")
        }
    }

    static let AllServicesUuid = [
        CBUUID(string: "F000FFD0-0451-4000-B000-000000000000"),
        AuthorizeService.uuid,
        ControlService.uuid
    ]
}
