import org.gradle.api.tasks.testing.logging.TestLogEvent.*

plugins {
    kotlin("jvm") version "1.6.0"
    id("com.lovelysystems.gradle") version "1.15.0"
}

repositories {
    mavenCentral()
    maven("https://raw.github.com/lovelysystems/maven/master/releases")
}

dependencies {
    testImplementation("com.lovelysystems:lovely-db-testing:0.0.4")
    testImplementation("org.junit.jupiter:junit-jupiter:5.8.1")
    testImplementation(kotlin("test-junit5"))
}

tasks.withType<Test> {
    // always run tests
    outputs.upToDateWhen { false }
    useJUnitPlatform()
    dependsOn("buildDockerImage")
    testLogging {
        showStandardStreams = true
        events = setOf(PASSED, SKIPPED, FAILED)
    }
}


lovely {
    gitProject()
    dockerProject("ghcr.io/lovelysystems/lovely-db-commons") {
        from("docker")
        from("src/main/sql") {
            into("schema/sql")
        }
    }
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}
