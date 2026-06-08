plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FCM 推送：解析 google-services.json（用 classpath 方式应用，须在 Android 插件之后）
apply(plugin = "com.google.gms.google-services")

android {
    namespace = "com.example.express_pickup"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // 打包阶段强制剔除 x86/x86_64 的原生库（含 ML Kit 的 .so）。
    // 这些架构只有电脑模拟器用，所有真手机都是 ARM，剔除后省约 30MB、兼容性不受影响。
    packaging {
        jniLibs {
            excludes += listOf("**/x86/**", "**/x86_64/**")
        }
    }

    compileOptions {
        // flutter_local_notifications 17.x 需要 core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.express_pickup"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 只保留真手机的两种 ARM 架构，去掉只有模拟器用的 x86/x86_64，
        // 省下 ML Kit 等库的 x86 副本（约 11MB+），真手机兼容性不受影响。
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // 关闭 R8 代码压缩：避免它把 workmanager / another_telephony 等新插件
            // 反射用到的类删掉，导致 release 包一启动就闪退。包会略大但更稳。
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // ML Kit 中文文字识别：插件把它声明为 compileOnly（不打包），
    // 用中文截图 OCR 必须由 App 显式引入，否则运行时 ClassNotFoundException 闪退。
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}
