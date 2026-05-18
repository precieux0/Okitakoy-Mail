# Okitakoy Mail

Application **Flutter** de boîte mail temporaire — par **Okitakoy Corp**, fondée par **Précieux Okitakoy**.

## Fonctionnalités

- 🔐 Inscription / connexion par **e-mail + mot de passe** (stocké chiffré localement)
- 🟦 **Google OAuth** (sans Firebase)
- ⚫ **GitHub OAuth** (sans Firebase)
- 📬 Adresse e-mail temporaire (API mail.tm)
- 📖 Page **À propos & FAQ**

## Lancer en local

```bash
cd flutter_app
flutter create --platforms=android --project-name okitakoy_mail --org corp.okitakoy .
bash scripts/patch_android.sh
flutter pub get
flutter run --dart-define=GITHUB_CLIENT_ID=... --dart-define=GITHUB_CLIENT_SECRET=...
```

## Construire l'APK Android 13+

Push sur `main` → la GitHub Action **Build Android APK** génère un APK compatible **API 33 (Android 13+)**, `minSdk 21`. L'artifact `okitakoy-mail-release-apk` est téléchargeable depuis l'onglet Actions.

## Configurer Google & GitHub OAuth

Voir [`configuration.md`](./configuration.md).
