---
title:  "How to write the first Kotlin code in Java project"
excerpt: "Adding Kotlin to an existing multi-module Java project"
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2020-10-30 10:01:00 +0200
tags: kotlin java 
---
Although JDK 15 was released a few weeks ago, unfortunately some programmers, especially in server applications development, still have to deal with a much older version of Java in their projects. This leads to frustration and very often people rotation in projects. The IT world is relentlessly rushing forward and as specialists in our profession, we would like to have access to the latest technologies that make our work more enjoyable, but also more efficient.

Programmers are cunning creatures and try to cope with using different libraries such as lombok, vavr, streamsupport or retrolambda, but using them (especially several at once) makes the configuration unreadable and sensitive to changes. I used to be in the position of a man who was looking for such solutions, and today, working mainly with the Kotlin language, I often wonder why I did not persuade the team to switch to this language.

I think the main factor that prevented me from doing this was the fear of possible problems with the project setup, the time it took to learn a new language and the need to convince the rest of the team. All this is also influenced by the fact that it is difficult to convince “business” to do it. We can often hear the sentence “If it's working, why break it”. Today, however, I know that such a transition is not difficult and I would like to share it with you and sincerely persuade you to do so.

For those who do not know the advantages of Kotlin, let's start by answering the question "Why is it worth switching to Kotlin at all?"
1. Java and Kotlin interoperability. In our project, we do not have to rewrite everything from scratch. All you have to do is create `kotlin` folder in `src/main` in addition to the `java` directory. We can safely call Java code from Kotlin and vice versa.
2. Kotlin compiles to JVM 6 by default so you can use it for really old projects. Newer versions of the JVM can also be used.
3. Simple to learn. Kotlin is inspired by existing languages, such as Java, C#, JavaScript, Scala, and Groovy. I am sure that the programmers of these languages will be able to start writing effectively in a new language within a few days.
4. Concise. Enabling the use of lambdas, extension functions, and higher-order functions. Thanks to this, we can get rid of all the libraries that I mentioned at the beginning of the text.
5. Safe. One of the most common pitfalls in many programming languages, is trying to access a reference element with a value of `null`. This, of course, results in the application throwing an exception, which in Java is `NullPointerException`. In Kotlin, the type system distinguishes between references that can contain `null` and those that cannot, which makes it much more difficult to go wrong.
6. Production ready. Behind Kotlin there are over a hundred engineers from JetBrains, a company known for the best IDE IntelliJ IDEA, and on the web you can find many examples of server applications that have been written or translated into Kotlin. My company is also working on such projects and they are implemented successfully.
7. Automatic Java code conversion to Kotlin in Intellij IDEA. This may not be a adventage of the language itself, but it is a feature that helps make the transition to Kotlin a lot. Every Java example you find on the web is simply pasted into the IDE, which converts it to Kotlin. The converted code this way is not perfect, but it is fully usable. I wouldn't be honest if I didn't mention that but there are probably few percent examples that we have to fix manually.

Ok, once we've answered the question is it worth it, we need to think about how to do it. I assume you are using some kind of build tool in your projects. So let's start with Maven.

