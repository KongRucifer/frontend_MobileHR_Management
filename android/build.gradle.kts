allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// The main Android SDK is under Program Files (read-only), so the NDK required
// by native deps (e.g. Firebase) was installed to a writable location. Force
// EVERY Android module (app + plugins) to use it, so no module tries to auto-
// download an NDK into the read-only SDK (which would fail the licence check).
// Hooked at plugin-apply time (before AGP resolves the NDK) and set via
// reflection to avoid needing the AGP classpath in this root script.
subprojects {
    plugins.withId("com.android.base") {
        extensions.findByName("android")?.let { ext ->
            runCatching {
                ext.javaClass.methods
                    .firstOrNull { it.name == "setNdkPath" && it.parameterCount == 1 }
                    ?.invoke(ext, "C:/Users/kpyou/AppData/Local/Android/Sdk/ndk/28.2.13676358")
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
