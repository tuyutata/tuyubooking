import groovy.json.JsonSlurper

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val flutterProjectRoot = System.getenv("TUYUBOOKING_PROJECT_ROOT")
                ?.let { java.io.File(it) }
                ?: settingsDir.parentFile
            flutterProjectRoot.resolve("android/local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Flutter插件清单来自本产品当前执行根；Gradle设置本身只在真实android根执行，
// 不再通过缓存视图中的跨根符号链接建立第二个Gradle根。
val flutterProjectRoot = System.getenv("TUYUBOOKING_PROJECT_ROOT")
    ?.let { java.io.File(it) }
    ?: settingsDir.parentFile
val flutterPlugins = flutterProjectRoot.resolve(".flutter-plugins-dependencies")
if (flutterPlugins.isFile) {
    val metadata = JsonSlurper().parse(flutterPlugins) as Map<*, *>
    val androidPlugins = (metadata["plugins"] as? Map<*, *>)?.get("android") as? List<*> ?: emptyList<Any>()
    androidPlugins.filterIsInstance<Map<*, *>>()
        .filter { it["native_build"] != false }
        .forEach { plugin ->
            val name = plugin["name"] as String
            include(":$name")
            project(":$name").projectDir = java.io.File(plugin["path"] as String, "android")
        }
}

include(":app")
