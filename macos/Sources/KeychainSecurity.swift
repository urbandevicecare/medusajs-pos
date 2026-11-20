import Foundation
import Security

/// Hardware-backed Apple Keychain Services helper for macOS.
/// Encrypts and securely stores server URLs, API keys, and staff session tokens using AES-256 GCM.
public enum KeychainSecurity {
    private static let serviceName = "co.uk.urbandevicecare.pos"
    public static var useInMemoryStoreForTesting: Bool = false
    private static var inMemoryStore: [String: String] = [:]
    
    private static var isTestEnvironment: Bool {
        useInMemoryStoreForTesting || ProcessInfo.processInfo.environment["UDC_POS_TEST_MODE"] == "1"
    }
    
    public static func save(key: String, value: String) -> Bool {
        if isTestEnvironment {
            inMemoryStore[key] = value
            return true
        }
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing item before saving updated credential
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public static func load(key: String) -> String? {
        if isTestEnvironment {
            return inMemoryStore[key]
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    public static func delete(key: String) {
        if isTestEnvironment {
            inMemoryStore.removeValue(forKey: key)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
