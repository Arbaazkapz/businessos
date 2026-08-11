/// Google Sign-In configuration for Drive backup/sync.
///
/// google_sign_in v7 requires a **serverClientId** to be passed to
/// `GoogleSignIn.instance.initialize()` on Android - even though this app
/// has no server. Without it you get exactly the error you saw:
///
///   GoogleSignInException(code clientConfigurationError,
///   serverClientId must be provided on Android, null)
///
/// IMPORTANT - this is NOT the same value as the "Client ID for Android"
/// you already created (the one tied to your package name + SHA-1
/// fingerprint, shown in image 3). That Android client is used
/// automatically behind the scenes by Play Services; it is never typed
/// into code.
///
/// serverClientId must be a **"Web application"** type OAuth client ID,
/// created in the SAME Google Cloud project:
///   1. Google Cloud Console -> APIs & Services -> Credentials
///   2. Create Credentials -> OAuth client ID -> Application type: "Web
///      application" (NOT Android)
///   3. No redirect URIs are needed for this use case - just create it and
///      copy the Client ID (looks like
///      "123456789-abc...xyz.apps.googleusercontent.com")
///   4. Paste that value below.
///
/// This value is not a secret (it identifies your app, it doesn't
/// authenticate it) so it's fine to commit/ship in the APK.
const String googleServerClientId =
    '225715080177-8rmdpsc9o2fuafsg7dkggkli75sk3gm5.apps.googleusercontent.com';

bool get isGoogleServerClientIdConfigured =>
    !googleServerClientId.startsWith('REPLACE_WITH_');
