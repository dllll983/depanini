#!/usr/bin/env bash
# Prépare un projet Flutter complet (Android + iOS) pour une des deux apps.
# Usage : bash tool/prepare_platform.sh client "DÉPANINI"
#         bash tool/prepare_platform.sh pro    "DÉPANINI Pro"
set -euo pipefail

VARIANT="$1"
LABEL="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build_apps/$VARIANT"

rm -rf "$OUT"
mkdir -p "$ROOT/build_apps"
flutter create --org dz.depanini --project-name "$VARIANT" --platforms android,ios "$OUT"

# Code de l'application
rm -rf "$OUT/lib" "$OUT/test"
cp -r "$ROOT/lib" "$OUT/lib"
sed "s/^name: depanini/name: $VARIANT/" "$ROOT/pubspec.yaml" > "$OUT/pubspec.yaml"

# Icônes Android
for d in "$ROOT/assets/icons/$VARIANT"/mipmap-*; do
  cp "$d/ic_launcher.png" "$OUT/android/app/src/main/res/$(basename "$d")/ic_launcher.png"
done

# Nom, permissions et intentions Android ; textes d'autorisation iOS
python3 - "$OUT" "$LABEL" "$VARIANT" <<'PY'
import re, sys, pathlib
out, label, variant = sys.argv[1], sys.argv[2], sys.argv[3]
m = pathlib.Path(out, 'android/app/src/main/AndroidManifest.xml')
x = m.read_text(encoding='utf-8')
x = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', x, count=1)
perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.CAMERA',
]
if variant == 'pro':
    perms += ['android.permission.FOREGROUND_SERVICE', 'android.permission.FOREGROUND_SERVICE_LOCATION']
block = ''.join(f'\n    <uses-permission android:name="{p}"/>' for p in perms)
x = re.sub(r'(<manifest[^>]*>)', r'\1' + block, x, count=1)
queries = '''
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="sms"/></intent>'''
if '<queries>' in x:
    x = x.replace('<queries>', '<queries>' + queries, 1)
else:
    x = x.replace('</manifest>', f'    <queries>{queries}\n    </queries>\n</manifest>')
m.write_text(x, encoding='utf-8')

# Versions Gradle / Android / Kotlin récentes (compatibilité des plugins)
for name in ('settings.gradle', 'settings.gradle.kts'):
    s = pathlib.Path(out, 'android', name)
    if s.exists():
        t = s.read_text(encoding='utf-8')
        t = re.sub(r'(com\.android\.application["\)]?\s*version\s*["\'])[^"\']+', r'\g<1>8.7.3', t)
        t = re.sub(r'(org\.jetbrains\.kotlin\.android["\)]?\s*version\s*["\'])[^"\']+', r'\g<1>2.1.0', t)
        s.write_text(t, encoding='utf-8')
w = pathlib.Path(out, 'android/gradle/wrapper/gradle-wrapper.properties')
w.write_text(re.sub(r'distributionUrl=.*', r'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.10.2-all.zip',
                    w.read_text(encoding='utf-8')), encoding='utf-8')

p = pathlib.Path(out, 'ios/Runner/Info.plist')
y = p.read_text(encoding='utf-8')
y = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', rf'\g<1>{label}\g<2>', y)
extra = '''
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>DÉPANINI utilise votre position pour trouver les prestataires les plus proches.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>Votre position est partagée avec le client uniquement pendant une mission.</string>
	<key>NSCameraUsageDescription</key>
	<string>Photographier vos documents et le reçu de virement.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Choisir la photo de vos documents ou du reçu de virement.</string>
	<key>LSApplicationQueriesSchemes</key>
	<array><string>tel</string><string>sms</string><string>https</string><string>whatsapp</string></array>'''
y = y.replace('<dict>', '<dict>' + extra, 1)
p.write_text(y, encoding='utf-8')
print('platform patched for', variant)
PY

echo "Projet prêt : $OUT"
