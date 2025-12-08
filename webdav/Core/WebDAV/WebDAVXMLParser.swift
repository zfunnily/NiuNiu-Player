import Foundation

// MARK: - WebDAV基础数据模型
enum WebDAVItemType: String, Codable, CaseIterable {
    case file
    case directory
    case unknown
    
    // 提供一个从字符串安全转换的方法
       init(fromRawValue value: String?) {
           guard let value = value?.lowercased() else {
               self = .unknown
               return
           }
           
           // 尝试直接从原始值初始化
           if let type = WebDAVItemType(rawValue: value) {
               self = type
               return
           }
           
           // 处理可能的变体
           switch value {
           case "file", "document", "item":
               self = .file
           case "dir", "folder", "collection":
               self = .directory
           default:
               self = .unknown
           }
       }
}

struct WebDAVItem: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let type: WebDAVItemType
    let size: Int64?
    let modificationDate: Date?
    let creationDate: Date?
    let contentType: String?
    let etag: String?
    
    // 自定义CodingKeys枚举，控制编码和解码的字段
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case path
            case type
            case size
            case modificationDate
            case creationDate
            case contentType
            case etag
        }
        
        // 提供默认初始化器
        init(
            id: UUID = UUID(),
            name: String,
            path: String,
            type: WebDAVItemType,
            size: Int64? = nil,
            modificationDate: Date? = nil,
            creationDate: Date? = nil,
            contentType: String? = nil,
            etag: String? = nil
        ) {
            self.id = id
            self.name = name
            self.path = path
            self.type = type
            self.size = size
            self.modificationDate = modificationDate
            self.creationDate = creationDate
            self.contentType = contentType
            self.etag = etag
        }
        
        // MARK: - Decodable 实现
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // 解码UUID
            if let idString = try? container.decode(String.self, forKey: .id),
               let uuid = UUID(uuidString: idString) {
                self.id = uuid
            } else {
                // 如果无法解码UUID，生成一个新的
                self.id = UUID()
            }
            
            // 解码必要的字段
            self.name = try container.decode(String.self, forKey: .name)
            self.path = try container.decode(String.self, forKey: .path)
            
            // 解码枚举类型，可以从字符串或自定义编码解码
            if let typeString = try? container.decode(String.self, forKey: .type) {
                self.type = WebDAVItemType(fromRawValue: typeString)
            } else if let typeInt = try? container.decode(Int.self, forKey: .type),
                      typeInt < WebDAVItemType.allCases.count {
                // 也支持从整数索引解码
                self.type = WebDAVItemType.allCases[typeInt]
            } else {
                throw DecodingError.dataCorruptedError(forKey: .type,
                                                      in: container,
                                                      debugDescription: "无法解码WebDAVItemType")
            }
            
            // 解码可选字段
            self.size = try container.decodeIfPresent(Int64.self, forKey: .size)
            self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
            self.etag = try container.decodeIfPresent(String.self, forKey: .etag)
            
            // 解码日期（支持多种格式）
            self.modificationDate = try Self.decodeDate(from: container, forKey: .modificationDate)
            self.creationDate = try Self.decodeDate(from: container, forKey: .creationDate)
        }
        
        // MARK: - Encodable 实现
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // 编码所有字段
            try container.encode(id.uuidString, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(path, forKey: .path)
            try container.encode(type.rawValue, forKey: .type)
            
            // 编码可选字段
            if let size = size {
                try container.encode(size, forKey: .size)
            }
            
            if let contentType = contentType {
                try container.encode(contentType, forKey: .contentType)
            }
            
            if let etag = etag {
                try container.encode(etag, forKey: .etag)
            }
            
            // 编码日期（使用ISO 8601格式）
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let modificationDate = modificationDate {
                try container.encode(dateFormatter.string(from: modificationDate), forKey: .modificationDate)
            }
            
            if let creationDate = creationDate {
                try container.encode(dateFormatter.string(from: creationDate), forKey: .creationDate)
            }
        }
    static func == (lhs: WebDAVItem, rhs: WebDAVItem) -> Bool {
        return lhs.path == rhs.path
    }
    // MARK: - 辅助方法
        private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
            // 尝试解码为ISO 8601字符串
            if let dateString = try? container.decode(String.self, forKey: key) {
                // 尝试ISO 8601格式
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                
                // 尝试RFC 1123格式
                let rfcFormatter = DateFormatter()
                rfcFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                rfcFormatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = rfcFormatter.date(from: dateString) {
                    return date
                }
                
                // 尝试基本格式
                let basicFormatter = DateFormatter()
                basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                basicFormatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = basicFormatter.date(from: dateString) {
                    return date
                }
            }
            
            // 如果是时间戳
            if let timestamp = try? container.decode(Double.self, forKey: key) {
                return Date(timeIntervalSince1970: timestamp)
            }
            
            return nil
        }
}

