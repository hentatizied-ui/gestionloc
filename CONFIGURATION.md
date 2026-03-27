# Guide de configuration — 3 plateformes

## Étape 1 — Google Cloud Console (une seule fois)

1. Va sur https://console.cloud.google.com
2. **Nouveau projet** → nom : `GestionLocative`
3. **API et services** → **Bibliothèque** → activer **Google Drive API**
4. **API et services** → **Écran de consentement OAuth**
   - Type : Externe
   - Nom : Gestion Locative
   - Email : le tien
   - Enregistrer
5. **API et services** → **Identifiants** → **+ Créer des identifiants** → **ID client OAuth**

---

## Étape 2 — Créer 3 clients OAuth

### Client Web (obligatoire pour Chrome ET Android)
- Type : **Application Web**
- Origines JS autorisées :
  - `http://localhost`
  - `http://localhost:8080`
- → Copie le **Client ID Web** (`XXXX.apps.googleusercontent.com`)

### Client Android
- Type : **Android**
- Nom du package : `com.example.gestion_locative`
- Empreinte SHA-1 (debug) — exécute dans ton terminal :
  ```
  keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
  ```
  Sur Mac/Linux :
  ```
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```
- → Copie le **Client ID Android**

### Client iOS
- Type : **iOS**
- Bundle ID : `com.example.gestionLocative`
- → Copie le **Client ID iOS**
- → Télécharge aussi le **GoogleService-Info.plist**

---

## Étape 3 — Mettre à jour le code

### `lib/services/auth_service.dart`
Remplace les 3 constantes :
```dart
static const String _webClientId     = 'TON_WEB_CLIENT_ID.apps.googleusercontent.com';
static const String _androidClientId = 'TON_ANDROID_CLIENT_ID.apps.googleusercontent.com';
static const String _iosClientId     = 'TON_IOS_CLIENT_ID.apps.googleusercontent.com';
```

### `web/index.html`
Remplace la balise meta :
```html
<meta name="google-signin-client_id" content="TON_WEB_CLIENT_ID.apps.googleusercontent.com">
```

### Android — `android/app/google-services.json`
Télécharge le vrai fichier depuis Google Cloud Console → Identifiants → ton projet Android → icône téléchargement, et remplace le fichier placeholder.

### iOS — `ios/Runner/GoogleService-Info.plist`
Remplace le fichier placeholder par celui téléchargé depuis Google Cloud Console.

### iOS — `ios/Runner/Info.plist`
Remplace `REMPLACE_IOS_CLIENT_ID` par la valeur `REVERSED_CLIENT_ID` de ton `GoogleService-Info.plist`
(format : `com.googleusercontent.apps.XXXXXXX`)

---

## Étape 4 — Lancer

```bash
# Chrome (port fixe pour éviter de changer l'URL à chaque fois)
flutter run -d chrome --web-port=8080

# Android (émulateur ou vrai appareil branché)
flutter run -d android

# iOS (Mac uniquement)
flutter run -d ios
```

---

## Résumé des fichiers à modifier

| Fichier | Ce qu'il faut remplacer |
|---|---|
| `lib/services/auth_service.dart` | 3 Client IDs |
| `web/index.html` | Client ID Web |
| `android/app/google-services.json` | Remplacer par le vrai fichier |
| `ios/Runner/GoogleService-Info.plist` | Remplacer par le vrai fichier |
| `ios/Runner/Info.plist` | REVERSED_CLIENT_ID iOS |
