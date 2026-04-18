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
