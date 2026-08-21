allprojects {
    repositories {
        // 阿里云镜像（原 google()/mavenCentral() 网络不通）
        maven(url = "https://maven.aliyun.com/repository/google")
        maven(url = "https://maven.aliyun.com/repository/public")
        // 高德 3D 地图 SDK（8.x 在 jcenter 镜像；9.0.0~9.7.0 在 public 镜像，9.8.0+ 官方仓库当前网络不可达）
        maven(url = "https://maven.aliyun.com/repository/jcenter")
        // Flutter 官方 maven 镜像（flutter_embedding 等）
        maven(url = "https://storage.flutter-io.cn/download.flutter.io")
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
