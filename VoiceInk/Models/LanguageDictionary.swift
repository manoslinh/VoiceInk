import Foundation

enum TranscriptionLanguageSupport {
    private static let assemblyAIRealtimeLanguageCodes = ["en", "es", "de", "fr", "pt", "it"]

    private static let assemblyAIBatchLanguageCodes = [
        "en", "en_au", "en_uk", "en_us", "es", "fr", "de", "it", "pt", "nl",
        "hi", "ja", "zh", "fi", "ko", "pl", "ru", "tr", "uk", "vi", "af",
        "sq", "am", "ar", "hy", "as", "az", "ba", "eu", "be", "bn", "bs",
        "br", "bg", "my", "ca", "hr", "cs", "da", "et", "fo", "gl", "ka",
        "el", "gu", "ht", "ha", "haw", "he", "hu", "is", "id", "jw", "kn",
        "kk", "km", "lo", "la", "lv", "ln", "lt", "lb", "mk", "mg", "ms",
        "ml", "mt", "mi", "mr", "mn", "ne", "no", "nn", "oc", "pa", "ps",
        "fa", "ro", "sa", "sr", "sn", "sd", "si", "sk", "sl", "so", "su",
        "sw", "sv", "de_ch", "tl", "tg", "ta", "tt", "te", "th", "bo",
        "tk", "ur", "uz", "cy", "yi", "yo"
    ]

    static func languages(for model: any TranscriptionModel, realtimeEnabled: Bool? = nil) -> [String: String] {
        if model.provider == .assemblyAI {
            return assemblyAILanguages(usesRealtime: assemblyAIUsesRealtime(for: model, realtimeEnabled: realtimeEnabled))
        }

        return model.supportedLanguages
    }

    static func validLanguageOrFallback(_ language: String?, for model: any TranscriptionModel, realtimeEnabled: Bool? = nil) -> String {
        let languages = languages(for: model, realtimeEnabled: realtimeEnabled)

        if let language, languages[language] != nil {
            return language
        }

        if languages["auto"] != nil {
            return "auto"
        }

        if languages["en-US"] != nil {
            return "en-US"
        }

        if languages["en"] != nil {
            return "en"
        }

        return languages.keys.sorted { lhs, rhs in
            languages[lhs, default: lhs] < languages[rhs, default: rhs]
        }.first ?? "en"
    }

    // MARK: - Multiple language selection

