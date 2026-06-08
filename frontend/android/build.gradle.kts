buildscript {
    repositories {
        // 阿里云镜像（国内加速，放最前面优先命中）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
    dependencies {
        // FCM 推送：google-services 插件（用 classpath 方式拉取实际工件，国内镜像有）
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        // 阿里云镜像（国内加速，放最前面优先命中）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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
// 统一所有子工程（含三方插件，如 workmanager / another_telephony）的 JVM 目标为 17，
// 修复老插件 Java(11)/Kotlin(1.8) 编译目标不一致导致的 "Inconsistent JVM-target" 构建失败。
// 注意：必须放在下面 evaluationDependsOn(":app") 之前注册，否则 :app 已被评估会报错。
subprojects {
    afterEvaluate {
        // Java 目标：通过 AGP 的 compileOptions 设置（直接设 JavaCompile 任务会被 AGP 覆盖）
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        // Kotlin 目标：放在 afterEvaluate 内，确保覆盖老插件自带的 kotlinOptions.jvmTarget="1.8"
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
