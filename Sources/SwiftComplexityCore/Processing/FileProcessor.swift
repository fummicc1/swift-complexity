import Foundation
import SwiftParser
import SwiftSyntax

public protocol FileProcessing {
  func processFiles(at paths: [String], options: ProcessingOptions) async throws
    -> [ComplexityResult]
}

public struct ProcessingOptions: Sendable {
  public let recursive: Bool
  public let excludePatterns: [String]
  public let verbose: Bool

  public init(recursive: Bool = false, excludePatterns: [String] = [], verbose: Bool = false) {
    self.recursive = recursive
    self.excludePatterns = excludePatterns
    self.verbose = verbose
  }
}

public enum FileProcessorError: Error, LocalizedError {
  case invalidPath(String)
  case fileNotReadable(String)
  case parseError(String, underlying: Error)
  case noSwiftFiles

  public var errorDescription: String? {
    switch self {
    case .invalidPath(let path):
      return "Invalid path: \(path)"
    case .fileNotReadable(let path):
      return "Cannot read file: \(path)"
    case .parseError(let path, let underlying):
      return "Parse error in \(path): \(underlying.localizedDescription)"
    case .noSwiftFiles:
      return "No Swift files found"
    }
  }
}

public actor FileProcessor: FileProcessing {
  private let analyzer: ComplexityAnalyzer
  private let fileManager: FileManager

  public init(analyzer: ComplexityAnalyzer = ComplexityAnalyzer()) {
    self.analyzer = analyzer
    self.fileManager = FileManager.default
  }

  public func processFiles(at paths: [String], options: ProcessingOptions) async throws
    -> [ComplexityResult]
  {
    let swiftFiles = try await collectSwiftFiles(from: paths, options: options)

    guard !swiftFiles.isEmpty else {
      throw FileProcessorError.noSwiftFiles
    }

    if options.verbose {
      print("Found \(swiftFiles.count) Swift files to analyze")
    }

    return try await withThrowingTaskGroup(of: ComplexityResult?.self) { group in
      var results: [ComplexityResult] = []

      for filePath in swiftFiles {
        group.addTask {
          try await self.processFile(at: filePath, verbose: options.verbose)
        }
      }

      for try await result in group {
        if let result = result {
          results.append(result)
        }
      }

      return results.sorted { $0.filePath < $1.filePath }
    }
  }

  private func collectSwiftFiles(from paths: [String], options: ProcessingOptions) async throws
    -> [String]
  {
    var allSwiftFiles: Set<String> = []

    for path in paths {
      let resolvedPath = resolvePath(path)
      let swiftFiles = try await findSwiftFiles(
        at: resolvedPath, recursive: options.recursive)
      let filteredFiles = filterFiles(swiftFiles, excludePatterns: options.excludePatterns)
      allSwiftFiles.formUnion(filteredFiles)
    }

    return Array(allSwiftFiles).sorted()
  }

  private func findSwiftFiles(at path: String, recursive: Bool) async throws -> [String] {
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
      throw FileProcessorError.invalidPath(path)
    }

    if isDirectory.boolValue {
      return try await findSwiftFilesInDirectory(path, recursive: recursive)
    } else {
      guard path.hasSuffix(".swift") else {
        return []
      }
      return [path]
    }
  }

  private func findSwiftFilesInDirectory(_ directory: String, recursive: Bool) async throws
    -> [String]
  {
    return try await withCheckedThrowingContinuation { continuation in
      Task.detached {
        do {
          let result = try Self.findSwiftFilesSync(
            directory: directory, recursive: recursive, fileManager: FileManager.default
          )
          continuation.resume(returning: result)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private static func findSwiftFilesSync(
    directory: String, recursive: Bool, fileManager: FileManager
  ) throws -> [String] {
    let url = URL(fileURLWithPath: directory)
    let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]

    guard
      let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: resourceKeys,
        options: recursive ? [] : [.skipsSubdirectoryDescendants],
        errorHandler: { _, error in
          print("Warning: Error enumerating \(url): \(error)")
          return true
        }
      )
    else {
      throw FileProcessorError.invalidPath(directory)
    }

    var swiftFiles: [String] = []

    for case let fileURL as URL in enumerator {
      let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))

      if resourceValues.isRegularFile == true && fileURL.pathExtension == "swift" {
        swiftFiles.append(fileURL.path)
      }
    }

    return swiftFiles
  }

  private func filterFiles(_ files: [String], excludePatterns: [String]) -> [String] {
    guard !excludePatterns.isEmpty else { return files }

    return files.filter { filePath in
      !excludePatterns.contains { pattern in
        filePath.range(of: pattern, options: .regularExpression) != nil
      }
    }
  }

  private func processFile(at filePath: String, verbose: Bool) async throws -> ComplexityResult? {
    do {
      if verbose {
        print("Analyzing: \(filePath)")
      }

      let fileContent = try String(contentsOfFile: filePath)
      let sourceFile = Parser.parse(source: fileContent)

      return try await analyzer.analyze(sourceFile: sourceFile, filePath: filePath)

    } catch {
      if verbose {
        print("Error processing \(filePath): \(error)")
      }
      throw FileProcessorError.parseError(filePath, underlying: error)
    }
  }

  private func resolvePath(_ path: String) -> String {
    if path.hasPrefix("/") {
      return path
    }

    let currentDirectory = fileManager.currentDirectoryPath
    return (currentDirectory as NSString).appendingPathComponent(path)
  }
}
