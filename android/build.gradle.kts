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
subprojects {
    project.evaluationDependsOn(":app")
}

// The API level the app compiles against (`flutter.compileSdkVersion`), read off
// the Flutter Gradle plugin's extension on :app. The fallback is the value Flutter
// 3.47 sets, so a future rename in that plugin cannot break the build here.
val appCompileSdkVersion: Int by lazy {
    val flutterExtension = project(":app").extensions.findByName("flutter")
    val getter =
        flutterExtension?.javaClass?.methods?.firstOrNull {
            it.name == "getCompileSdkVersion" && it.parameterTypes.isEmpty()
        }
    (getter?.invoke(flutterExtension) as? Int) ?: 36
}

// Every Android module must compile against an API level at least as new as the
// app's: the Flutter embedding pulls in AndroidX artifacts (fragment 1.7.1,
// lifecycle 2.7.0, …) that refuse to be linked from a module built against 33,
// and AGP reads the value from each module's own build script. Plugins published
// before API 34 still pin `compileSdkVersion 33` there — onnxruntime 1.4.1 does,
// and it ships no sources at all, only prebuilt `jniLibs` — so raising the value
// here is the only place that can fix a dependency the pub cache owns.
subprojects {
    // :app is already evaluated here (see `evaluationDependsOn` above), so it is
    // configured directly; the plugin modules still get their afterEvaluate.
    val module = this
    fun raiseAndroidCompileSdk() {
        val android = module.extensions.findByName("android") ?: return
        val setter =
            android.javaClass.methods.firstOrNull { method ->
                method.name == "compileSdkVersion" &&
                    method.parameterTypes.size == 1 &&
                    (method.parameterTypes[0] == Int::class.javaPrimitiveType ||
                        method.parameterTypes[0] == Integer::class.java)
            }
        // Flutter's own modules are already at the app's level; a plugin too old
        // to expose the setter is left alone rather than failed here.
        setter?.invoke(android, appCompileSdkVersion)
    }
    if (state.executed) {
        raiseAndroidCompileSdk()
    } else {
        afterEvaluate { raiseAndroidCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
