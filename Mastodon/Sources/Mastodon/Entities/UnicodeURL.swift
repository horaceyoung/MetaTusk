// Copyright © 2021 Metabolist. All rights reserved.

import Foundation

public struct UnicodeURL {
    public let raw: String
    public let url: URL
}

extension UnicodeURL: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw)
    }
}

extension UnicodeURL: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        raw = try container.decode(String.self)

        if let url = URL(unicodeString: raw) {
            self.url = url
        } else {
            throw URLError(.badURL)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(raw)
    }
}