// MARK: - WebDAV XML命名空间常量
struct WebDAVNamespace {
    static let dav = "DAV:"
    static let custom = "http://owncloud.org/ns"
}

// MARK: - WebDAV XML解析器主类
class WebDAVXMLParser: NSObject {
    // MARK: - 目录列表解析
    static func parseDirectoryListing(at path: String, xmlData: Data) -> Result<[WebDAVItem], Error> {
        let parser = XMLParser(data: xmlData)
        let delegate = DirectoryListingParserDelegate()
        delegate.basePath = path
        parser.delegate = delegate
        
        if parser.parse() {
            return .success(delegate.items)
        } else if let error = parser.parserError {
            return .failure(error)
        } else {
            return .failure(NSError(domain: "WebDAVParser", code: 0, userInfo: [NSLocalizedDescriptionKey: "未知解析错误"]))
        }
    }
    
    // MARK: - 属性解析
    static func parseProperties(xmlData: Data) -> Result<[String: Any], Error> {
        let parser = XMLParser(data: xmlData)
        let delegate = PropertiesParserDelegate()
        parser.delegate = delegate
        
        if parser.parse() {
            return .success(delegate.properties)
        } else if let error = parser.parserError {
            return .failure(error)
        } else {
            return .failure(NSError(domain: "WebDAVParser", code: 0, userInfo: [NSLocalizedDescriptionKey: "未知解析错误"]))
        }
    }
    
    // MARK: - 错误响应解析
    static func parseErrorResponse(xmlData: Data) -> String? {
        let parser = XMLParser(data: xmlData)
        let delegate = ErrorResponseParserDelegate()
        parser.delegate = delegate
        
        if parser.parse() {
            return delegate.errorDescription
        }
        return nil
    }
}

// MARK: - 目录列表解析代理
class DirectoryListingParserDelegate: NSObject, XMLParserDelegate {
    var items: [WebDAVItem] = []
    
    // 当前解析状态
    private var currentItem: WebDAVItem?
    private var currentElement = ""
    private var currentElementValue = ""
    private var currentHref = ""
    private var currentName = ""
    private var currentSize: Int64?
    private var currentContentType: String?
    private var currentEtag: String?
    private var currentModificationDate: Date?
    private var currentCreationDate: Date?
    private var isDirectory = false
    private var isParsingItem = false
    private var isInHrefElement = false
    private var isInResponseElement = false
    public var basePath: String?
    
