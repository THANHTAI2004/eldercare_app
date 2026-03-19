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
    // Keep shared build output for local modules, but avoid redirecting
    // pub-cache plugins across Windows drive roots (for example C: -> D:).
    val projectDriveRoot = project.projectDir.toPath().root?.toString()
    val rootProjectDriveRoot = rootProject.projectDir.toPath().root?.toString()
    if (projectDriveRoot == rootProjectDriveRoot) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
