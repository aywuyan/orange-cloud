//
//  BuildConfig.swift
//  notification
//
//  与 Shared/BuildConfig.swift 同构。通知服务扩展是独立 target，不编译 Shared/，
//  这里只需要共享容器一项。
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
}
