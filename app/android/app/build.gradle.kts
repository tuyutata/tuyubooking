import groovy.json.JsonSlurper
import java.util.Properties

plugins {
    id("com.android.application")
    // AGP提供内置Kotlin；Flutter插件在Android插件之后应用。
    id("dev.flutter.flutter-gradle-plugin")
}

val flutterProductRoot = System.getenv("TUYUBOOKING_PROJECT_ROOT")
    ?.let { file(it) }
    ?: rootProject.projectDir.parentFile
val flutterBuildProperties = Properties().apply {
    flutterProductRoot.resolve("android/local.properties").inputStream().use { load(it) }
}
val productVersionCode = flutterBuildProperties.getProperty("flutter.versionCode", "1").toInt()
val productVersionName = flutterBuildProperties.getProperty("flutter.versionName", "1.0")

android {
    namespace = "com.tuyulove.tuyubooking"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Android is always the employee client installation product.
        applicationId = "com.tuyulove.tuyubooking.client"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = productVersionCode
        versionName = productVersionName
    }

    buildTypes {
        release {
            // Release artifacts stay unsigned in the source tree. The Release
            // workflow injects the official key and verifies the final signature.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    // Android工程从真实源码根执行；Flutter生成文件只从当前任务缓存根读取。
    source = System.getenv("TUYUBOOKING_PROJECT_ROOT") ?: "../.."
}

// 安装名称读取现有产品语言资源，生成物仅写入当前平台的产品构建目录。
// AGP 9 consumes generated resources through a typed task output.
abstract class GenerateAppNameResources : DefaultTask() {
    @get:org.gradle.api.tasks.OutputDirectory
    abstract val generatedResources: org.gradle.api.file.DirectoryProperty
}

val appNameResources = layout.buildDirectory.dir("generated/app-name/res")
val appNameSources = mapOf(
    "values" to layout.projectDirectory.file("../../lib/shared/localization/resources/app_en.arb"),
    "values-zh" to layout.projectDirectory.file("../../lib/shared/localization/resources/app_zh.arb"),
)
val generateAppNameResources = tasks.register<GenerateAppNameResources>("generateAppNameResources") {
    generatedResources.set(appNameResources)
    inputs.files(appNameSources.values)
    outputs.dir(appNameResources)
    doLast {
        appNameSources.forEach { (qualifier, source) ->
            val document = JsonSlurper().parse(source.asFile) as Map<*, *>
            val title = document["appTitle"] as? String
                ?: throw GradleException("产品语言资源缺少安装名称")
            require(title.isNotBlank() && !title.contains("\n")) { "安装名称不能为空或包含换行" }
            val escaped = title.replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace("\"", "&quot;")
            val output = appNameResources.get().file("$qualifier/strings.xml").asFile
            output.parentFile.mkdirs()
            output.writeText("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources><string name=\"app_name\">$escaped</string></resources>\n", Charsets.UTF_8)
        }
    }
}
// Let AGP carry the generation dependency into every resource-consuming variant.
androidComponents.onVariants { variant ->
    variant.sources.res?.addGeneratedSourceDirectory(
        generateAppNameResources,
        GenerateAppNameResources::generatedResources,
    )
}
