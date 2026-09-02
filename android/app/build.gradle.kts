import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release-Signing (Store-Blocker behoben): android/key.properties existiert
// nur lokal bei Jonny, nie im Git (siehe android/.gitignore). Wenn sie
// fehlt, wird WEITER UNTEN in diesem File jeder echte Release-Build-Task
// hart abgebrochen - kein stilles Signieren mit den Debug-Keys mehr. Siehe
// docs/RELEASE.md fuer den vollstaendigen Ablauf inkl. keytool-Befehl.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreProperties = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasKeystoreProperties) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.honeybadger.honey_badger_chess"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.honeybadger.honey_badger_chess"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Debug-Keys hier sind nur ein Konfigurations-Platzhalter, damit
            // `flutter run`/Debug-Builds nicht durch eine fehlende
            // key.properties kaputtgehen (Gradle konfiguriert alle
            // BuildTypes, egal welcher Task tatsaechlich laeuft). Der
            // eigentliche Schutz gegen stilles Debug-Signing ist der
            // doFirst-Hook unten, der NUR bei echten Release-Build-Tasks
            // greift.
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

if (!hasKeystoreProperties) {
    tasks.matching {
        it.name.startsWith("assembleRelease") || it.name.startsWith("bundleRelease")
    }.configureEach {
        doFirst {
            throw GradleException(
                "Release-Build ohne android/key.properties nicht erlaubt - " +
                    "kein stilles Signieren mit Debug-Keys. Siehe " +
                    "docs/RELEASE.md, um einen echten Keystore anzulegen."
            )
        }
    }
}

flutter {
    source = "../.."
}
