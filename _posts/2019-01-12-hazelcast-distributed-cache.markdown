---
title:  "Simple Hazelcast configuration in Spring Boot 2 application. "
excerpt: "How to configure Hazelcast in Spring Boot 2. Simple use of Hazelcast in small distributed system."
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2018-06-10 12:35:00 +0200
tags: hazelcast spring-boot kotlin docker
---
In one of the projects I have to use Hazelcast so I decided it was a good idea to run a simple project consisting of two applications on separate docker containers. The first application will perform the task of the cache server and simultaneously write to it, and the second will read from the cache. The second application will have a REST controller with the help of which you will be able to view the data saved in the cache.
Gradle configurations allow you to create two docker images, simplifying the launch of two applications. 

This is root project `build.gradle` file:

~~~ 
buildscript {
    ext {
        kotlinVersion = '1.2.71'
        springBootVersion = '2.1.1.RELEASE'
        gradleDockerVersion   = "1.2"
    }
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath("org.springframework.boot:spring-boot-gradle-plugin:${springBootVersion}")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${kotlinVersion}")
        classpath("org.jetbrains.kotlin:kotlin-allopen:${kotlinVersion}")
        classpath("se.transmode.gradle:gradle-docker:${gradleDockerVersion}")
    }

}

allprojects {
    group = 'pl.codeaddict'
    version = '0.0.1-SNAPSHOT'
}

subprojects {
    repositories {
        mavenLocal()
        mavenCentral()
    }
}
~~~

...and here is `build.gradle` file for **demo-hazelcast-cache**:

~~~
plugins {
    id 'kotlin'
    id 'kotlin-spring'
    id 'eclipse'
    id 'org.springframework.boot'
    id 'io.spring.dependency-management'
    id 'application'
    id 'docker'
}

mainClassName = 'pl.codeaddict.demohazelcast.cache.DemoHazelcastApplicationCacheKt'
sourceCompatibility = 1.8
compileKotlin {
    kotlinOptions {
        freeCompilerArgs = ["-Xjsr305=strict"]
        jvmTarget = "1.8"
    }
}
compileTestKotlin {
    kotlinOptions {
        freeCompilerArgs = ["-Xjsr305=strict"]
        jvmTarget = "1.8"
    }
}

jar {
    manifest { attributes 'Main-Class': "$mainClassName" }
    from { configurations.compile.collect { it.isDirectory() ? it : zipTree(it) } }
}

docker {
    maintainer = 'Michal Kostewicz <m.kostewicz84@gmail.com>'
    baseImage "frolvlad/alpine-oraclejdk8:slim"
}

task copyTar(type: Copy) {
    from file("$buildDir/distributions/demo-hazelcast-cache-0.0.1-SNAPSHOT.tar")
    into file("$buildDir/docker")
}

