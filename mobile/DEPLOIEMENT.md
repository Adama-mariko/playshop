# Guide de Déploiement - PlayShop Mobile (Android)

## 📱 Tester sur un téléphone Android

### Option 1 : Mode Développement (Recommandé pour les tests)

1. **Activer le mode développeur sur votre téléphone Android :**
   - Allez dans `Paramètres` → `À propos du téléphone`
   - Appuyez 7 fois sur `Numéro de build`
   - Retournez dans `Paramètres` → `Options pour les développeurs`
   - Activez `Débogage USB`

2. **Connecter votre téléphone à l'ordinateur via USB**

3. **Vérifier que le téléphone est détecté :**
   ```bash
   cd mobile
   flutter devices
   ```

4. **Lancer l'application sur le téléphone :**
   ```bash
   flutter run
   ```

### Option 2 : Générer un APK pour installation manuelle

1. **Générer l'APK de debug :**
   ```bash
   cd mobile
   flutter build apk --debug
   ```
   L'APK sera généré dans : `mobile/build/app/outputs/flutter-apk/app-debug.apk`

2. **Transférer l'APK sur votre téléphone :**
   - Via USB : copiez le fichier sur votre téléphone
   - Via email/WhatsApp : envoyez-vous le fichier
   - Via cloud : uploadez sur Google Drive/Dropbox

3. **Installer l'APK sur le téléphone :**
   - Ouvrez le fichier APK sur votre téléphone
   - Autorisez l'installation depuis des sources inconnues si demandé
   - Installez l'application

### Option 3 : APK de Release (pour distribution)

1. **Générer l'APK de release :**
   ```bash
   cd mobile
   flutter build apk --release
   ```
   L'APK sera dans : `mobile/build/app/outputs/flutter-apk/app-release.apk`

2. **Distribuer l'APK :**
   - Partagez directement le fichier APK
   - Uploadez sur un serveur web
   - Utilisez un service comme Firebase App Distribution

## 🚀 Déployer sur Google Play Store

### Prérequis

1. **Compte Google Play Developer** (25$ unique)
2. **Clé de signature** pour signer l'application

### Étapes de déploiement

#### 1. Créer une clé de signature

```bash
cd mobile/android
keytool -genkey -v -keystore playshop-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias playshop
```

Conservez précieusement :
- Le fichier `playshop-release-key.jks`
- Le mot de passe du keystore
- Le mot de passe de la clé

#### 2. Configurer la signature dans `android/key.properties`

Créez le fichier `mobile/android/key.properties` :

```properties
storePassword=VOTRE_MOT_DE_PASSE_KEYSTORE
keyPassword=VOTRE_MOT_DE_PASSE_CLE
keyAlias=playshop
storeFile=playshop-release-key.jks
```

⚠️ **Important :** Ajoutez `key.properties` dans `.gitignore` !

#### 3. Modifier `android/app/build.gradle.kts`

Ajoutez avant le bloc `android` :

```kotlin
// Charger les propriétés de signature
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Dans le bloc `android`, modifiez `buildTypes` :

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

#### 4. Mettre à jour les informations de l'application

Dans `mobile/android/app/build.gradle.kts`, changez :

```kotlin
defaultConfig {
    applicationId = "com.playshop.mobile"  // Changez com.example
    minSdk = 21
    targetSdk = 34
    versionCode = 1
    versionName = "1.0.0"
}
```

#### 5. Générer l'App Bundle (AAB) pour le Play Store

```bash
cd mobile
flutter build appbundle --release
```

Le fichier sera dans : `mobile/build/app/outputs/bundle/release/app-release.aab`

#### 6. Uploader sur Google Play Console

1. Allez sur [Google Play Console](https://play.google.com/console)
2. Créez une nouvelle application
3. Remplissez les informations (nom, description, captures d'écran, icône)
4. Uploadez le fichier `app-release.aab`
5. Configurez la fiche du store
6. Soumettez pour révision

## 🌐 Alternatives au Play Store

### 1. Firebase App Distribution (Gratuit)

Idéal pour les tests bêta :

```bash
# Installer Firebase CLI
npm install -g firebase-tools

# Se connecter
firebase login

# Distribuer l'APK
firebase appdistribution:distribute mobile/build/app/outputs/flutter-apk/app-release.apk \
  --app VOTRE_APP_ID \
  --groups testers
```

### 2. Hébergement Web Direct

Uploadez l'APK sur votre serveur et partagez le lien :

```bash
# Exemple avec votre backend
cp mobile/build/app/outputs/flutter-apk/app-release.apk backend/public/downloads/playshop.apk
```

Créez une page de téléchargement : `https://votre-domaine.com/downloads/playshop.apk`

### 3. Services tiers

- **AppCenter** (Microsoft) - Gratuit
- **TestFlight** (iOS uniquement)
- **Diawi** - Partage temporaire d'APK

## 🔧 Configuration Backend pour le Mobile

### Vérifier que le backend accepte les requêtes mobiles

Dans `backend/.env`, assurez-vous que :

```env
APP_URL=https://votre-api.com
FRONTEND_URL=https://votre-site.com
```

### Tester la redirection deep link

Après paiement, le backend redirige vers :
- Web : `https://votre-site.com/payment/success?ref=PS-123`
- Mobile : `playshop://payment/success?ref=PS-123`

La détection se fait automatiquement via le paramètre `mobile=1` envoyé par l'app.

## 📝 Checklist avant déploiement

- [ ] Changer `applicationId` de `com.example.playshop_mobile` à votre domaine
- [ ] Mettre à jour l'icône de l'app (`android/app/src/main/res/mipmap-*/ic_launcher.png`)
- [ ] Configurer l'URL de l'API dans `mobile/lib/core/api/api_client.dart`
- [ ] Tester les deep links (`playshop://payment/success`)
- [ ] Générer une clé de signature pour la release
- [ ] Tester l'APK de release sur un vrai téléphone
- [ ] Préparer les captures d'écran pour le Play Store
- [ ] Rédiger la description de l'app

## 🐛 Dépannage

### L'APK ne s'installe pas
- Vérifiez que "Sources inconnues" est activé
- Désinstallez l'ancienne version si elle existe

### L'app crash au démarrage
- Vérifiez les logs : `flutter logs`
- Assurez-vous que l'URL de l'API est correcte

### Le deep link ne fonctionne pas
- Vérifiez que `app_links` est bien installé : `flutter pub get`
- Testez avec : `adb shell am start -a android.intent.action.VIEW -d "playshop://payment/success?ref=TEST"`

### Erreur de signature
- Vérifiez que `key.properties` existe et contient les bonnes informations
- Assurez-vous que le fichier `.jks` est au bon endroit

## 📞 Support

Pour toute question, consultez :
- [Documentation Flutter](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
