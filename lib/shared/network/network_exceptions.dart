class NetworkRequestException implements Exception {
  const NetworkRequestException(this.message);

  final String message;
}

class RemoteResponseException implements Exception {
  const RemoteResponseException(this.message);

  final String message;
}

class ResourceNotFoundException extends RemoteResponseException {
  const ResourceNotFoundException(super.message);
}

/// The OAuth server refused a code or refresh token: signing in again is
/// the only way on.
class InvalidGrantException extends RemoteResponseException {
  const InvalidGrantException(super.message);
}
