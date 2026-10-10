# DÉPANINI — code de démarrage (Flutter + Supabase)

Un seul code Flutter pour **deux applications** publiées sur Android (APK/AAB) et iOS (IPA) :

| App | Point d'entrée | Identifiant | Public |
| --- | --- | --- | --- |
| DÉPANINI | `lib/main_client.dart` | `dz.depanini.client` | Clients (gratuit) |
| DÉPANINI Pro | `lib/main_pro.dart` | `dz.depanini.pro` | Prestataires (1 500 DA/mois par virement) |

Aucun paiement n'est intégré à l'application, ni côté client, ni côté prestataire.

## Contenu

```
supabase/schema.sql          Base PostgreSQL + PostGIS : tables, sécurité (RLS), recherche par proximité,
                             validation des virements, publicités, stockage
lib/core/                    Config, thème (jaune/noir · rouge/marine), GPS, accès aux données, démarrage
lib/widgets/ad_slot.dart     Emplacement publicitaire réutilisable (client et Pro)
lib/client/                  Accueil (2 axes + appel 14), prestataires proches (carte + liste), suivi temps réel
lib/pro/                     Tableau de bord (en ligne, demandes, accepter/refuser), abonnement par virement
```

## 1. Prérequis

- Flutter (canal stable) et Android Studio ; pour iOS : un Mac avec Xcode et CocoaPods
  (sans Mac : Codemagic ou GitHub Actions avec un runner macOS).
- Supabase CLI (`npm i -g supabase`) et Docker pour le serveur local.

## 2. Générer les dossiers Android et iOS

```bash
cd depanini
flutter create --org dz.depanini --project-name depanini --platforms android,ios .
flutter pub get
```

## 3. Base de données

```bash
supabase init
supabase start                      # serveur local
supabase db reset                   # ou collez supabase/schema.sql dans l'éditeur SQL
```

Activez l'authentification par téléphone (SMS OTP) dans Supabase et branchez la passerelle SMS de votre opérateur.

## 4. Deux « flavors » (client / pro)

**Android** — `android/app/build.gradle` :

```gradle
android {
    flavorDimensions "app"
    productFlavors {
        client { dimension "app"; applicationId "dz.depanini.client"; resValue "string", "app_name", "DÉPANINI" }
        pro    { dimension "app"; applicationId "dz.depanini.pro";    resValue "string", "app_name", "DÉPANINI Pro" }
    }
}
```

Puis `android:label="@string/app_name"` dans `AndroidManifest.xml`, et les permissions :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<!-- App Pro uniquement : suivi pendant les missions -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

**iOS** — dans Xcode, dupliquer le schéma *Runner* en `client` et `pro`, avec les configurations
`Debug-client`, `Release-client`, `Debug-pro`, `Release-pro` et un *Bundle Identifier* par flavor.
Dans `ios/Runner/Info.plist` :

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>DÉPANINI utilise votre position pour trouver les dépanneurs et ambulances les plus proches.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>DÉPANINI Pro partage votre position avec le client uniquement pendant une mission en cours.</string>
<key>NSCameraUsageDescription</key>
<string>Photographier vos documents et le reçu de virement de votre abonnement.</string>
```

## 5. Lancer

```bash
flutter run -t lib/main_client.dart --flavor client \
  --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=<clé>

flutter run -t lib/main_pro.dart --flavor pro \
  --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=<clé>
```

## 6. Compiler pour les stores

```bash
# Android — Google Play (AAB) et APK direct
flutter build appbundle --flavor client -t lib/main_client.dart --dart-define-from-file=prod.json
flutter build apk --split-per-abi --flavor client -t lib/main_client.dart --dart-define-from-file=prod.json

# iOS — App Store / TestFlight
flutter build ipa --flavor client -t lib/main_client.dart --dart-define-from-file=prod.json
```

(Même chose avec `--flavor pro -t lib/main_pro.dart`.) Signature Android : `keytool` + `android/key.properties`,
voir le dossier projet, section 8.

## 7. Fonctionnement clé

- **Proximité** : `nearby_providers(lat, lng, axe, catégorie, rayon)` trie par distance réelle avec PostGIS et
  ne renvoie que les prestataires **vérifiés, en ligne et abonnés** (7 jours de grâce).
- **Vie privée** : avant acceptation, le prestataire ne voit que la distance (`incoming_requests`) ;
  les téléphones ne sont échangés qu'après acceptation (`request_contacts`).
- **Abonnement** : le prestataire vire 1 500 DA (ou 4 200 / 15 000 DA), téléverse le reçu ;
  l'admin appelle `validate_payment(id)` qui prolonge `subscription_until`.
- **Publicité** : table `ads` (surface `client` ou `pro`, emplacement, wilayas, dates) affichée par `AdSlot`.

## 8. À compléter avant production

- Écrans d'inscription (OTP), d'onboarding prestataire et de téléversement des documents.
- Service de premier plan Android pour le suivi (`flutter_foreground_task`) et notifications push (FCM/APNs).
- Console d'administration web (validation documents et virements, publicités, modération).
- Traductions arabe (droite à gauche), mode hors ligne, bouton SOS par SMS.
- Serveur de tuiles OSM propre (le serveur public `tile.openstreetmap.org` interdit l'usage intensif en production).
