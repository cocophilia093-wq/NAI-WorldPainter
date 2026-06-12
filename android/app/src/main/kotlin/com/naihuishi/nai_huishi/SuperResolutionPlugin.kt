package com.naihuishi.nai_huishi

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.IOException
import java.io.InputStreamReader
import kotlin.concurrent.thread

/**
 * 图片超分原生插件。
 *
 * 设计要点：
 * 1. 可执行文件以 librealsr.so / librealcugan.so 形式打包进 jniLibs，
 *    APK 安装后被解压到 applicationInfo.nativeLibraryDir —— 这是 Android 10+
 *    W^X 策略下唯一允许执行 ELF 的目录。
 * 2. 模型从 assets/sr_models 释放到 filesDir/sr_models（只读数据，放哪都行）。
 * 3. 通过 ProcessBuilder 直接执行可执行文件（不经过 sh，避免命令注入），
 *    用 EventChannel 把 stdout/stderr 的进度行流式回传给 Dart。
 *
 * ncnn CLI 参数（已从二进制确认）：
 *   realsr-ncnn   -i in -o out -s 4 -m <modelDir>  (Real-ESRGAN-anime 仅 x4)
 *   realcugan-ncnn -i in -o out -s 2|4 -m <modelDir> -n -1  (conservative)
 *   -g -1 表示 CPU 模式（最稳，规避 Vulkan 兼容问题）
 *   CPU 模式下默认 tilesize=auto + syncgap=3 在 RealCUGAN 容易触发内部断言/OOM
 *   导致退出码 255，因此显式 -t 100 -c 0 -j 2:1:2 控制内存与稳定性。
 */
class SuperResolutionPlugin : FlutterPlugin {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context

    private var eventSink: EventChannel.EventSink? = null
    @Volatile private var currentProcess: Process? = null
    @Volatile private var canceled: Boolean = false

    /** 最近的若干行原生输出，失败时附在错误消息中便于定位。 */
    private val tailBuf = ArrayDeque<String>()
    private val tailLock = Any()
    private fun appendTail(line: String) {
        synchronized(tailLock) {
            tailBuf.addLast(line)
            while (tailBuf.size > 20) tailBuf.removeFirst()
        }
    }
    private fun clearTail() = synchronized(tailLock) { tailBuf.clear() }
    private fun snapshotTail(): String =
        synchronized(tailLock) { tailBuf.joinToString("\n") }

    companion object {
        private const val METHOD_CHANNEL = "com.naihuishi.nai_huishi/super_resolution"
        private const val EVENT_CHANNEL = "com.naihuishi.nai_huishi/super_resolution_progress"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)

