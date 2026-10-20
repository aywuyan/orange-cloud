//
//  BuildConfig.swift
//  Shared（主 App / Widget / Watch）
//
//  自编译配置的运行时入口：构建时由 xcconfig 写入 Info.plist（OCAppGroup 等），
//  运行时在 Bundle.main 里读回来。没有注入配置时回退到上游默认值，
//  所以直接 clone 用 Xcode 打开、不做任何配置也能正常编译运行。
//
//  Info.plist 里的值由 build setting 展开；未定义的 build setting 会展开成空串，
//  某些构建方式也可能原样留下 "$(OCAppGroup)"，这两种情况都按“未配置”处理。
//

import Foundation

nonisolated enum BuildConfig {

    /// 读 Info.plist 里的构建配置；缺失 / 空串 / 未被展开的 `$(...)` 均视为未配置
    static func string(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    /// 跨进程共享容器（主 App / Widget / Watch / 扩展）
    static let appGroupID = string("OCAppGroup") ?? "group.jiamin.chen.Orange-Cloud"

    /// 共享钥匙串组；nil = 不指定 access group，用系统默认组
    static let keychainGroup = string("OCKeychainGroup")

    /// Cloudflare OAuth Client ID
    static let oauthClientID = string("OCOAuthClientID") ?? "102240eb9095a1965ee11813ef4788cd"

    /// OAuth 回调中转地址（必须与 Dashboard 注册的 redirect_uri 完全一致）
    static let oauthRedirectURI = string("OCOAuthRedirectURI") ?? "https://o-c.do/oauth/callback"
}