    /// A stored language value may hold a comma-separated list (e.g. "en,el").
    /// Splits it into individual, trimmed, non-empty codes preserving order.
    static func parseSelectedLanguages(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Whether a multi-language *restriction* is meaningful for this model.
    /// Only FluidAudio Parakeet v3 can constrain decoding by script; every
    /// other engine accepts a single language or full auto-detect.
    static func supportsMultipleLanguages(for model: any TranscriptionModel) -> Bool {
        guard model.isMultilingualModel, model.provider == .fluidAudio else { return false }
        return FluidAudioModelManager.supportsScriptFiltering(named: model.name)
    }

    /// Validated, de-duplicated, order-preserving list of selected languages for
    /// a model. "auto" collapses to ["auto"]; an empty/invalid selection falls
    /// back to `validLanguageOrFallback`.
    static func validLanguages(_ raw: String?, for model: any TranscriptionModel, realtimeEnabled: Bool? = nil) -> [String] {
        let supported = languages(for: model, realtimeEnabled: realtimeEnabled)
        let parsed = parseSelectedLanguages(raw)

        if parsed.contains("auto"), supported["auto"] != nil {
            return ["auto"]
        }

        var seen = Set<String>()
        let valid = parsed.filter { supported[$0] != nil && seen.insert($0).inserted }
        if !valid.isEmpty {
            return valid
        }

        return [validLanguageOrFallback(raw, for: model, realtimeEnabled: realtimeEnabled)]
    }

    /// Comma-joined form of `validLanguages`, suitable for storage.
    static func validLanguagesString(_ raw: String?, for model: any TranscriptionModel, realtimeEnabled: Bool? = nil) -> String {
        validLanguages(raw, for: model, realtimeEnabled: realtimeEnabled).joined(separator: ",")
    }

    /// The single language code handed to engines that take only one value.
    /// A single selection is passed through; multiple selections become "auto"
    /// (when supported) so no one language is wrongly forced.
    static func primaryLanguage(_ raw: String?, for model: any TranscriptionModel, realtimeEnabled: Bool? = nil) -> String {
        let valid = validLanguages(raw, for: model, realtimeEnabled: realtimeEnabled)
        if valid.count == 1 {
            return valid[0]
        }

        let supported = languages(for: model, realtimeEnabled: realtimeEnabled)
        if supported["auto"] != nil {
            return "auto"
        }
        return valid.first ?? validLanguageOrFallback(raw, for: model, realtimeEnabled: realtimeEnabled)
    }

    /// Normalizes a stored selection for a model: preserves the validated list
    /// for models that support multi-select, otherwise collapses to one code.
    static func normalizedSelection(_ raw: String?, for model: any TranscriptionModel, realtimeEnabled: Bool? = nil) -> String {
        if supportsMultipleLanguages(for: model) {
            return validLanguagesString(raw, for: model, realtimeEnabled: realtimeEnabled)
        }
        return validLanguageOrFallback(raw, for: model, realtimeEnabled: realtimeEnabled)
    }

    /// Returns the stored value after toggling one language code on/off.
    /// "auto" is mutually exclusive with specific languages; clearing the last
    /// specific language reverts to "auto".
    static func toggling(_ code: String, in raw: String?, available: [String: String]) -> String {
        if code == "auto" {
            return "auto"
        }

        var set = Set(parseSelectedLanguages(raw).filter { $0 != "auto" })
        if set.contains(code) {
            set.remove(code)
        } else {
            set.insert(code)
        }

        if set.isEmpty {
            return "auto"
        }

        return set
            .sorted { (available[$0] ?? $0) < (available[$1] ?? $1) }
            .joined(separator: ",")
    }

    /// Human-readable summary of a (possibly multi-) language selection.
    static func displaySummary(for raw: String?, available: [String: String]) -> String {
        let codes = parseSelectedLanguages(raw)
        if codes.isEmpty || codes.contains("auto") {
            return available["auto"] ?? "Auto-detect"
        }
        return codes.map { available[$0] ?? $0 }.joined(separator: ", ")
    }

    private static func assemblyAILanguages(usesRealtime: Bool) -> [String: String] {
        let codes = usesRealtime ? assemblyAIRealtimeLanguageCodes : assemblyAIBatchLanguageCodes
        var filtered = LanguageDictionary.all.filter { codes.contains($0.key) }
        filtered["auto"] = "Auto-detect"
        return filtered
    }

    private static func assemblyAIUsesRealtime(for model: any TranscriptionModel, realtimeEnabled: Bool?) -> Bool {
        guard model.provider == .assemblyAI, model.supportsStreaming else {
            return false
        }

        return TranscriptionRealtimeSupport.isEnabled(for: model, modeValue: realtimeEnabled)
    }
}

enum LanguageDictionary {
    private static let whisperLanguageCodes: Set<String> = [
        "auto",
        "af", "am", "ar", "as", "az", "ba", "be", "bg", "bn", "bo",
        "br", "bs", "ca", "cs", "cy", "da", "de", "el", "en", "es",
        "et", "eu", "fa", "fi", "fo", "fr", "gl", "gu", "ha", "haw",
        "he", "hi", "hr", "ht", "hu", "hy", "id", "is", "it", "ja",
        "jw", "ka", "kk", "km", "kn", "ko", "la", "lb", "ln", "lo",
        "lt", "lv", "mg", "mi", "mk", "ml", "mn", "mr", "ms", "mt",
        "my", "ne", "nl", "nn", "no", "oc", "pa", "pl", "ps", "pt",
        "ro", "ru", "sa", "sd", "si", "sk", "sl", "sn", "so", "sq",
        "sr", "su", "sv", "sw", "ta", "te", "tg", "th", "tk", "tl",
        "tr", "tt", "uk", "ur", "uz", "vi", "yi", "yo", "yue", "zh"
    ]

