//
//  Logger.swift
//  webdav
//
//  Created by ZQJ on 2025/12/8.
//

// 修改Logger.swift文件以支持多个参数输入

import Foundation

/// 日志级别枚举
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 4
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var stringValue: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .none: return "NONE"
        }
    }
    
    var colorCode: String {
        switch self {
        case .debug: return "\u{001B}[0;36m" // 青色
        case .info: return "\u{001B}[0;32m" // 绿色
        case .warning: return "\u{001B}[0;33m" // 黄色
        case .error: return "\u{001B}[0;31m" // 红色
        case .none: return "\u{001B}[0;0m" // 默认
        }
    }
}

/// 日志配置
struct LogConfiguration {
    var logLevel: LogLevel
    var showTimestamp: Bool
    var showLogLevel: Bool
    var showFileName: Bool
    var showLineNumber: Bool
    var showFunctionName: Bool
    
    static var `default`: LogConfiguration {
        return LogConfiguration(
            logLevel: .debug,
            showTimestamp: true,
            showLogLevel: true,
            showFileName: true,
            showLineNumber: true,
            showFunctionName: true
        )
    }
    
    static var production: LogConfiguration {
        return LogConfiguration(
            logLevel: .warning,
            showTimestamp: true,
            showLogLevel: true,
            showFileName: false,
            showLineNumber: false,
            showFunctionName: false
        )
    }
}

/// 日志管理器
class Logger {
    static let shared = Logger()
    private init() {}
    
    var configuration = LogConfiguration.default
    
    var logOutput: ((String) -> Void) = { message in
        print(message)
    }
    
    /// 通用日志方法 - 支持多个参数
    func log(
        _ items: Any...,
        level: LogLevel,
        separator: String = " ",
        terminator: String = "",
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        guard level >= configuration.logLevel else {
            return
        }
        
        var logPrefix = ""
        
        if configuration.showTimestamp {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            logPrefix += "[\(timestamp)] "
        }
        
        if configuration.showLogLevel {
            logPrefix += "[\(level.stringValue)] "
        }
        
        if configuration.showFileName || configuration.showLineNumber {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            if configuration.showFileName {
                logPrefix += "[\(fileName)"
            }
            if configuration.showLineNumber {
                logPrefix += ":\(line)"
            }
            if configuration.showFileName || configuration.showLineNumber {
                logPrefix += "] "
            }
        }
        
        if configuration.showFunctionName {
            logPrefix += "[\(function)] "
        }
        
        // 将多个参数组合成一个字符串
        let message = items.map { String(describing: $0) }.joined(separator: separator) + terminator
        let fullMessage = logPrefix + message
        
        #if DEBUG
        logOutput("\(level.colorCode)\(fullMessage)\u{001B}[0;0m")
        #else
        logOutput(fullMessage)
        #endif
    }
    
    // 便捷日志方法 - 支持多个参数
    func debug(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
        log(items, level: .debug, separator: separator, terminator: terminator, file: file, line: line, function: function)
    }
    
    func info(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
        log(items, level: .info, separator: separator, terminator: terminator, file: file, line: line, function: function)
    }
    
    func warning(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
        log(items, level: .warning, separator: separator, terminator: terminator, file: file, line: line, function: function)
    }
    
    func error(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
        log(items, level: .error, separator: separator, terminator: terminator, file: file, line: line, function: function)
    }
    
    func setLogLevel(_ level: LogLevel) {
        configuration.logLevel = level
    }
    
    func enableProductionMode() {
        configuration = .production
    }
    
    func enableDevelopmentMode() {
        configuration = .default
    }
}

// 便捷的全局日志函数 - 支持多个参数
func DLog(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
    Logger.shared.debug(items, separator: separator, terminator: terminator, file: file, line: line, function: function)
}

func ILog(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
    Logger.shared.info(items, separator: separator, terminator: terminator, file: file, line: line, function: function)
}

func WLog(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
    Logger.shared.warning(items, separator: separator, terminator: terminator, file: file, line: line, function: function)
}

func ELog(_ items: Any..., separator: String = " ", terminator: String = "", file: String = #file, line: Int = #line, function: String = #function) {
    Logger.shared.error(items, separator: separator, terminator: terminator, file: file, line: line, function: function)
}
