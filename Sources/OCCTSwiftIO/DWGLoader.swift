// DWGLoader.swift
// OCCTSwiftIO
//
// Reads DWG (AutoCAD's native drawing format) into the same SwiftDXF entity model `DXFLoader`
// produces. DWG is a closed binary format with no Swift reader, so the reading is done by the
// `dwg2dxf` tool in `Tools/dwg2dxf` (built on the acadrust library), which this loader runs and
// whose DXF output it parses with SwiftDXF. The Swift package gains no dependency.
//
// A conversion is a step someone may later have to account for, so each one records what was
// converted and what converted it: the source's SHA-256 and DWG version code, and the converter's
// own version line.
//
// macOS only: it runs a subprocess. Other platforms get `DWGError.unsupportedPlatform`.

import Foundation
import SwiftDXF

#if canImport(CryptoKit)
    import CryptoKit
#endif

public enum DWGLoader {

    /// The environment variable naming the `dwg2dxf` executable.
    public static let converterEnvironmentVariable = "OCCTSWIFTIO_DWG2DXF"

    /// One DWG read: the drawing, and the record of how it was obtained.
    public struct Conversion: Sendable {
        /// The drawing, in the same entity model `DXFLoader.readEntities` returns.
        public let drawing: DXF.Drawing
        /// The converter's `--version` line, such as `dwg2dxf 0.1.0 acadrust 0.6.8`.
        public let converter: String
        /// SHA-256 of the source file, lowercase hex.
        public let sourceSHA256: String
        /// The source's DWG version code from its first six bytes, such as `AC1032`.
        public let sourceVersion: String
        /// Anything about the result a caller should not miss.
        public let warnings: [String]
    }

    public enum DWGError: Error, CustomStringConvertible {
        /// No `dwg2dxf` executable was given, named by the environment, or found on `PATH`.
        case converterNotFound
        /// The file does not start with a DWG version code.
        case notADWG(String)
        /// The converter ran and failed.
        case conversionFailed(status: Int32, message: String)
        /// Subprocesses are not available on this platform.
        case unsupportedPlatform

        public var description: String {
            switch self {
            case .converterNotFound:
                return
                    "dwg2dxf was not found. Build it from Tools/dwg2dxf and put it on PATH, or set "
                    + "\(DWGLoader.converterEnvironmentVariable) to its path."
            case .notADWG(let header):
                return "not a DWG file: it starts with \"\(header)\", not a DWG version code"
            case .conversionFailed(let status, let message):
                return "dwg2dxf failed (exit \(status)): \(message)"
            case .unsupportedPlatform:
                return "reading DWG needs a subprocess, which this platform does not allow"
            }
        }
    }

    /// The `dwg2dxf` executable: `explicit` if given, else the environment variable, else `PATH`.
    public static func locateConverter(explicit: URL? = nil) -> URL? {
        let manager = FileManager.default
        if let explicit { return manager.isExecutableFile(atPath: explicit.path) ? explicit : nil }
        let environment = ProcessInfo.processInfo.environment
        if let named = environment[converterEnvironmentVariable],
            manager.isExecutableFile(atPath: named)
        {
            return URL(fileURLWithPath: named)
        }
        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(
                "dwg2dxf")
            if manager.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// Read a DWG file into the SwiftDXF entity model, with the record of the conversion.
    public static func readEntities(from url: URL, converter: URL? = nil) throws -> Conversion {
        #if os(macOS)
            guard let executable = locateConverter(explicit: converter) else {
                throw DWGError.converterNotFound
            }
            let source = try Data(contentsOf: url)
            let header = String(decoding: source.prefix(6), as: UTF8.self)
            guard header.hasPrefix("AC") else { throw DWGError.notADWG(header) }

            let version = try run(executable, ["--version"])
            guard version.status == 0 else {
                throw DWGError.conversionFailed(status: version.status, message: version.error)
            }
            let converted = try run(executable, [url.path, "-"])
            guard converted.status == 0 else {
                throw DWGError.conversionFailed(status: converted.status, message: converted.error)
            }
            let drawing = try DXF.read(data: converted.output)

            var warnings: [String] = []
            if drawing.entities.isEmpty {
                warnings.append("the converted drawing has no entities the reader recognises")
            }
            return Conversion(
                drawing: drawing,
                converter: String(decoding: version.output, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                sourceSHA256: sha256(source), sourceVersion: header, warnings: warnings)
        #else
            throw DWGError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
        private static func run(
            _ executable: URL, _ arguments: [String]
        ) throws -> (status: Int32, output: Data, error: String) {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            let output = Pipe()
            let error = Pipe()
            process.standardOutput = output
            process.standardError = error
            try process.run()
            // Read to end before waiting: a full pipe would otherwise block the converter.
            let outputData = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = error.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (
                process.terminationStatus, outputData,
                String(decoding: errorData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    #endif

    private static func sha256(_ data: Data) -> String {
        #if canImport(CryptoKit)
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
            return ""
        #endif
    }
}
