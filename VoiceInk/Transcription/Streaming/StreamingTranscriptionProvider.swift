import Foundation

/// Events emitted by a streaming transcription provider
enum StreamingTranscriptionEvent {
    case sessionStarted
    case partial(text: String)
    case committed(text: String)
    case error(Error)
}

/// Errors specific to streaming transcription
enum StreamingTranscriptionError: LocalizedError {
    case missingAPIKey
    case connectionFailed(String)
    case timeout
    case serverError(String)
    case notConnected
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return String(localized: "API key not configured for streaming transcription")
        case .connectionFailed(let message):
            return String(format: String(localized: "Streaming connection failed: %@"), message)
        case .timeout:
            return String(localized: "Streaming transcription timed out waiting for final result")
        case .serverError(let message):
            return String(format: String(localized: "Streaming server error: %@"), message)
        case .notConnected:
            return String(localized: "Not connected to streaming transcription service")
        case .audioConversionFailed:
            return String(localized: "Failed to convert audio chunk for streaming")
        }
    }
}

/// Protocol for streaming transcription providers.
protocol StreamingTranscriptionProvider: AnyObject {
    /// Connect to the streaming transcription endpoint.
    ///
    /// - Parameters:
    ///   - language: The primary selected language code (or "auto").
    ///   - languages: The full validated list of selected language codes. Used by
    ///     on-device providers that can constrain decoding by writing script (e.g.
    ///     Parakeet v3's union script filter). Cloud and single-script providers may
    ///     ignore this and rely on `language`; the default forwarding implementation
    ///     below keeps them compiling and behaving unchanged.
    func connect(model: any TranscriptionModel, language: String?, languages: [String]) async throws

    /// Single-language connect. This is a requirement (no default) so that every
    /// provider supplies a concrete implementation — the `languages` default below
    /// forwards here via dynamic dispatch, which is only safe if a real witness
    /// always exists. (A default here would let the two defaults forward to each
    /// other and recurse infinitely for any provider that overrides neither.)
    func connect(model: any TranscriptionModel, language: String?) async throws

    /// Send a chunk of raw PCM audio data (16-bit, 16kHz, mono, little-endian)
    func sendAudioChunk(_ data: Data) async throws

    /// Commit the current audio buffer to finalize transcription
    func commit() async throws

    /// Disconnect from the streaming endpoint
    func disconnect() async

    /// Stream of transcription events from the provider
    var transcriptionEvents: AsyncStream<StreamingTranscriptionEvent> { get }
}

extension StreamingTranscriptionProvider {
    /// Default for the multi-language form: ignore the full list and forward to the
    /// single-language `connect`, which is a protocol requirement and therefore
    /// dynamically dispatches to each provider's concrete implementation. Providers
    /// that don't need the script set (all cloud providers, Nemotron, Unified) keep
    /// their existing `connect(model:language:)` and inherit this for free.
    func connect(model: any TranscriptionModel, language: String?, languages: [String]) async throws {
        try await connect(model: model, language: language)
    }
}
