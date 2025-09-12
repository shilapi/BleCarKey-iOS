//
//  NetUtil.swift
//  carkey
//
//  Created by Shilapi Chen on 9/8/25.
//
import Foundation
import CommonCrypto

extension String {
    var md5: String {
        let data = Data(self.utf8) // Convert the string to Data using UTF-8 encoding
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH)) // Create a buffer for the MD5 digest

        // Perform the MD5 hash calculation
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }

        // Convert the digest bytes to a hexadecimal string
        return digest.map { String(format: "%02x", $0) }.joined()
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
