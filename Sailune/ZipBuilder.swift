import Foundation

// MARK: - stored-only zip writer（mimetype 第一個、全部 stored、無 extra field）
struct ZipBuilder {
    private var data = Data()
    private var central = Data()
    private var entries = 0

    mutating func addEntry(_ name: String, _ fileData: Data) {
        let nameData = Data(name.utf8)
        let crc = Self.crc32(fileData)
        let size = UInt32(fileData.count)
        let offset = UInt32(data.count)

        // local file header
        data.appendLE32(0x04034b50)
        data.appendLE16(20)              // version needed
        data.appendLE16(0)               // flags
        data.appendLE16(0)               // method = stored
        data.appendLE16(0)               // mod time
        data.appendLE16(0x0021)          // mod date (1980-01-01)
        data.appendLE32(crc)
        data.appendLE32(size)            // compressed size
        data.appendLE32(size)            // uncompressed size
        data.appendLE16(UInt16(nameData.count))
        data.appendLE16(0)               // extra field length = 0（mimetype 硬性要求）
        data.append(nameData)
        data.append(fileData)

        // central directory header
        central.appendLE32(0x02014b50)
        central.appendLE16(20)           // version made by
        central.appendLE16(20)           // version needed
        central.appendLE16(0)            // flags
        central.appendLE16(0)            // method = stored
        central.appendLE16(0)            // mod time
        central.appendLE16(0x0021)       // mod date
        central.appendLE32(crc)
        central.appendLE32(size)
        central.appendLE32(size)
        central.appendLE16(UInt16(nameData.count))
        central.appendLE16(0)            // extra
        central.appendLE16(0)            // comment
        central.appendLE16(0)            // disk start
        central.appendLE16(0)            // internal attr
        central.appendLE32(0)            // external attr
        central.appendLE32(offset)       // local header offset
        central.append(nameData)

        entries += 1
    }

    mutating func finalize() -> Data {
        let cdOffset = UInt32(data.count)
        data.append(central)
        let cdSize = UInt32(central.count)
        data.appendLE32(0x06054b50)      // EOCD
        data.appendLE16(0)
        data.appendLE16(0)
        data.appendLE16(UInt16(entries))
        data.appendLE16(UInt16(entries))
        data.appendLE32(cdSize)
        data.appendLE32(cdOffset)
        data.appendLE16(0)
        return data
    }

    // CRC32（標準 polynomial 0xEDB88320，與 zlib 同款）
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
    private static let crcTable: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }
}

private extension Data {
    mutating func appendLE16(_ v: UInt16) { var le = v.littleEndian; append(Data(bytes: &le, count: 2)) }
    mutating func appendLE32(_ v: UInt32) { var le = v.littleEndian; append(Data(bytes: &le, count: 4)) }
}
