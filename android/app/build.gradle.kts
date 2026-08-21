plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// 读取 local.properties（已被 .gitignore 排除，不进仓库），
// 获取高德 API key 注入 AndroidManifest 占位符，避免明文 key 提交到公开仓库。
val localProperties = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.example.work_path_test"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.work_path_test"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 注入高德 API key 到 Manifest 占位符 ${AMAP_API_KEY}
        manifestPlaceholders["AMAP_API_KEY"] =
            localProperties.getProperty("AMAP_API_KEY") ?: "PLACEHOLDER_FILL_IN_LOCAL_PROPERTIES"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // 禁用 R8 压缩/混淆：高德 SDK 大量通过 JNI FindClass 引用类，
            // R8 收缩会删除 native 引用的类，导致 "java_class == null" 崩溃。
            // （模拟器 debug 包不混淆所以一直正常；真机 release 包混淆后必现）
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 高德 3D 地图 SDK 合包（3dmap 11.2.100 + search 9.8.1 + location 11.2.100）：
    // 本地引入。9.7.0 及以下的加固壳不兼容 Android 14/15/16（报"加固技术未适配"/JNI 崩溃），
    // 且 9.8.0+ 无法从 Maven 拉取（官方仓库网络不通），故下载官网 V11.2.100 合包放入 libs。
    implementation(files("libs/AMap3DMap_11.2.100_AMapSearch_9.8.1_AMapLocation_11.2.100_20260805.jar"))
    // 高德定位 SDK 依赖的快速数学库（net.jafama.FastMath），R8 缺类报错
    implementation("net.jafama:jafama:2.3.0")
    // so 库放于 src/main/jniLibs（arm64-v8a / armeabi-v7a），由 AGP 自动打入 APK
}

flutter {
    source = "../.."
}
