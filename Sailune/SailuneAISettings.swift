import Foundation
import Security

enum SailuneAIProvider: String, CaseIterable, Identifiable {
    case appleOnDevice
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleOnDevice: "Apple 裝置端模型（免金鑰）"
        case .gemini: "Gemini API"
        }
    }
}

struct SailuneAISettings {
    static let defaultEndpoint = "https://generativelanguage.googleapis.com/v1beta/interactions"
    static let defaultModel = "gemini-3.8-flash"

    let endpoint: URL
    let model: String

    init(endpoint: String, model: String) throws {
        let endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: endpoint),
              url.scheme == "https",
              url.host == "generativelanguage.googleapis.com",
              url.path == "/v1beta/interactions",
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw SailuneAISettingsError.invalidEndpoint
        }
        guard !model.isEmpty,
              model.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            throw SailuneAISettingsError.invalidModel
        }
        self.endpoint = url
        self.model = model
    }
}

enum SailuneAISettingsError: LocalizedError {
    case invalidEndpoint
    case invalidModel
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "API 接口須為 Google Gemini 的 HTTPS Interactions 網址。"
        case .invalidModel: "模型名稱只能包含英文字母、數字、句點、底線與連字號。"
        case .keychain: "無法存取 macOS 鑰匙圈，請檢查系統設定後重試。"
        }
    }
}

enum SailuneAISettingsStore {
    private static let providerKey = "SailuneAIProvider"
    private static let endpointKey = "SailuneAIEndpoint"
    private static let modelKey = "SailuneAIModel"
    private static let keychainService = "com.sailune.ai.gemini"
    private static let keychainAccount = "personal-api-key"

    static var provider: SailuneAIProvider {
        SailuneAIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .appleOnDevice
    }

    static var endpoint: String {
        UserDefaults.standard.string(forKey: endpointKey) ?? SailuneAISettings.defaultEndpoint
    }

    static var model: String {
        UserDefaults.standard.string(forKey: modelKey) ?? SailuneAISettings.defaultModel
    }

    static func apiKey() throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(keychainQuery(returnData: true) as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw SailuneAISettingsError.keychain(status)
        }
        return value
    }

    static func save(provider: SailuneAIProvider, endpoint: String, model: String, apiKey: String) throws {
        let settings = try SailuneAISettings(endpoint: endpoint, model: model)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            let status = SecItemDelete(keychainQuery() as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw SailuneAISettingsError.keychain(status)
            }
        } else {
            let data = Data(key.utf8)
            let status = SecItemUpdate(keychainQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if status == errSecItemNotFound {
                var item = keychainQuery()
                item[kSecValueData as String] = data
                let addStatus = SecItemAdd(item as CFDictionary, nil)
                guard addStatus == errSecSuccess else { throw SailuneAISettingsError.keychain(addStatus) }
            } else if status != errSecSuccess {
                throw SailuneAISettingsError.keychain(status)
            }
        }
        UserDefaults.standard.set(settings.endpoint.absoluteString, forKey: endpointKey)
        UserDefaults.standard.set(settings.model, forKey: modelKey)
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }

    private static func keychainQuery(returnData: Bool = false) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        if returnData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }
}
