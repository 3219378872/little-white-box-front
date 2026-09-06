abstract final class ErrorCodes {
  static const int unknownError = 1;
  static const int paramError = 2;
  static const int systemError = 3;
  static const int tooManyRequests = 5;
  static const int serviceUnavailable = 6;

  static const int userNotFound = 1001;
  static const int userAlreadyExist = 1002;
  static const int passwordError = 1003;
  static const int tokenExpired = 1004;
  static const int tokenInvalid = 1005;
  static const int loginRequired = 1006;
  static const int permissionDenied = 1007;

  static const int contentNotFound = 2001;
  static const int contentForbidden = 2002;
  static const int contentEmpty = 2004;
  static const int postAlreadyDeleted = 2006;
  static const int contentVersionConflict = 2007;
  static const int idempotencyConflict = 2008;

  static const int alreadyLiked = 3001;
  static const int alreadyFavorited = 3002;
  static const int notLiked = 3003;
  static const int notFavorited = 3004;
  static const int favoritesPrivate = 3007;

  static const int fileTooLarge = 4001;
  static const int unsupportedFileType = 4002;
  static const int uploadFailed = 4003;
  static const int mediaNotFound = 4004;

  static const int searchEmpty = 5001;

  static const int cannotWatchSelf = 6005;

  static bool isAuthError(int? code) =>
      code == tokenExpired || code == tokenInvalid || code == loginRequired;
}
