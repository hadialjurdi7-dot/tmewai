plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tmewai.app"
    compileSdk = flutter.compileSdkVersion
    // The Flutter tool sets the NDK version; onnxruntime's Android plugin
    // compiles against whatever version the app declares.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tmewai.app"
        // minSdk follows the Flutter floor (24 on Flutter 3.47) and is also the
        // floor of every Android plugin in the build: file_picker 21,
        // path_provider 21, onnxruntime 21. targetSdk is the current stable
        // API level, which keeps SAF and scoped-storage behaviour modern.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // A release APK is signed with the debug keys until a real keystore
            // is supplied; see NOTES.md for the release signing step.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ABI coverage is left to the Flutter tool's `--split-per-abi` flag instead
    // of a Gradle `splits` block, so both paths stay identical. onnxruntime
    // ships arm64-v8a and armeabi-v7a only; see NOTES.md for what that means
    // for x86_64 emulator builds.
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