task appDocker(type: Docker) {
    dependsOn 'copyTar'
    addFile('demo-hazelcast-cache-0.0.1-SNAPSHOT.tar', '/')
    entryPoint( ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/demo-hazelcast-cache-0.0.1-SNAPSHOT/lib/demo-hazelcast-cache-0.0.1-SNAPSHOT.jar"])
}

dependencies {
    implementation('org.springframework.boot:spring-boot-starter')
    implementation('com.fasterxml.jackson.module:jackson-module-kotlin')
    implementation('com.hazelcast:hazelcast:3.11.1')
    implementation('com.hazelcast:hazelcast-spring:3.11.1')
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    testImplementation('org.springframework.boot:spring-boot-starter-test')
    testImplementation('io.projectreactor:reactor-test')
}

~~~

The **demo-hazelcast-cache** application is designed to create a Hazelcast configuration that will be available in a distributed system and to save simple information in cache at specified intervals. This application does not have any user interface.
The following code shows the simple Hazelcast configuration:
~~~kotlin
@Configuration
class HazelcastConfiguration {
    @Bean
    fun hazelCastConfig(): Config {
        val config = Config()
        config
                .addMapConfig(
                        MapConfig()
                                .setName("configuration")
                                .setMaxSizeConfig(MaxSizeConfig(200, MaxSizeConfig.MaxSizePolicy.FREE_HEAP_SIZE))
                                .setEvictionPolicy(EvictionPolicy.LRU)
                                .setTimeToLiveSeconds(-1))
        return config
    }
}
~~~
I will not discuss individual configuration parameters, you can read about them in the [Hazelcast documentation](https://docs.hazelcast.org/docs/3.11.1/javadoc/). 
The following code deals with saving the example information in the cache:
~~~kotlin
@Service
class ScheduledTasks {
    val key = "MY_KEY"

    @Autowired
    private val hazelcastInstance: HazelcastInstance? = null

    @Scheduled(fixedRate = 1000)
    fun changeHazelcastMap() {
        val hazelcastMap: IMap<String, Int> = hazelcastInstance?.getMap("my-map")!!
        if(!hazelcastMap.containsKey(key)){
            hazelcastMap.put(key,0)
        }else{
            var previousInteger: Int = hazelcastMap.get(key)!!
            val nextInteger = ++previousInteger
            hazelcastMap.put(key, nextInteger)
        }
    }
}
~~~
Task of second application **demo-hazelcast-client** is to read from the common cache and show results through the REST controller ([localhost:8080/hazelcast/stream](localhost:8080/hazelcast/stream)). First, let's look at the `build.gradle` file:
~~~
plugins {
    id 'kotlin'
    id 'kotlin-spring'
    id 'eclipse'
    id 'org.springframework.boot'
    id 'io.spring.dependency-management'
    id 'application'
    id 'docker'
}

mainClassName = 'pl.codeaddict.demohazelcast.client.DemoHazelcastApplicationClientKt'
sourceCompatibility = 1.8
compileKotlin {
    kotlinOptions {
        freeCompilerArgs = ["-Xjsr305=strict"]
        jvmTarget = "1.8"
    }
}
compileTestKotlin {
    kotlinOptions {
        freeCompilerArgs = ["-Xjsr305=strict"]
        jvmTarget = "1.8"
    }
}

jar {
    manifest { attributes 'Main-Class': "$mainClassName" }
    from { configurations.compile.collect { it.isDirectory() ? it : zipTree(it) } }
}

docker {
    maintainer = 'Michal Kostewicz <m.kostewicz84@gmail.com>'
    baseImage "frolvlad/alpine-oraclejdk8:slim"
}

task copyTar(type: Copy) {
    from file("$buildDir/distributions/demo-hazelcast-client-0.0.1-SNAPSHOT.tar")
    into file("$buildDir/docker")
}

task appDocker(type: Docker) {
    dependsOn 'copyTar'
    addFile('demo-hazelcast-client-0.0.1-SNAPSHOT.tar', '/')
    entryPoint( ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/demo-hazelcast-client-0.0.1-SNAPSHOT/lib/demo-hazelcast-client-0.0.1-SNAPSHOT.jar"])
}

dependencies {
    implementation('org.springframework.boot:spring-boot-starter-web')
    implementation('org.springframework.boot:spring-boot-starter-webflux')
    implementation('com.fasterxml.jackson.module:jackson-module-kotlin')
    implementation('com.hazelcast:hazelcast-client:3.11.1')
    implementation('com.hazelcast:hazelcast-spring:3.11.1')
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    testImplementation('org.springframework.boot:spring-boot-starter-test')
    testImplementation('io.projectreactor:reactor-test')
}

~~~

The following code shows the simple Hazelcast client configuration:
~~~kotlin
@Configuration
class HazelcastConfiguration {
    @Bean
    fun clientConfig(): ClientConfig {
        val clientConfig = ClientConfig()
        val networkConfig = clientConfig.getNetworkConfig()
        networkConfig.addAddress("demo-hazelcast-cache:5701", "demo-hazelcast-cache:5702")
                .setSmartRouting(true)
                .addOutboundPortDefinition("34700-34710")
                .setRedoOperation(true)
                .setConnectionTimeout(5000)
                .setConnectionAttemptLimit(5)

        return clientConfig

    }

    @Bean
    fun hazelcastInstance(clientConfig: ClientConfig): HazelcastInstance {
        return HazelcastClient.newHazelcastClient(clientConfig)
    }

}
~~~
This time there is one element that I will discuss. In `addAddress("demo-hazelcast-cache:5701", "demo-hazelcast-cache:5702")` I'm using docker container addresses (hosts names are configured in docker-compose.yml).
As I wrote earlier, the application provides a REST controller:
~~~kotlin
@RestController
class HazelcastClientController {
    val key = "MY_KEY"

    @Autowired
    private val hazelcastInstance: HazelcastInstance? = null

    @GetMapping(value = "/hazelcast/stream", produces = arrayOf(MediaType.TEXT_EVENT_STREAM_VALUE))
    @ResponseBody
    fun streamHazelcastMap(): Flux<String> {
        val hazelcastMap: IMap<String, Int> = hazelcastInstance?.getMap("my-map")!!
        return Flux
                .interval(Duration.ofMillis(1100))
                .map { tick ->  "NEW VALUE: " + hazelcastMap.get(key) }
    }
}
~~~
You can see that I am using the same key (`MY_KEY`) when extracting data from the cache as if they were saved in the first application. 
Controller works in the [Sent-Events](https://www.w3schools.com/html/html5_serversentevents.asp) technology and streams information every 1100 ms.

You can start both applications by running gradle build job with `appDocker` task which creates docker images: `./gradlew build appDocker`. After creating images you can use simple docker-compose command to start both apps: `cd docker && docker-compose up`.

This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/hazelcast-demo). 
Have fun and thanks for reading!

