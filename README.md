# Unknown

Unknown is a Swift package that helps comprehend and analyze unfamiliar terms or concepts by leveraging web search and language models.

## Features

- 🔍 Automated web search and content extraction
- 🤖 AI-powered concept analysis using language models
- 📊 Confidence scoring for results
- 🌐 Multi-language support
- 📝 Detailed analysis including definitions, categories, and related concepts
- 📋 Customizable search parameters
- 🪵 Optional logging support


## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/Unknown.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
do {
    let understanding = try await Unknown("quantum entanglement").comprehend()
    print(understanding.definition)
    print(understanding.category)
    print(understanding.concepts)
    print(understanding.confidence)
} catch {
    print("Comprehension failed: \(error)")
}
```

### With Custom Configuration

```swift
// Create a custom logger
var logger = Logger(label: "com.example.unknown")
logger.logLevel = .debug

// Configure Unknown with custom settings
let config = Unknown.Configuration(
    model: "custom-model",
    searchLimit: 20,
    logger: logger
)

let unknown = Unknown("quantum entanglement", configuration: config)
let understanding = try await unknown.comprehend()
```

### Static Usage

```swift
let understanding = try await Unknown.comprehend("quantum entanglement")
```

## Understanding Object

The comprehension result is returned as an `Understanding` object with the following properties:

```swift
public struct Understanding {
    public let query: String       // Original query
    public let definition: String  // Core definition
    public let category: String    // Concept category
    public let concepts: [String]  // Related concepts
    public let confidence: Float   // Confidence score (0-1)
}
```

## Configuration

Customize the behavior using `Configuration`:

```swift
public struct Configuration {
    public let model: String       // Language model to use
    public let searchLimit: Int    // Max search results
    public let logger: Logger?     // Optional logger
}
```

## Error Handling

Unknown defines several error types through `ComprehensionError`:

```swift
public enum ComprehensionError: Error {
    case searchFailed(String)
    case invalidURL(String)
    case parsingFailed(String)
    case contentExtractionFailed(String)
    case generalError(String)
}
```


## License

Unknown is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Author

[@1amageek](https://github.com/1amageek)
