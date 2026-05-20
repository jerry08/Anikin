# anikin

A new Flutter project.

## Local configuration

The Juro API base URL is intentionally provided outside git. Create a local
`env/juro.local.json` file shaped like:

```json
{
  "JURO_API_BASE_URL": "https://your-juro-host.example/api"
}
```

Run the app with:

```powershell
flutter run --dart-define-from-file=env/juro.local.json
```

## Releases

The GitHub release workflow builds Android, Windows, and Linux. Tagged pushes
like `v3.0.2` create a release.

Required release secret:

- `JURO_API_BASE_URL` for the compiled app API URL. The legacy `API_URL` secret
  is also accepted.

Required Android signing secrets:

- `ANDROID_KEYSTORE_B64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The legacy `KEYSTORE_B64` and `PASSWORD` secrets are also accepted.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