For example, I used the first multi-module project that I found on Google by typing ["github maven multi module"](https://github.com/jitpack/maven-modular) .

Project root configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  
  <groupId>io.jitpack</groupId>
  <artifactId>example-root</artifactId>
  <version>2.0-SNAPSHOT</version>
  <packaging>pom</packaging>
  <name>example-root</name>
  
  <modules>
    <module>module1</module>
    <module>module2</module>
  </modules>
  
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.2</version>
        <configuration> <!-- Compile java 7 compatible bytecode -->
          <source>1.7</source>
          <target>1.7</target>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```
It's time to add Kotlin. So I add some necessary elements to the main `pom.xml`:
1. The variable with the Kotlin version we will use:

```xml
 <properties>
    <kotlin.version>1.4.10</kotlin.version>
  </properties>
```

2. Kotlin standard library dependency which provides many useful functions:

```xml
 <dependencies>
    <dependency>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-stdlib</artifactId>
      <version>${kotlin.version}</version>
    </dependency>
  </dependencies>
```

3. We add to the `build` section the configuration of the source code paths and a plugin that compiles Kotlin's source code:

```xml
<sourceDirectory>${project.basedir}/src/main/kotlin</sourceDirectory>
<testSourceDirectory>${project.basedir}/src/test/kotlin</testSourceDirectory>

    <plugins>
      <plugin>
        <groupId>org.jetbrains.kotlin</groupId>
        <artifactId>kotlin-maven-plugin</artifactId>
        <version>${kotlin.version}</version>
        <executions>
          <execution>
            <id>compile</id>
            <goals>
              <goal>compile</goal>
            </goals>
            <configuration>
              <sourceDirs>
                <sourceDir>${project.basedir}/src/main/kotlin</sourceDir>
                <sourceDir>${project.basedir}/src/main/java</sourceDir>
              </sourceDirs>
            </configuration>
          </execution>
          <execution>
            <id>test-compile</id>
            <goals> <goal>test-compile</goal> </goals>
            <configuration>
              <sourceDirs>
                <sourceDir>${project.basedir}/src/test/kotlin</sourceDir>
                <sourceDir>${project.basedir}/src/test/java</sourceDir>
              </sourceDirs>
            </configuration>
          </execution>
        </executions>
      </plugin>
```

The entire configuration looks like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  
  <groupId>io.jitpack</groupId>
  <artifactId>example-root</artifactId>
  <version>2.0-SNAPSHOT</version>
  <packaging>pom</packaging>
  <name>example-root</name>
  
  <modules>
    <module>module1</module>
    <module>module2</module>
  </modules>

  <properties>
    <kotlin.version>1.4.10</kotlin.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-stdlib</artifactId>
      <version>${kotlin.version}</version>
    </dependency>
  </dependencies>

  <build>
    <sourceDirectory>${project.basedir}/src/main/kotlin</sourceDirectory>
    <testSourceDirectory>${project.basedir}/src/test/kotlin</testSourceDirectory>

    <plugins>
      <plugin>
        <groupId>org.jetbrains.kotlin</groupId>
        <artifactId>kotlin-maven-plugin</artifactId>
        <version>${kotlin.version}</version>
        <executions>
          <execution>
            <id>compile</id>
            <goals>
              <goal>compile</goal>
            </goals>
            <configuration>
              <sourceDirs>
                <sourceDir>${project.basedir}/src/main/kotlin</sourceDir>
                <sourceDir>${project.basedir}/src/main/java</sourceDir>
              </sourceDirs>
            </configuration>
          </execution>
          <execution>
            <id>test-compile</id>
            <goals> <goal>test-compile</goal> </goals>
            <configuration>
              <sourceDirs>
                <sourceDir>${project.basedir}/src/test/kotlin</sourceDir>
                <sourceDir>${project.basedir}/src/test/java</sourceDir>
              </sourceDirs>
            </configuration>
          </execution>
        </executions>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.2</version>
        <configuration> <!-- Compile java 7 compatible bytecode -->
          <source>1.7</source>
          <target>1.7</target>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

Now is the time to add some code written in Kotlin. So I'm adding the `kotlin` directory to `module1` and the package that already exists in the project, as well as a simple service `io.jitpack.KotlinRulezService.kt`, with the following content:

```kotlin
class KotlinRulezService {
    
    fun talkToMe(greetingWord: String) {
        println("Kotlin Rulez $greetingWord")
    }
}
```

There is one class written in Java in `module1` and that is the main class of the application: ʻio.jitpack.App.java`:

```java
public class App 
{
    public static final String GREETING = "Hello World!";
    
    public static void main( String[] args )
    {
        System.out.println(GREETING);
    }
}
```

Let's add to it, call to our Kotlin service. After the changes, it should look like this:

```java
public class App 
{
    public static final String GREETING = "Hello World!";
    
    public static void main( String[] args )
    {
        KotlinRulezService service = new KotlinRulezService();
        service.talkToMe(GREETING);
    }
}
```

Running `mvn compile` after all this changes should be no problem.

As you can see, adding Kotlin to a project using Maven is very simple. Now let's try to do the same with the project using Gradle. I will approach this task in the same way as before, i.e. using the first project that Google will find me after entering "github gradle multi module". This time it is a project [gradle-multi-module] (https://github.com/gwonsungjun/gradle-multi-module).

Our configuration is as follows:

```groovy
buildscript {
    ext {
        springBootVersion = '2.1.3.RELEASE'
    }
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath("org.springframework.boot:spring-boot-gradle-plugin:${springBootVersion}")
        classpath "io.spring.gradle:dependency-management-plugin:1.0.6.RELEASE"
    }
}

allprojects {
    group 'com.sungjun'
    version '1.0-SNAPSHOT'
}

subprojects {
    apply plugin: 'java'
    apply plugin: 'org.springframework.boot'
    apply plugin: 'io.spring.dependency-management'

    sourceCompatibility = 1.8

    repositories {
        mavenCentral()
    }

    dependencies {
        testCompile group: 'junit', name: 'junit', version: '4.12'
    }
}

project(':sample-api') {
    dependencies {
        compile project(':sample-common')
    }
}

project(':sample-admin') {
    dependencies {
        compile project(':sample-common')
    }
}
```

We can build the project using `./gradlew build` command. It's time to add Kotlin:

1. As in the previous case, we need to add a plugin that will compile the Kotlin code for us. To do this, add the following code to the main `build.gradle` file under the `buildscript` section:

```
plugins {
    id "org.jetbrains.kotlin.jvm" version "1.3.72"
}
```

For this project, it was necessary to downgrade to a lower version of the plug-in due to the use of Gradle version 4.10.3 in the project.
2. In the same file we have a `subprojects` section to which we need to add an `apply plugin: 'kotlin'` so that we can use Kotlin code in each sub-module.
3. We also need to add a dependency to the Kotlin standard library: `implementation "org.jetbrains.kotlin: kotlin-stdlib-jdk8"` in dependencies of the `subprojects` section.
Ultimately, the main configuration file looks like this:

```groovy
buildscript {
    ext {
        springBootVersion = '2.1.3.RELEASE'
    }
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath("org.springframework.boot:spring-boot-gradle-plugin:${springBootVersion}")
        classpath "io.spring.gradle:dependency-management-plugin:1.0.6.RELEASE"
    }
}

plugins {
    id "org.jetbrains.kotlin.jvm" version "1.3.72"
}

allprojects {
    group 'com.sungjun'
    version '1.0-SNAPSHOT'
}

subprojects {
    apply plugin: 'java'
    apply plugin: 'org.springframework.boot'
    apply plugin: 'io.spring.dependency-management'
    apply plugin: 'kotlin'

    sourceCompatibility = 1.8

    repositories {
        mavenCentral()
    }

    dependencies {
        testCompile group: 'junit', name: 'junit', version: '4.12'
        implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk8"
    }
}

project(':sample-api') {
    dependencies {
        compile project(':sample-common')
    }
}

project(':sample-admin') {
    dependencies {
        compile project(':sample-common')
    }
}
```

We can now start writing some code in Kotlin. In the sub-module `sample-api`, add the `kotlin` directory in the `src/main` directory and add the `com.sungjun.api.service` package to it. As I mentioned at the beginning of the text, if we use IntelliJ Idea, we can easily convert code written in Java into Kotlin.

I think it would be nice to try it on the example of the service `com.sungjun.api.service.MemberServiceCustom` in the module mentioned above. So I will create a Kotlin class with the same name: `MemberServiceCustom.kt` and paste the following Java code into it:

```java
import com.sungjun.common.member.Member;
import com.sungjun.common.repository.MemberRepository;
import org.springframework.stereotype.Service;

@Service
public class MemberServiceCustom {

    private MemberRepository memberRepository;

    public MemberServiceCustom(MemberRepository memberRepository) {
        this.memberRepository = memberRepository;
    }

    public Long singup (Member member) {
        return memberRepository.save(member).getId();
    }
}
```

The IDE itself will ask whether to convert the code, and as a result of this operation we will get the following Kotlin code:

```kotlin
import com.sungjun.common.member.Member
import com.sungjun.common.repository.MemberRepository
import org.springframework.stereotype.Service

@Service
class MemberServiceCustom(private val memberRepository: MemberRepository) {
    fun singup(member: Member): Long {
        return memberRepository.save(member).id
    }

}
```

The first thing that catches your eye is the brevity of this code, and you can write it down in even more compact form:

```kotlin
import com.sungjun.common.member.Member
import com.sungjun.common.repository.MemberRepository
import org.springframework.stereotype.Service

@Service
class MemberServiceCustom(private val memberRepository: MemberRepository) {
    fun singup(member: Member) = memberRepository.save(member).id
}
```

We now need to remove the old Java service because we have a name conflict in this package. We can check all our work by running the test `com.sungjun.api.service.MemberServiceCustomTest`, which is used by the mentioned service. And that's the end of the changes needed to use Kotlin using Gradle.

### Summary
I hope that in this text I encouraged the use of Kotlin in your projects. I know that commercial projects can be very complex, but let's remember that with a bit of work we can bring the project into the twenty-first century. Quite often we try to support ourselves with various libraries that can complicate the building process. As you can see in the text, we can easily convert them all into a language that is very pleasant, efficient and can significantly improve the reception of the project by current and new programmers.

At my current work, we write almost all of our server applications in Kotlin. We have never had problems with introducing this language to the project, as well as with the onboarding of new programmers who only dealt with Java before.

This is it! You can find all the source code in my repository [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/KotlinInJavaProject). 
Have fun and thanks for reading!

