//
//  TokenStore.swift
//  Orange Cloud
//
//  OAuth Token 只存 Keychain，绝不写 UserDefaults 或内存以外的地方。
//  多登录身份：每个身份（UUID）一个 Keychain 条目；旧版单条目在首次启动时迁移。
//

import Foundation
import Security

nonisolated enum TokenStore {

    struct StoredToken: Codable, Sendable {
        var accessToken:  String
        var refreshToken: String?
        var expiresAt:    Date
        var scope:        String
    }

    private static let service = "app.orangecloud.oauth"
    private static let legacyAccount = "default"

    /// 共享钥匙串组（主 App 与 Widget 共用；Widget 只读 access_token，不做刷新）。
    /// 自编译由 xcconfig 的 OC_KEYCHAIN_GROUP 注入；未配置时为 nil，用系统默认组——
    /// 签名注入的 entitlements 若让主 App 与扩展落在同一个默认组，共享同样成立。
    static let sharedAccessGroup = BuildConfig.keychainGroup

    // MARK: - 按身份读写

    @discardableResult
    static func save(_ token: StoredToken, sessionId: UUID) -> Bool {
        save(token, account: sessionId.uuidString)
    }

    static func load(sessionId: UUID) -> StoredToken? {
        load(account: sessionId.uuidString)
    }

    static func clear(sessionId: UUID) {
        SecItemDelete(baseQuery(account: sessionId.uuidString) as CFDictionary)
    }

    // MARK: - 旧版单 token（迁移用）

    static func loadLegacy() -> StoredToken? {
        load(account: legacyAccount)
    }

    static func clearLegacy() {
        SecItemDelete(baseQuery(account: legacyAccount) as CFDictionary)
    }

    // MARK: - 内部实现

    @discardableResult
    private static func save(_ token: StoredToken, account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(token) else { return false }

        // 先原地更新：「删后加」之间有一个无 token 的窗口，File Provider 扩展 / Widget 并发读会读到
        // "token missing"（Files.app 里表现为一次鉴权失败）。只更新纯本机 + 共享组这一种正规形态，
        // 更新成功即返回；历史遗留的可同步条目等形态仍走下面的删后加归一。
        var updateQuery = baseQuery(account: account)
        updateQuery[kSecAttrSynchronizable as String] = false
        let updateAttrs: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary) == errSecSuccess {
            return true
        }

        // 删除时匹配本机与（历史遗留的）可同步两种形态，确保统一改回纯本机条目
        SecItemDelete(anyQuery(account: account) as CFDictionary)

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        // token 仅按设备本地保管，绝不随 iCloud 钥匙串跨设备同步
        // （OAuth 刷新令牌每次轮换，同步旧令牌会导致并发刷新互相作废而误登出）
        query[kSecAttrSynchronizable as String] = false
        let sharedStatus = SecItemAdd(query as CFDictionary, nil)
        if sharedStatus == errSecSuccess {
            return true
        }
        // 没配共享组 = 刚才写的就是系统默认组，没有可回退的目标，直接算失败
        guard sharedAccessGroup != nil else {
            AppLog.auth.error("keychain token save FAILED account=\(account) status=\(sharedStatus)")
            return false
        }
        query.removeValue(forKey: kSecAttrAccessGroup as String)
        let fallbackStatus = SecItemAdd(query as CFDictionary, nil)
        if fallbackStatus != errSecSuccess {
            // 两次写入都失败 = token 已被上面的 SecItemDelete 清掉、新值又没写进去，
            // 下次读取必是 "token missing"。这里必须留痕，否则表象与静默丢 token 无法区分。
            AppLog.auth.error("keychain token save FAILED account=\(account) sharedStatus=\(sharedStatus) fallbackStatus=\(fallbackStatus)")
        }
        return fallbackStatus == errSecSuccess
    }

    private static func load(account: String) -> StoredToken? {
        var query = anyQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // 配了共享组时，读写删都带上它——否则只会命中系统默认组，找不到自己写进去的条目
        if let group = sharedAccessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    /// 读/删用：同时匹配本机与可同步条目
    private static func anyQuery(account: String) -> [String: Any] {
        var query = baseQuery(account: account)
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        return query
    }
}
