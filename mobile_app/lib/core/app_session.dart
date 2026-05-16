class AppSession {
  AppSession._();

  static bool _isGuestMode = false;
  static bool _aiMatchRan = false;

  static bool get isGuestMode => _isGuestMode;
  static bool get hasRunAiMatch => _aiMatchRan;

  static void enterGuestMode() {
    _isGuestMode = true;
    _aiMatchRan = false;
  }

  static void clearGuestMode() {
    _isGuestMode = false;
    _aiMatchRan = false;
  }

  static void markAiMatchRan() {
    _aiMatchRan = true;
  }
}