        methodChannel.setMethodCallHandler { call, result -> onMethodCall(call, result) }
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareAssets" -> {
                thread {
                    try {
                        val dir = releaseModels()
                        runOnMain { result.success(dir) }
                    } catch (e: Exception) {
                        runOnMain { result.error("PREPARE_FAILED", e.message, null) }
                    }
                }
            }
            "upscale" -> {
                val input = call.argument<String>("inputPath")
                val output = call.argument<String>("outputPath")
                val engine = call.argument<String>("engine") // "realsr" | "realcugan"
                val scale = call.argument<Int>("scale") ?: 4
                val modelDir = call.argument<String>("modelDir")
                if (input == null || output == null || engine == null || modelDir == null) {
                    result.error("BAD_ARGS", "缺少必要参数", null)
                    return
                }
                canceled = false
                clearTail()
                thread {
                    try {
                        val code = runUpscale(engine, input, output, scale, modelDir)
                        runOnMain {
                            if (canceled) {
                                result.error("CANCELED", "已取消", null)
                            } else if (code == 0) {
                                result.success(output)
                            } else {
                                val tail = snapshotTail().ifBlank { "(无输出)" }
                                result.error("EXEC_FAILED", "退出码 $code\n$tail", null)
                            }
                        }
                    } catch (e: Exception) {
                        // 取消时主动 destroy 进程，readLine 抛 IOException 属正常路径
                        if (canceled) {
                            runOnMain { result.error("CANCELED", "已取消", null) }
                            return@thread
                        }
                        runOnMain {
                            val tail = snapshotTail()
                            val msg = if (tail.isBlank()) e.message else "${e.message}\n$tail"
                            result.error("EXEC_EXCEPTION", msg, null)
                        }
                    }
                }
            }
            "cancel" -> {
                canceled = true
                currentProcess?.destroy()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** 把 assets/sr_models 整树复制到 filesDir/sr_models，返回该目录绝对路径。 */
    private fun releaseModels(): String {
        val targetRoot = File(appContext.filesDir, "sr_models")
        copyAssetDir("sr_models", targetRoot)
        return targetRoot.absolutePath
    }

    private fun copyAssetDir(assetPath: String, target: File) {
        val am = appContext.assets
        val children = am.list(assetPath) ?: arrayOf()
        if (children.isEmpty()) {
            // 是文件：复制
            target.parentFile?.mkdirs()
            am.open(assetPath).use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
        } else {
            // 是目录：递归
            target.mkdirs()
            for (child in children) {
                copyAssetDir("$assetPath/$child", File(target, child))
            }
        }
    }

    private fun runUpscale(
        engine: String,
        input: String,
        output: String,
        scale: Int,
        modelDir: String,
    ): Int {
        val libDir = appContext.applicationInfo.nativeLibraryDir
        val execName = when (engine) {
            "realsr" -> "librealsr.so"
            "realcugan" -> "librealcugan.so"
            else -> throw IllegalArgumentException("未知引擎 $engine")
        }
        val exec = File(libDir, execName)
        if (!exec.exists()) {
            throw IllegalStateException("找不到可执行文件: ${exec.absolutePath}")
        }

        val cmd = mutableListOf(
            exec.absolutePath,
            "-i", input,
            "-o", output,
            "-s", scale.toString(),
            "-m", modelDir,
            "-g", "-1",
        )
        if (engine == "realcugan") {
            // conservative 模型对应 noise = -1
            cmd.add("-n"); cmd.add("-1")
            // CPU 模式下 tilesize=auto + syncgap=3 在 RealCUGAN 容易导致退出 255
            // (内部断言 / OOM)。显式限制 tilesize=100、关闭 syncgap=0、降低线程
            // 以换取稳定性。
            cmd.add("-t"); cmd.add("100")
            cmd.add("-c"); cmd.add("0")
            cmd.add("-j"); cmd.add("2:1:2")
        } else if (engine == "realsr") {
            // realsr CPU 同样限制 tilesize 防 OOM
            cmd.add("-t"); cmd.add("100")
            cmd.add("-j"); cmd.add("2:1:2")
        }

        val pb = ProcessBuilder(cmd)
        pb.redirectErrorStream(true)
        // ncnn 依赖库与可执行文件同在 nativeLibraryDir，安装时已就位；
        // 仍显式声明 LD_LIBRARY_PATH 保证 dlopen 能找到 libncnn/libomp/libc++_shared。
        pb.environment()["LD_LIBRARY_PATH"] = libDir

        val process = pb.start()
        currentProcess = process

        try {
            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                while (true) {
                    val text = try {
                        reader.readLine() ?: break
                    } catch (_: IOException) {
                        // 进程被 destroy / pipe 关闭：正常路径，让 waitFor() 决定退出码
                        break
                    }
                    if (text.contains("unused DT entry")) continue
                    appendTail(text)
                    runOnMain { eventSink?.success(text) }
                }
            }
        } catch (_: IOException) {
            // 同上，吞掉 use{} 在关闭流时可能再次抛出的 IOException
        }
        val code = process.waitFor()
        currentProcess = null
        return code
    }

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private fun runOnMain(block: () -> Unit) = mainHandler.post(block)
}
