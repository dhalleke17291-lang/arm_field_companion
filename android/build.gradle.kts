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

// Force single version of androidx.activity across ALL subprojects (plugins included)
// to prevent duplicate R class during DEX merge.
subprojects {
    project.configurations.configureEach {
        resolutionStrategy {
            force("androidx.activity:activity-ktx:1.9.2")
            force("androidx.activity:activity:1.9.2")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
