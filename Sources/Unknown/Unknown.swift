import Foundation
import AspectAnalyzer
import OllamaKit
import Logging
import Remark
import SwiftSoup
import NaturalLanguage

/// Represents an optimized understanding of an unknown concept or term
public struct Understanding: Sendable {
    /// The original query or term to understand
    public let query: String
    
    /// Core definition or explanation
    public let definition: String
    
    /// Category or type of the concept
    public let category: String
    
    /// Related concepts and terms
    public let concepts: [String]
    
    /// Confidence score of the understanding
    public let confidence: Float
    
    public init(
        query: String,
        definition: String,
        category: String,
        concepts: [String],
        confidence: Float
    ) {
        self.query = query
        self.definition = definition
        self.category = category
        self.concepts = concepts
        self.confidence = confidence
    }
}

// MARK: - CustomStringConvertible
extension Understanding: CustomStringConvertible {
    public var description: String {
        var result = """
        Definition: \(definition)
        Category: \(category)
        """
        
        if !concepts.isEmpty {
            result += "\nRelated Concepts: \(concepts.joined(separator: ", "))"
        }
        
        result += "\nConfidence: \(String(format: "%.1f%%", confidence * 100))"
        
        return result
    }
}

/// Errors that can occur during comprehension
public enum ComprehensionError: Error {
    /// Failed to perform web search or retrieve results
    case searchFailed(String)
    /// Invalid URL construction or formatting
    case invalidURL(String)
    /// Failed to parse search results or concept data
    case parsingFailed(String)
    /// Failed to extract meaningful content
    case contentExtractionFailed(String)
    /// AI model related errors
    case modelError(String)
    /// General errors
    case generalError(String)
}

/// A type for comprehending unknown terms or concepts
public struct Unknown: Sendable {
    /// Configuration options for unknown term analysis
    public struct Configuration: Sendable {
        /// The model to use for analysis
        public let model: String
        /// Maximum number of sources to consider
        public let maxSources: Int
        /// Minimum confidence threshold
        public let minConfidence: Float
        /// Maximum tokens for context
        public let maxContextTokens: Int
        /// Search result limit
        public let searchLimit: Int
        
        public init(
            model: String = "llama3.2:latest",
            maxSources: Int = 5,
            minConfidence: Float = 0.7,
            maxContextTokens: Int = 1024,
            searchLimit: Int = 10
        ) {
            self.model = model
            self.maxSources = maxSources
            self.minConfidence = minConfidence
            self.maxContextTokens = maxContextTokens
            self.searchLimit = searchLimit
        }
        
        public static let `default` = Configuration()
    }
    
    private let query: String
    private let configuration: Configuration
    private let logger: Logger
    private let ollamaKit: OllamaKit
    private let aspectAnalyzer: AspectAnalyzer
    
    /// Initialize with a query to comprehend
    /// - Parameters:
    ///   - query: The query containing unknown terms to understand
    ///   - configuration: Configuration options for the analysis
    ///   - logger: Optional logger for debugging
    public init(
        _ query: String,
        configuration: Configuration = .default,
        logger: Logger? = nil
    ) {
        self.query = query
        self.configuration = configuration
        self.logger = logger ?? Logger(label: "Unknown")
        self.ollamaKit = OllamaKit()
        self.aspectAnalyzer = AspectAnalyzer(model: configuration.model)
    }
    
    /// Comprehend the unknown terms in the query
    /// - Returns: An Understanding of the unknown terms
    public func comprehend() async throws -> Understanding {
        logger.debug("Starting comprehension", metadata: [
            "query": .string(query)
        ])
        
        // Validate input
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ComprehensionError.generalError("Empty query provided")
        }
        
