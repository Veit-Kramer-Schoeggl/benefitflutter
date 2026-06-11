import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide logging facade over the `logger` package.
///
/// Levels: [d] debug, [i] info, [w] warning, [e] error.
///
/// - In release builds debug/info are dropped and only warning/error are kept
///   (via [ProductionFilter] + a warning [Level]); in debug everything prints.
/// - Every message is passed through [redact] as a defense-in-depth net to strip
///   PII/secrets (emails, bearer tokens, key=value secrets, GPS coordinates).
///   The primary rule remains: never pass a secret to the logger in the first place.
/// - [e] is the bridge point for crash reporting (Sentry is wired in a later step).
class AppLogger {
  AppLogger._();

  static Logger? _logger;

  /// Configure the logger. Call once early in `main()` (inside the guarded zone).
  static void init() {
    _logger = Logger(
      filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
      level: kReleaseMode ? Level.warning : Level.debug,
      printer: kReleaseMode
          ? SimplePrinter(printTime: true, colors: false)
          : PrettyPrinter(methodCount: 0, errorMethodCount: 8, colors: false),
    );
  }

  static Logger get _l => _logger ??= Logger();

  static void d(String message) => _l.d(redact(message));

  static void i(String message) => _l.i(redact(message));

  static void w(String message, [Object? error, StackTrace? stackTrace]) =>
      _l.w(redact(message), error: error, stackTrace: stackTrace);

  /// Error-level log. Bridged to crash reporting (Sentry) in a later step.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _l.e(redact(message), error: error, stackTrace: stackTrace);
  }

  // ---- Redaction (defense-in-depth) ----

  static final List<RegExp> _redactors = <RegExp>[
    // Email addresses
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    // Bearer tokens
    RegExp(r'(?:[Bb]earer)\s+[A-Za-z0-9._\-]+'),
    // key=value / key: value secrets
    RegExp(
      r'\b(password|passwd|secret|token|api[_-]?key|dsn|authorization)\b\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    // GPS coordinates / health raw values: numbers with 5+ decimal places
    RegExp(r'-?\d{1,3}\.\d{5,}'),
  ];

  /// Replace likely PII/secrets in [input] with `[redacted]`.
  static String redact(String input) {
    var out = input;
    for (final r in _redactors) {
      out = out.replaceAll(r, '[redacted]');
    }
    return out;
  }
}