    // 日期格式化器，支持多种格式
    private let dateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss z",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        ]
        
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "GMT")
            return formatter
        }
    }()
    
    // 开始解析元素
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = stripNamespace(from: elementName)
        currentElementValue = ""
        
        if currentElement == "response" {
            isInResponseElement = true
            resetItemData()
        } else if isInResponseElement {
            if currentElement == "href" {
                isInHrefElement = true
            } else if currentElement == "collection" {
                isDirectory = true
            }
        }
    }
    
    // 结束解析元素
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = stripNamespace(from: elementName)
        
        if element == "response" {
            // 完成一个项目的解析
            finalizeCurrentItem()
            isInResponseElement = false
        } else if isInResponseElement {
            switch element {
            case "href":
                isInHrefElement = false
                parseHrefValue(currentElementValue)
            case "displayname":
                if !currentElementValue.isEmpty {
                    currentName = currentElementValue
                }
            case "getcontentlength":
                if !isDirectory, let length = Int64(currentElementValue) {
                    currentSize = length
                }
            case "getcontenttype":
                if !currentElementValue.isEmpty {
                    currentContentType = currentElementValue
                }
            case "getetag":
                if !currentElementValue.isEmpty {
                    currentEtag = currentElementValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            case "getlastmodified":
                currentModificationDate = parseDate(currentElementValue)
            case "creationdate":
                currentCreationDate = parseDate(currentElementValue)
            default:
                break
            }
        }
    }
    
    // 获取元素内容
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentElementValue += string
    }
    
    // 解析错误处理
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        DLog("WebDAV XML解析错误: \(parseError.localizedDescription)")
    }
    
    // 辅助方法
    private func stripNamespace(from elementName: String) -> String {
        // 移除命名空间前缀，如"d:response" -> "response"
        if let colonIndex = elementName.firstIndex(of: ":") {
            return String(elementName[elementName.index(after: colonIndex)...])
        }
        return elementName
    }
    
    private func parseHrefValue(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 添加URL解码处理
        if let decodedValue = trimmedValue.removingPercentEncoding {
            currentHref = decodedValue
        } else {
            currentHref = trimmedValue
        }
        
        // 如果没有displayname，从href中提取文件名
        if currentName.isEmpty {
            var path = currentHref // 使用解码后的值
            
            // 移除末尾的斜杠并标记为目录
            if path.hasSuffix("/") {
                path = String(path.dropLast())
                isDirectory = true
            }
            
            // 提取最后一个路径部分作为名称
            if let lastComponent = path.components(separatedBy: "/").last,
               !lastComponent.isEmpty && lastComponent != ".." && lastComponent != "." {
                currentName = lastComponent
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let trimmedString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 尝试所有支持的日期格式
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmedString) {
                return date
            }
        }
        
        DLog("无法解析日期: \(trimmedString)")
        return nil
    }
    
    private func resetItemData() {
        currentName = ""
        currentHref = ""
        currentSize = nil
        currentContentType = nil
        currentEtag = nil
        currentModificationDate = nil
        currentCreationDate = nil
        isDirectory = false
    }
    
    private func finalizeCurrentItem() {
        guard !currentName.isEmpty && currentName != ".." && currentName != "." else { return }
        // 2. 过滤掉与基础路径相同的条目（父目录自身）
//        if let basePath = basePath {
//            // 标准化路径进行比较
//            let normalizedBasePath = basePath.trimmingCharacters(in: .init(charactersIn: "/"))
//            let normalizedCurrentPath = currentHref.trimmingCharacters(in: .init(charactersIn: "/"))
//            
//            // 如果当前路径就是基础路径，跳过（这就是父目录自身）
//            if normalizedCurrentPath == normalizedBasePath {
//                return
//            }
//            
//            // 额外检查：如果路径结构表明这是父目录的重复条目
//            if let lastSlashIndex = currentHref.lastIndex(of: "/"),
//               let baseLastSlashIndex = basePath.lastIndex(of: "/") {
//                // 提取文件名部分
//                let currentFileName = String(currentHref[lastSlashIndex...].dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
//                let basePathName = String(basePath[baseLastSlashIndex...].dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
//                
//                // 如果文件名与基础路径名称相同，可能是重复的父目录条目
//                if currentFileName == basePathName && currentHref != basePath {
//                    return
//                }
//            }
//        }
        
        // 构建完整路径（保留原始路径结构）
        var fullPath = currentHref
        
        // 创建并添加项目
        let item = WebDAVItem(
            name: currentName,
            path: fullPath,
            type: isDirectory ? .directory : .file,
            size: currentSize,
            modificationDate: currentModificationDate,
            creationDate: currentCreationDate,
            contentType: currentContentType,
            etag: currentEtag
        )
        
        // 避免重复项
        if !items.contains(item) {
            items.append(item)
        }
    }
}

// MARK: - 属性解析代理
class PropertiesParserDelegate: NSObject, XMLParserDelegate {
    var properties: [String: Any] = [:]
    
    private var currentPropertyName = ""
    private var currentPropertyValue = ""
    private var isParsingProperty = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let element = stripNamespace(from: elementName)
        
