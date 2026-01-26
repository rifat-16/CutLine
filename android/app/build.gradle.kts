import java.io.FileInputStream
import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .all { keystoreProperties.containsKey(it) }

val isReleaseTaskRequested = gradle.startParameter.taskNames.any { name ->
    name.contains("release", ignoreCase = true)
}

if (isReleaseTaskRequested && !hasReleaseKeystore) {
    throw GradleException(
        """
        Missing Android release signing config.
        
        Create `android/key.properties` with:
          storeFile=/absolute/path/to/upload-keystore.jks
          storePassword=YOUR_PASSWORD
          keyAlias=upload
          keyPassword=YOUR_PASSWORD
        
        Then rebuild with:
          flutter build appbundle --release
        """.trimIndent()
    )
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
fun resolveMapKey(name: String): String {
    val fromProps = localProperties.getProperty(name)?.trim().orEmpty()
    if (fromProps.isNotEmpty()) {
        return fromProps
    }
    val fromEnv = System.getenv(name)?.trim().orEmpty()
    if (fromEnv.isNotEmpty()) {
        return fromEnv
    }
    return ""
}

val mapsApiKeyDefault = resolveMapKey("MAPS_API_KEY")
val mapsApiKeyDev = resolveMapKey("MAPS_API_KEY_DEV").ifEmpty { mapsApiKeyDefault }
val mapsApiKeyStaging = resolveMapKey("MAPS_API_KEY_STAGING").ifEmpty { mapsApiKeyDefault }
val mapsApiKeyProd = resolveMapKey("MAPS_API_KEY_PROD").ifEmpty { mapsApiKeyDefault }

val requestedFlavors = listOf("dev", "staging", "prod").filter { flavor ->
    gradle.startParameter.taskNames.any { name -> name.contains(flavor, ignoreCase = true) }
}

requestedFlavors.forEach { flavor ->
    val configFile = project.file("src/$flavor/google-services.json")
    if (!configFile.exists()) {
        throw GradleException(
            """
            Missing Firebase config for Android flavor "$flavor".
            
            Expected file:
              android/app/src/$flavor/google-services.json
            
            Download the correct google-services.json from:
              Firebase Console → Project Settings → Your apps (Android)
            """.trimIndent()
        )
    }
}

android {
    namespace = "com.cutline"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                val storeFilePath = keystoreProperties["storeFile"] as String
                val storeFileObj = File(storeFilePath)
                storeFile = if (storeFileObj.isAbsolute) {
                    storeFileObj
                } else {
                    rootProject.file(storeFilePath)
                }
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    compileOptions {
        // Enable core library desugaring for Java 8+ APIs
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cutline.prod"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyDefault
        resValue("string", "app_name", "CutLine")
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "com.cutline.dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "CutLine Dev")
            manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyDev
        }
        create("staging") {
            dimension = "env"
            applicationId = "com.cutline.staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "CutLine Staging")
            manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyStaging
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.cutline.prod"
            resValue("string", "app_name", "CutLine")
            manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyProd
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add this line for desugaring support
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
