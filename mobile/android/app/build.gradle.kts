import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Khoá ký bản phát hành. Tệp key.properties và .jks đều nằm ngoài repo
// (xem .gitignore) — mật khẩu không bao giờ được vào lịch sử git.
//
// Thiếu tệp thì KHÔNG làm vỡ build: bản release rơi về khoá debug để người
// trong nhóm chưa có khoá vẫn dựng và chạy thử được. Nhưng bản ký bằng khoá
// debug thì đừng phát ra ngoài — ai cũng ký lại được bản giả mang đúng danh
// tính app. Dòng cảnh báo bên dưới in ra mỗi lần dựng để khỏi quên.
val thongTinKhoa = Properties()
val tepKhoa = rootProject.file("key.properties")
val coKhoaThat = tepKhoa.exists()
if (coKhoaThat) {
    FileInputStream(tepKhoa).use { thongTinKhoa.load(it) }
} else {
    logger.warn("CẢNH BÁO: không thấy android/key.properties — bản release sẽ ký bằng khoá debug, chỉ dùng nội bộ.")
}

android {
    namespace = "com.histojourney.historiai"
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
        applicationId = "com.histojourney.historiai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (coKhoaThat) {
            create("release") {
                keyAlias = thongTinKhoa.getProperty("keyAlias")
                keyPassword = thongTinKhoa.getProperty("keyPassword")
                storePassword = thongTinKhoa.getProperty("storePassword")
                // Đường dẫn trong key.properties tính từ thư mục android/,
                // không phải android/app/ — dùng rootProject cho khỏi lệch.
                storeFile = rootProject.file(thongTinKhoa.getProperty("storeFile"))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (coKhoaThat) "release" else "debug"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider: trao tệp bản cài vừa tải cho trình cài đặt của Android (MainActivity.kt).
    implementation("androidx.core:core:1.13.1")
}
