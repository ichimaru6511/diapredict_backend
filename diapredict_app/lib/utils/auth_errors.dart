// Converts Firebase error codes into messages that users can understand.
String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'The email address is not valid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for this email.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'network-request-failed':
      return 'No internet connection. Please try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    default:
      return 'Something went wrong ($code). Please try again.';
  }
}
