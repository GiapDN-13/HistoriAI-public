package com.histojourney.historiai

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Kênh "historiai/cai_dat" cho lib/core/ban_moi.dart: app tự tải bản cài mới rồi
 * mở màn cài của Android — người dùng chỉ còn bấm "Cài đặt".
 *
 * Không cài lặng lẽ được (Android không cho app ngoài CH Play làm vậy). Lần đầu,
 * trình cài đặt của máy sẽ hỏi có cho HistoriAI cài ứng dụng không; bật xong quay
 * lại là cài tiếp. Bản mới phải ký cùng khoá với bản đang cài, không thì Android từ chối.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "historiai/cai_dat")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "abi" -> result.success(Build.SUPPORTED_ABIS.toList())
                    // Android 8+: phải được người dùng cho phép "cài ứng dụng không rõ nguồn".
                    "choPhepCai" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    // Mở thẳng công tắc của HistoriAI. Không đi đường "Cài đặt" trong hộp
                    // cảnh báo của trình cài: trên Android 14 bật xong quay lại là mất
                    // màn cài, người dùng về app mà chưa cài gì (thấy trên giả lập 28/09).
                    "moQuyenCai" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")))
                        }
                        result.success(true)
                    }
                    "thuMuc" -> {
                        val d = File(cacheDir, "ban_moi")
                        d.mkdirs()
                        result.success(d.absolutePath)
                    }
                    "cai" -> {
                        try {
                            val tep = File(call.argument<String>("duong_dan")!!)
                            // Chỉ cài tệp nằm trong thư mục bản cài của chính app.
                            if (tep.parentFile?.canonicalPath != File(cacheDir, "ban_moi").canonicalPath) {
                                result.error("SAI_CHO", "tệp ngoài thư mục bản cài", null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(this, "$packageName.cai_dat", tep)
                            val y = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(y)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOI", e.toString(), null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
