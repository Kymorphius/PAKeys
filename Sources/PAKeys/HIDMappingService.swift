import Foundation

struct KeyMapping: Codable, Equatable, Sendable {
    let source: UInt64
    let destination: UInt64

    enum CodingKeys: String, CodingKey {
        case source = "HIDKeyboardModifierMappingSrc"
        case destination = "HIDKeyboardModifierMappingDst"
    }
}

enum HIDMappingError: LocalizedError {
    case commandFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message.isEmpty ? "系统未能更新按键映射。" : message
        case .invalidOutput:
            return "无法读取当前按键映射。"
        }
    }
}

struct HIDMappingService: Sendable {
    // USB HID usage IDs: Right GUI/Command (0xE7), Left GUI/Command (0xE3).
    static let rightCommandToLeftCommand = KeyMapping(
        source: 0x7000000E7,
        destination: 0x7000000E3
    )

    func isEnabled() throws -> Bool {
        try currentMappings().contains(Self.rightCommandToLeftCommand)
    }

    func setEnabled(_ enabled: Bool) throws {
        var mappings = try currentMappings().filter {
            $0.source != Self.rightCommandToLeftCommand.source
        }

        if enabled {
            mappings.append(Self.rightCommandToLeftCommand)
        }

        let data = try JSONEncoder().encode(["UserKeyMapping": mappings])
        guard let json = String(data: data, encoding: .utf8) else {
            throw HIDMappingError.invalidOutput
        }

        _ = try runHIDUtil(arguments: ["property", "--set", json])
    }

    func currentMappings() throws -> [KeyMapping] {
        let output = try runHIDUtil(arguments: ["property", "--get", "UserKeyMapping"])
        return try Self.parseMappings(output)
    }

    static func parseMappings(_ output: String) throws -> [KeyMapping] {
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value == "(null)" {
            return []
        }

        guard let data = value.data(using: .utf8) else {
            throw HIDMappingError.invalidOutput
        }

        if let mappings = try? JSONDecoder().decode([KeyMapping].self, from: data) {
            return mappings
        }

        // hidutil commonly prints an OpenStep-style property list rather than JSON.
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
           let rawMappings = plist as? [[String: Any]] {
            return rawMappings.compactMap { item in
                guard
                    let source = uint64(item["HIDKeyboardModifierMappingSrc"]),
                    let destination = uint64(item["HIDKeyboardModifierMappingDst"])
                else { return nil }
                return KeyMapping(source: source, destination: destination)
            }
        }

        throw HIDMappingError.invalidOutput
    }

    private static func uint64(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber { return number.uint64Value }
        if let string = value as? String { return UInt64(string) }
        return nil
    }

    private func runHIDUtil(arguments: [String]) throws -> String {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let error = standardError.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: error, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw HIDMappingError.commandFailed(message)
        }

        return String(data: output, encoding: .utf8) ?? ""
    }
}