    static func forProvider(isMultilingual: Bool, provider: ModelProvider = .whisper) -> [String: String] {
        if !isMultilingual {
            return ["en": "English"]
        }

        if let cloudProvider = CloudProviderRegistry.provider(for: provider) {
            guard let codes = cloudProvider.languageCodes else {
                return all
            }
            var filtered = all.filter { codes.contains($0.key) }
            if cloudProvider.includesAutoDetect { filtered["auto"] = "Auto-detect" }
            return filtered
        }

        switch provider {
        case .whisper:
            return languages(matching: whisperLanguageCodes)

        case .nativeApple:
            return appleNative

        case .fluidAudio:
            let codes = [
                "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr",
                "hr", "hu", "it", "lt", "lv", "mt", "nl", "pl", "pt", "ro",
                "ru", "sk", "sl", "sv", "uk"
            ]
            var filtered = all.filter { codes.contains($0.key) }
            filtered["auto"] = "Auto-detect"
            return filtered

        default:
            return all
        }
    }

    static let nemotronLatin: [String: String] = [
        "auto": "Auto-detect",
        "de-DE": "German",
        "en-US": "English",
        "es-US": "Spanish",
        "fr-FR": "French",
        "it-IT": "Italian",
        "pt-BR": "Portuguese",
    ]

    static let nemotronMultilingual: [String: String] = [
        "auto": "Auto-detect",
        "ar-AR": "Arabic",
        "bg-BG": "Bulgarian",
        "cs-CZ": "Czech",
        "da-DK": "Danish",
        "de-DE": "German",
        "en-US": "English",
        "es-US": "Spanish",
        "et-EE": "Estonian",
        "fi-FI": "Finnish",
        "fr-FR": "French",
        "hi-IN": "Hindi",
        "hr-HR": "Croatian",
        "hu-HU": "Hungarian",
        "it-IT": "Italian",
        "ja-JP": "Japanese",
        "ko-KR": "Korean",
        "nb-NO": "Norwegian Bokmal",
        "nl-NL": "Dutch",
        "pl-PL": "Polish",
        "pt-BR": "Portuguese",
        "ro-RO": "Romanian",
        "ru-RU": "Russian",
        "sk-SK": "Slovak",
        "sv-SE": "Swedish",
        "tr-TR": "Turkish",
        "uk-UA": "Ukrainian",
        "vi-VN": "Vietnamese",
        "zh-CN": "Mandarin Chinese",
    ]

    private static func languages(matching codes: Set<String>) -> [String: String] {
        all.filter { codes.contains($0.key) }
    }

    // Apple Native Speech languages in BCP-47 format.
    // Queried from SpeechTranscriber.supportedLocales on macOS 26.4.
    static let appleNative: [String: String] = [
        "de-DE": "German (Germany)",
        "de-AT": "German (Austria)",
        "de-CH": "German (Switzerland)",
        "en-AU": "English (Australia)",
        "en-CA": "English (Canada)",
        "en-GB": "English (United Kingdom)",
        "en-IE": "English (Ireland)",
        "en-IN": "English (India)",
        "en-NZ": "English (New Zealand)",
        "en-SG": "English (Singapore)",
        "en-US": "English (United States)",
        "en-ZA": "English (South Africa)",
        "es-CL": "Spanish (Chile)",
        "es-ES": "Spanish (Spain)",
        "es-MX": "Spanish (Mexico)",
        "es-US": "Spanish (United States)",
        "fr-BE": "French (Belgium)",
        "fr-CA": "French (Canada)",
        "fr-CH": "French (Switzerland)",
        "fr-FR": "French (France)",
        "it-CH": "Italian (Switzerland)",
        "it-IT": "Italian (Italy)",
        "ja-JP": "Japanese (Japan)",
        "ko-KR": "Korean (South Korea)",
        "pt-BR": "Portuguese (Brazil)",
        "pt-PT": "Portuguese (Portugal)",
        "yue-CN": "Cantonese (China mainland)",
        "zh-CN": "Chinese (China mainland)",
        "zh-HK": "Chinese (Hong Kong)",
        "zh-TW": "Chinese (Taiwan)"
    ]

