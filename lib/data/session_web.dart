import 'package:web/web.dart' as web;

String? readSession() {
  try {
    return web.window.sessionStorage.getItem('errandly_session');
  } catch (_) {
    return null;
  }
}

void saveSession(String? token) {
  try {
    if (token == null) {
      web.window.sessionStorage.removeItem('errandly_session');
    } else {
      web.window.sessionStorage.setItem('errandly_session', token);
    }
  } catch (_) {
    // Browsers may disable storage; the current session still works.
  }
}
