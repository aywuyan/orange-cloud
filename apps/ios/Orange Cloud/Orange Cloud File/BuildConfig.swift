//
//  BuildConfig.swift
//  Orange Cloud File
//
//  与 Shared/BuildConfig.swift 同构。File Provider 扩展是独立 target，不编译 Shared/，
//  所以这里放一份最小实现；配置来源同样是 xcconfig → Info.plist。
//

import Foundation

nonisolated enum BuildConfig {

    static func string(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    /// 跨进程共享容器（与主 App / Widget 一致）
    static let appGroupID = string("OCAppGroup") ?? "group.jiamin.chen.Orange-Cloud"

    /// 共享钥匙串组；nil = 用系统默认组
    static let keychainGroup = string("OCKeychainGroup")

    /// Cloudflare OAuth Client ID（File Provider 内刷新 token 时要用）
    static let oauthClientID = string("OCOAuthClientID") ?? "102240eb9095a1965ee11813ef4788cd"
}