    static let all: [String: String] = [
        "auto": "Auto-detect",
        "af": "Afrikaans",
        "am": "Amharic",
        "ar": "Arabic",
        "as": "Assamese",
        "az": "Azerbaijani",
        "ba": "Bashkir",
        "be": "Belarusian",
        "bg": "Bulgarian",
        "bn": "Bengali",
        "bo": "Tibetan",
        "br": "Breton",
        "bs": "Bosnian",
        "ca": "Catalan",
        "cs": "Czech",
        "cy": "Welsh",
        "da": "Danish",
        "de": "German",
        "de_ch": "Swiss German",
        "el": "Greek",
        "en": "English",
        "en_au": "Australian English",
        "en_uk": "British English",
        "en_us": "US English",
        "es": "Spanish",
        "et": "Estonian",
        "eu": "Basque",
        "fa": "Persian",
        "fi": "Finnish",
        "fil": "Filipino",
        "fo": "Faroese",
        "fr": "French",
        "ga": "Irish",
        "gl": "Galician",
        "gu": "Gujarati",
        "ha": "Hausa",
        "haw": "Hawaiian",
        "he": "Hebrew",
        "hi": "Hindi",
        "hr": "Croatian",
        "ht": "Haitian Creole",
        "hu": "Hungarian",
        "hy": "Armenian",
        "id": "Indonesian",
        "ig": "Igbo",
        "is": "Icelandic",
        "it": "Italian",
        "ja": "Japanese",
        "jw": "Javanese",
        "ka": "Georgian",
        "kk": "Kazakh",
        "km": "Khmer",
        "kn": "Kannada",
        "ko": "Korean",
        "ku": "Kurdish",
        "ky": "Kyrgyz",
        "la": "Latin",
        "lb": "Luxembourgish",
        "ln": "Lingala",
        "lo": "Lao",
        "lt": "Lithuanian",
        "lv": "Latvian",
        "mg": "Malagasy",
        "mi": "Maori",
        "mk": "Macedonian",
        "ml": "Malayalam",
        "mn": "Mongolian",
        "mr": "Marathi",
        "ms": "Malay",
        "mt": "Maltese",
        "my": "Myanmar",
        "ne": "Nepali",
        "nl": "Dutch",
        "nn": "Norwegian Nynorsk",
        "no": "Norwegian",
        "oc": "Occitan",
        "or": "Odia",
        "pa": "Punjabi",
        "pl": "Polish",
        "ps": "Pashto",
        "pt": "Portuguese",
        "ro": "Romanian",
        "ru": "Russian",
        "sa": "Sanskrit",
        "sd": "Sindhi",
        "si": "Sinhala",
        "sk": "Slovak",
        "sl": "Slovenian",
        "sn": "Shona",
        "so": "Somali",
        "sq": "Albanian",
        "sr": "Serbian",
        "su": "Sundanese",
        "sv": "Swedish",
        "sw": "Swahili",
        "ta": "Tamil",
        "te": "Telugu",
        "tg": "Tajik",
        "th": "Thai",
        "tk": "Turkmen",
        "tl": "Tagalog",
        "tr": "Turkish",
        "tt": "Tatar",
        "uk": "Ukrainian",
        "ur": "Urdu",
        "uz": "Uzbek",
        "vi": "Vietnamese",
        "wo": "Wolof",
        "xh": "Xhosa",
        "yi": "Yiddish",
        "yo": "Yoruba",
        "yue": "Cantonese",
        "zh": "Chinese",
        "zu": "Zulu"
    ]
}
