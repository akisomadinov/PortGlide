import Foundation

struct CommandResult {
    let status: Int32
    let output: String
}

enum CommandError: LocalizedError {
    case failedToLaunch(String)
    case nonZeroExit(executable: String, status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .failedToLaunch(message):
            return "Не удалось запустить системную команду: \(message)"
        case let .nonZeroExit(executable, status, output):
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "Команда \(executable) завершилась с кодом \(status)."
                : "\(detail) (код \(status))"
        }
    }
}

final class CommandRunner {
    func run(_ executable: String, arguments: [String], requireSuccess: Bool = true) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice
            process.terminationHandler = { finished in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                let result = CommandResult(status: finished.terminationStatus, output: output)
                if requireSuccess && finished.terminationStatus != 0 {
                    continuation.resume(throwing: CommandError.nonZeroExit(
                        executable: executable,
                        status: finished.terminationStatus,
                        output: output
                    ))
                } else {
                    continuation.resume(returning: result)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: CommandError.failedToLaunch(error.localizedDescription))
            }
        }
    }

    func launch(
        _ executable: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
            return process
        } catch {
            throw CommandError.failedToLaunch(error.localizedDescription)
        }
    }
}
