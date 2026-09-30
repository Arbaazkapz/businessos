"""Run after flutter create. Preserves the existing Android application ID."""
from pathlib import Path
import re
import shutil

root = Path(__file__).resolve().parent.parent
android = root / 'android'
if not android.exists():
    raise SystemExit('Run flutter create --platforms=android --org com.businessos --project-name businessos . first')
for manifest in (android / 'app/src').glob('*/AndroidManifest.xml'):
    text = manifest.read_text()
    text = re.sub(r'android:label="[^"]*"', 'android:label="ShopHisab"', text)
    if '/main/' in str(manifest):
        for permission in ['INTERNET', 'USE_BIOMETRIC']:
            if f'android.permission.{permission}' not in text:
                text = re.sub(r'(<manifest[^>]*>)', r'\1\n    <uses-permission android:name="android.permission.' + permission + '" />', text, count=1)
        text = re.sub(r'\s+android:allowBackup="[^"]*"', '', text)
        text = text.replace('<application', '<application android:allowBackup="false"', 1)
    manifest.write_text(text)
for activity in (android / 'app/src/main').rglob('MainActivity.kt'):
    activity.write_text(activity.read_text().replace('FlutterActivity', 'FlutterFragmentActivity'))
for style in (android / 'app/src/main/res').glob('values*/styles.xml'):
    style.write_text(style.read_text().replace('parent="@android:style/Theme.Light.NoTitleBar"', 'parent="Theme.AppCompat.Light.NoActionBar"').replace('parent="@android:style/Theme.Black.NoTitleBar"', 'parent="Theme.AppCompat.NoActionBar"'))
gradle = android / 'app/build.gradle.kts'
text = gradle.read_text()
if 'id("org.jetbrains.kotlin.android")' not in text:
    text = text.replace('id("com.android.application")', 'id("com.android.application")\n    id("org.jetbrains.kotlin.android")', 1)
text = re.sub(r'compileSdk = .*', 'compileSdk = 36', text)
text = re.sub(r'minSdk = .*', 'minSdk = 23', text)
marker = '// SHOPHISAB SIGNING'
if marker in text: text = text.split(marker)[0]
text += '''
// SHOPHISAB SIGNING
android {
    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (System.getenv("SHOPHISAB_KEYSTORE") != null) {
            create("shopHisabRelease") {
                storeFile = file(System.getenv("SHOPHISAB_KEYSTORE"))
                storePassword = System.getenv("SHOPHISAB_STORE_PASSWORD")
                keyAlias = System.getenv("SHOPHISAB_KEY_ALIAS")
                keyPassword = System.getenv("SHOPHISAB_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName(
                if (System.getenv("SHOPHISAB_KEYSTORE") != null) "shopHisabRelease" else "debug"
            )
        }
    }
}
'''
gradle.write_text(text)
properties = android / 'gradle.properties'
config = properties.read_text()
config = re.sub(r'org.gradle.jvmargs=.*', 'org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError', config)
properties.write_text(config)
shutil.copyfile(root / 'debug.keystore', android / 'app/debug.keystore')
print('ShopHisab Android configuration applied; application ID unchanged.')
