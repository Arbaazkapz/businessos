import com.android.build.api.variant.LibraryAndroidComponentsExtension

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
// SHOPHISAB LIBRARY SDK
subprojects {
    // Older plugins may declare API 34 while their dependencies require API 36.
    // Align compilation only; each plugin keeps its own minimum/target SDK.
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryAndroidComponentsExtension> {
            finalizeDsl { library ->
                library.compileSdk = maxOf(library.compileSdk ?: 0, 36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
