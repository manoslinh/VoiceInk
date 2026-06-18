import Foundation

struct TranscriptionRequestContext {
    /// The single language code for engines that accept only one (the primary
    /// selection, or "auto" when multiple languages are selected).
    let language: String?
    /// The full validated selection. Engines that can constrain by it (Parakeet
    /// v3) use this; others fall back to `language`. Defaults to `[language]`.
    let languages: [String]
    let prompt: String?

    init(language: String?, languages: [String]? = nil, prompt: String?) {
        self.language = language
        self.languages = languages ?? language.map { [$0] } ?? []
        self.prompt = prompt
    }

    static var currentDefaults: TranscriptionRequestContext {
        let stored = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "auto"
        let parsed = TranscriptionLanguageSupport.parseSelectedLanguages(stored)
        let languages = parsed.isEmpty ? ["auto"] : parsed
        let primary = languages.count == 1 ? languages[0] : "auto"
        return TranscriptionRequestContext(
            language: primary,
            languages: languages,
            prompt: UserDefaults.standard.string(forKey: "TranscriptionPrompt")
        )
    }
}

/// A protocol defining the interface for a transcription service.
/// This allows for a unified way to handle both local and cloud-based transcription models.
protocol TranscriptionService {
    /// Transcribes the audio from a given file URL.
    ///
    /// - Parameters:
    ///   - audioURL: The URL of the audio file to transcribe.
    ///   - model: The `TranscriptionModel` to use for transcription. This provides context about the provider (local, OpenAI, etc.).
    /// - Returns: The transcribed text as a `String`.
    /// - Throws: An error if the transcription fails.
    func transcribe(audioURL: URL, model: any TranscriptionModel, context: TranscriptionRequestContext) async throws -> String
}

extension TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        try await transcribe(audioURL: audioURL, model: model, context: .currentDefaults)
    }
}
