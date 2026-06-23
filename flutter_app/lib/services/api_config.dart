/// Central place for the backend's base URL.
///
/// IMPORTANT: Before building the release APK, replace this with your
/// hosted backend's public URL (Railway/Render/Azure), e.g.
/// "https://glass-collector-api.up.railway.app".
///
/// Do NOT point this at "localhost" in the APK you submit — localhost
/// on the device refers to the device itself, not your dev machine.
class ApiConfig {
  static const String baseUrl = "https://YOUR-BACKEND-URL.example.com";

  // Convenience for local emulator testing only:
  // Android emulator -> use 10.0.2.2 to reach your host machine's localhost.
  // static const String baseUrl = "http://10.0.2.2:8080";
}
