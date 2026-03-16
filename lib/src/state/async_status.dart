enum AsyncStatus {
  idle,
  loading,
  success,
  empty,
  error,
  unauthorized,
}

extension AsyncStatusX on AsyncStatus {
  bool get isIdle => this == AsyncStatus.idle;
  bool get isLoading => this == AsyncStatus.loading;
  bool get isSuccess => this == AsyncStatus.success;
  bool get isEmpty => this == AsyncStatus.empty;
  bool get isError => this == AsyncStatus.error;
  bool get isUnauthorized => this == AsyncStatus.unauthorized;
}
