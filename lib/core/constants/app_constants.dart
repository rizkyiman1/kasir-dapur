abstract final class AppConstants {
  static const int pinLength = 6;
  static const int pinHashIterations = 12000;
  static const int splashMinDurationMs = 1200;
  static const int maxPinAttemptsWarning = 5;

  static const Duration sessionIdleLock = Duration(minutes: 5);
  static const Duration sessionMaxDuration = Duration(hours: 12);
  static const Duration sessionCheckInterval = Duration(seconds: 15);
  static const Duration sessionTouchDebounce = Duration(seconds: 5);

  static const String defaultBusinessDisplayName = 'Usaha Saya';

  static const String settingsKeyThemeMode = 'theme_mode';
  static const String settingsKeyOnboardingDone = 'onboarding_done';
  static const String settingsKeyCloudAccessToken = 'cloud.access_token';
  static const String settingsKeyCloudTokenUserId = 'cloud.token_user_id';
  static const String settingsKeyLastSyncPrefix = 'sync.last_at.';
  static const String settingsKeyLastBackupAtPrefix = 'backup.last_at.';
  static const String settingsKeyLastBackupIdPrefix = 'backup.last_id.';
  static const String settingsKeyLastBackupStatusPrefix = 'backup.last_status.';
  static const String settingsKeyLastRestoreAtPrefix =
      'backup.last_restore_at.';
  static const String settingsKeyLastRestoreStatusPrefix =
      'backup.last_restore_status.';
  static const String settingsKeyLastRestoreCountPrefix =
      'backup.last_restore_count.';
  static const String settingsKeyPreRestoreSnapshotPrefix =
      'backup.pre_restore_snapshot.';

  static const Duration syncPollInterval = Duration(seconds: 45);
  static const int syncMaxAttempts = 8;
}
