// AGP与KGP必须由同一个根classpath解析，避免settings先锁定AGP内置的另一版KGP。
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val productBuildValue = providers.environmentVariable("TUYUBOOKING_BUILD_DIR").orNull
    ?.takeIf { it.isNotBlank() }
    ?: "${System.getProperty("java.io.tmpdir")}/tuyubooking/android"
val productBuildFile = file(productBuildValue).canonicalFile
val productSourcePath = rootProject.projectDir.parentFile.canonicalFile.toPath()
require(productBuildFile.isAbsolute && !productBuildFile.toPath().startsWith(productSourcePath)) {
    "TUYUBOOKING_BUILD_DIR必须是TuyuBooking源码外的绝对目录"
}
rootProject.layout.buildDirectory.fileValue(productBuildFile)
val newBuildDir: Directory = rootProject.layout.buildDirectory.get()

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
