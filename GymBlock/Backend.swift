import Foundation
import Supabase

/// The one Supabase client. Sessions persist in the Keychain (the SDK's default) and the stored
/// session is emitted immediately on launch, so a returning user never sees the welcome page flash.
enum Backend {
  static let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseKey,
    options: SupabaseClientOptions(auth: .init(flowType: .pkce, emitLocalSessionAsInitialSession: true)))

  static let encoder: JSONEncoder = {
    let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
  }()
  static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    d.dateDecodingStrategy = .custom { decoder in
      let s = try decoder.singleValueContainer().decode(String.self)
      if let date = iso.date(from: s) ?? plain.date(from: s) { return date }
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
    }
    return d
  }()
}

/// One place for logs, so a failed request never crashes and is easy to find in Console.
enum AppLog {
  static func error(_ message: String) { NSLog("GymBlock: %@", message) }
}