        if isPropertyElement(elementName, namespaceURI: namespaceURI) {
            currentPropertyName = element
            currentPropertyValue = ""
            isParsingProperty = true
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = stripNamespace(from: elementName)
        
        if isParsingProperty && currentPropertyName == element {
            properties[currentPropertyName] = currentPropertyValue
            isParsingProperty = false
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isParsingProperty {
            currentPropertyValue += string
        }
    }
    
    private func stripNamespace(from elementName: String) -> String {
        if let colonIndex = elementName.firstIndex(of: ":") {
            return String(elementName[elementName.index(after: colonIndex)...])
        }
        return elementName
    }
    
    private func isPropertyElement(_ elementName: String, namespaceURI: String?) -> Bool {
        // 检查是否是属性元素
        return namespaceURI == WebDAVNamespace.dav && 
               !elementName.contains("prop") && 
               !elementName.contains("response")
    }
}

// MARK: - 错误响应解析代理
class ErrorResponseParserDelegate: NSObject, XMLParserDelegate {
    var errorDescription: String?
    
    private var currentElement = ""
    private var isInErrorElement = false
    private var isInDescriptionElement = false
    private var currentDescription = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let element = stripNamespace(from: elementName)
        currentElement = element
        
        if element == "error" {
            isInErrorElement = true
        } else if isInErrorElement && element == "description" {
            isInDescriptionElement = true
            currentDescription = ""
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = stripNamespace(from: elementName)
        
        if element == "error" {
            isInErrorElement = false
        } else if isInDescriptionElement && element == "description" {
            isInDescriptionElement = false
            if !currentDescription.isEmpty {
                errorDescription = currentDescription
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInDescriptionElement {
            currentDescription += string
        }
    }
    
    private func stripNamespace(from elementName: String) -> String {
        if let colonIndex = elementName.firstIndex(of: ":") {
            return String(elementName[elementName.index(after: colonIndex)...])
        }
        return elementName
    }
}

// MARK: - 使用示例
extension WebDAVXMLParser {
    static func exampleUsage() {
        // 假设有从WebDAV服务器获取的数据
        /*
        // 1. 解析目录列表
        let client = WebDAVClient(...)
        client.fetchDirectoryContents(path: "/documents") { result in
            switch result {
            case .success(let xmlData):
                let parseResult = WebDAVXMLParser.parseDirectoryListing(xmlData: xmlData)
                switch parseResult {
                case .success(let items):
                    // 成功解析目录项
                    for item in items {
                        DLog("\(item.type == .directory ? "目录" : "文件"): \(item.name), 大小: \(item.size ?? 0)字节")
                    }
                case .failure(let error):
                    DLog("解析失败: \(error)")
                }
            case .failure(let error):
                DLog("获取目录失败: \(error)")
            }
        }
        
        // 2. 解析属性
        client.fetchProperties(forPath: "/documents/file.txt") { result in
            switch result {
            case .success(let xmlData):
                if case .success(let properties) = WebDAVXMLParser.parseProperties(xmlData: xmlData) {
                    DLog("文件属性: \(properties)")
                }
            case .failure(let error):
                DLog("获取属性失败: \(error)")
            }
        }
        
        // 3. 解析错误响应
        client.performRequest(...) { result in
            switch result {
            case .failure(let error):
                if let xmlData = error.responseData {
                    if let errorMessage = WebDAVXMLParser.parseErrorResponse(xmlData: xmlData) {
                        DLog("服务器错误: \(errorMessage)")
                    } else {
                        DLog("请求失败: \(error.localizedDescription)")
                    }
                }
            default:
                break
            }
        }
        */
    }
}

// MARK: - 使用示例
extension WebDAVItem {
    // 示例：从JSON字符串解码
    static func fromJSON(jsonString: String) -> Result<WebDAVItem, Error> {
        do {
            let data = Data(jsonString.utf8)
            let decoder = JSONDecoder()
            let item = try decoder.decode(WebDAVItem.self, from: data)
            return .success(item)
        } catch {
            return .failure(error)
        }
    }
    
    // 示例：编码为JSON字符串
    func toJSONString() -> Result<String, Error> {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "WebDAVItem", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法将数据转换为字符串"])
            }
            return .success(jsonString)
        } catch {
            return .failure(error)
        }
    }
}
