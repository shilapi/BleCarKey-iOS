//
//  NetUtil.swift
//  carkey
//
//  Created by Shilapi Chen on 9/8/25.
//
import Foundation
import CommonCrypto
import CryptoKit

extension String {
    func generateMD5() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
    }
}

func getRandomString(length: Int) -> String {
    var result = ""
    for _ in 0..<length {
        let r = Int(arc4random_uniform(36)) // 0...35
        if r < 10 {
            // 数字
            result.append(String(r))
        } else {
            // 小写字母
            let char = Character(UnicodeScalar(r - 10 + 97)!) // 97 = "a"
            result.append(char)
        }
    }
    return result
}

func getDeviceModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
}
