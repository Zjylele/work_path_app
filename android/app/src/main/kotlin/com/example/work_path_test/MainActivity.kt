package com.example.work_path_test

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        preloadAmapLibrary()
        super.onCreate(savedInstanceState)
    }

    /**
     * 在主线程预加载高德 SDK 的 so 库。
     *
     * 背景：高德 SDK 在 TextureView 渲染线程（GLThread）上首次加载 so 时，
     * JNI 使用系统 ClassLoader 执行 FindClass，找不到 SDK 类，导致
     * "JNI DETECTED ERROR IN APPLICATION: java_class == null in call to GetStaticMethodID" 崩溃
     * （Android 12+ 严格校验后必现）。在主线程提前 loadLibrary 可让 JNI_OnLoad
     * 在正确的 ClassLoader 上下文中执行。
     */
    private fun preloadAmapLibrary() {
        try {
            System.loadLibrary("AMapSDK_MAP_v11_2_100")
            System.loadLibrary("apssdk")
        } catch (t: Throwable) {
            // 加载失败不阻断启动，由 SDK 运行时自行处理
        }
    }
}