        do {
            // 1. Extract keywords and analyze
            let keywords = try await extractAndAnalyzeKeywords(query)
            
            // 2. Perform search and gather information
            let searchResults = try await performSearch(keywords: keywords)
            
            // 3. Analyze gathered information
            return try await analyzeInformation(
                query: query,
                keywords: keywords,
                searchResults: searchResults
            )
        } catch {
            logger.error("Comprehension failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
    
    /// Static method to directly comprehend a query
    /// - Parameters:
    ///   - query: The query to comprehend
    ///   - configuration: Optional configuration for the analysis
    /// - Returns: An Understanding of the unknown terms
    public static func comprehend(
        _ query: String,
        configuration: Configuration = .default
    ) async throws -> Understanding {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(query)
        let language = recognizer.dominantLanguage?.rawValue
        let unknown = Unknown(query, configuration: configuration)
        return try await unknown.comprehend()
    }
    
    // MARK: - Private Methods
    
    /// Extracts and analyzes keywords from the query
    private func extractAndAnalyzeKeywords(_ query: String) async throws -> [String] {
        let analysis = try await aspectAnalyzer.extractKeywords(query)
        logger.debug("Extracted keywords", metadata: [
            "keywords": .string(analysis.keywords.joined(separator: ", "))
        ])
        return analysis.keywords
    }
    
    /// Performs search and gathers information
    private func performSearch(keywords: [String]) async throws -> String {
        let searchQuery = keywords.joined(separator: " ")
        return try await searchAndParse(searchQuery)
    }
    
    /// Performs web search and parses results
    internal func searchAndParse(_ query: String) async throws -> String {
        let url = try buildSearchURL(for: query)
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ComprehensionError.searchFailed("Invalid response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ComprehensionError.searchFailed("HTTP \(httpResponse.statusCode)")
        }
        
        let encoding = detectEncoding(from: httpResponse, data: data)
        guard let html = String(data: data, encoding: encoding) else {
            throw ComprehensionError.contentExtractionFailed("Failed to decode content")
        }
        return try SwiftSoup.parse(html).text()
    }
    
    /// Builds search URL with appropriate parameters
    private func buildSearchURL(for query: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: String(configuration.searchLimit)),
            URLQueryItem(name: "ie", value: "utf8"),
            URLQueryItem(name: "oe", value: "utf8")
        ]
        if let languageCode = Locale.current.language.languageCode?.identifier {
            components.queryItems?.append(URLQueryItem(name: "hl", value: languageCode))
        }
        guard let url = components.url else {
            throw ComprehensionError.invalidURL("Could not construct search URL")
        }
        return url
    }
    
    /// Analyzes gathered information and creates Understanding
    internal func analyzeInformation(
        query: String,
        keywords: [String],
        searchResults: String
    ) async throws -> Understanding {
        let data = OKChatRequestData(
            model: configuration.model,
            messages: [
                .system("""
                    Analyze the provided search results and create a comprehensive understanding.
                    Result must be in the **same language as the input query**
                    Respond in the following JSON format:
                    ```json
                    {
                        "definition": "Clear and concise definition",
                        "category": "General category or type",
                        "concepts": ["concept1", "concept2"],
                        "confidence": float between 0-1
                    }
                    ```
                    """),
                .user("""
                    Query: \(query)
                    Keywords: \(keywords.joined(separator: ", "))
                    
                    Search Results:
                    \(searchResults)
                    """)
            ]
        ) { options in
            options.temperature = 0
            options.topP = 1
            options.topK = 1
        }
        struct AnalysisResponse: Codable {
            let definition: String
            let category: String
            let concepts: [String]
            let confidence: Float
        }
        var response = ""
        for try await chunk in ollamaKit.chat(data: data) {
            response += chunk.message?.content ?? ""
        }
        let jsonResponse = response.extractedCodeBlock()
        guard let jsonData = jsonResponse.data(using: .utf8) else {
            throw ComprehensionError.parsingFailed("Failed to convert response to data")
        }
        let result = try JSONDecoder().decode(AnalysisResponse.self, from: jsonData)
        return Understanding(
            query: query,
            definition: result.definition,
            category: result.category,
            concepts: result.concepts,
            confidence: result.confidence
        )
    }
    
    /// Extracts URLs from search results
    private func extractURLs(from searchResults: String) throws -> [URL] {
        let pattern = #"https?://[^\s<>\"]+"#
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(
            in: searchResults,
            range: NSRange(searchResults.startIndex..., in: searchResults)
        )
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: searchResults) else { return nil }
            let urlString = String(searchResults[range])
            return URL(string: urlString)
        }
    }
    
    /// Detects content encoding from HTTP response and meta tags
    private func detectEncoding(from response: HTTPURLResponse, data: Data) -> String.Encoding {
        // Check Content-Type header
        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           let charset = contentType.components(separatedBy: "charset=").last?.trimmingCharacters(in: .whitespaces) {
            switch charset.lowercased() {
            case "shift_jis", "shift-jis", "shiftjis":
                return .shiftJIS
            case "euc-jp":
                return .japaneseEUC
            case "iso-2022-jp":
                return .iso2022JP
            case "utf-8":
                return .utf8
            default:
                break
            }
        }
        
        // Check meta tags
        if let content = String(data: data, encoding: .ascii),
           let metaCharset = content.range(of: "charset=", options: [.caseInsensitive]) {
            let startIndex = metaCharset.upperBound
            let endIndex = content[startIndex...].firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" }) ?? content.endIndex
            let charset = content[startIndex..<endIndex].lowercased()
            
            switch charset {
            case "shift_jis", "shift-jis", "shiftjis":
                return .shiftJIS
            case "euc-jp":
                return .japaneseEUC
            case "iso-2022-jp":
                return .iso2022JP
            case "utf-8":
                return .utf8
            default:
                break
            }
        }
        
        return .utf8
    }
}
