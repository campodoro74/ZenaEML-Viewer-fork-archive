import Foundation

public enum Decoding {

    // MARK: - Quoted-Printable

    public static func quotedPrintable(_ data: Data) -> Data {
        var out = Data()
        out.reserveCapacity(data.count)
        let bytes = [UInt8](data)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == 0x3D { // '='
                if i + 1 < bytes.count, bytes[i + 1] == 0x0A {
                    i += 2; continue
                }
                if i + 2 < bytes.count, bytes[i + 1] == 0x0D, bytes[i + 2] == 0x0A {
                    i += 3; continue
                }
                if i + 2 < bytes.count,
                   let hi = hexValue(bytes[i + 1]),
                   let lo = hexValue(bytes[i + 2]) {
                    out.append(UInt8((hi << 4) | lo))
                    i += 3; continue
                }
                out.append(b); i += 1
            } else {
                out.append(b); i += 1
            }
        }
        return out
    }

    private static func hexValue(_ b: UInt8) -> Int? {
        switch b {
        case 0x30...0x39: return Int(b - 0x30)
        case 0x41...0x46: return Int(b - 0x41 + 10)
        case 0x61...0x66: return Int(b - 0x61 + 10)
        default: return nil
        }
    }

    // MARK: - Base64

    public static func base64(_ s: String) -> Data {
        let cleaned = s.unicodeScalars.filter { scalar in
            let c = scalar.value
            return (c >= 0x30 && c <= 0x39) ||
                   (c >= 0x41 && c <= 0x5A) ||
                   (c >= 0x61 && c <= 0x7A) ||
                   c == 0x2B || c == 0x2F || c == 0x3D
        }
        let str = String(String.UnicodeScalarView(cleaned))
        return Data(base64Encoded: str, options: .ignoreUnknownCharacters) ?? Data()
    }

    // MARK: - Charset → String

    public static func string(from data: Data, charset: String?) -> String {
        if let cs = charset, let enc = encoding(for: cs), let s = String(data: data, encoding: enc) {
            return s
        }
        if let s = String(data: data, encoding: .utf8) { return s }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    public static func encoding(for charset: String) -> String.Encoding? {
        let cs = charset.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch cs {
        case "utf-8", "utf8": return .utf8
        case "us-ascii", "ascii": return .ascii
        case "iso-8859-1", "latin1", "latin-1": return .isoLatin1
        case "iso-8859-2": return .isoLatin2
        case "windows-1250", "cp1250": return .windowsCP1250
        case "windows-1251", "cp1251": return .windowsCP1251
        case "windows-1252", "cp1252": return .windowsCP1252
        case "windows-1253", "cp1253": return .windowsCP1253
        case "windows-1254", "cp1254": return .windowsCP1254
        case "utf-16", "utf16": return .utf16
        case "utf-16le": return .utf16LittleEndian
        case "utf-16be": return .utf16BigEndian
        default: break
        }
        let cfEnc = CFStringConvertIANACharSetNameToEncoding(cs as CFString)
        if cfEnc != kCFStringEncodingInvalidId {
            let ns = CFStringConvertEncodingToNSStringEncoding(cfEnc)
            return String.Encoding(rawValue: ns)
        }
        return nil
    }
}
