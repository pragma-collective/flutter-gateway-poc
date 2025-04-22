class CommandValidator {
  static final List<RegExp> commandPatterns = [
    RegExp(r'^HELP$', caseSensitive: false),
    RegExp(r'^REGISTER\s+\S+$', caseSensitive: false),
    RegExp(r'^SEND\s+\d+(\.\d+)?\s+\S+\s+\S+$', caseSensitive: false),
    RegExp(r'^NOMINATE\s+\+?\d+\s+\+?\d+$', caseSensitive: false),
    RegExp(r'^ACCEPT\s+\S+$', caseSensitive: false),
    RegExp(r'^DENY\s+\S+$', caseSensitive: false),
    RegExp(r'^REQUEST\s+\d+(\.\d+)?\s+\S+\s+\S+$', caseSensitive: false),
  ];

  static bool isValidCommand(String message) {
    return commandPatterns.any((pattern) => pattern.hasMatch(message.trim()));
  }
}