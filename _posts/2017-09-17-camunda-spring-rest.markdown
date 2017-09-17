---
title:  "Spring Boot 1.5 with Camunda 7.7. Camunda REST request in service task."
excerpt: "How to send REST request from Camunda service task configured in Camunda Modeller"
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2017-09-17 18:00:00 +0200
categories: spring camunda
tags: spring spring-boot camunda rest
---
I recently started working on an application that uses Camunda. The application uses the Camunda as standalone (separate) application using its REST API, and of course it is very well documented, however, I noticed that sometimes there is a need to send a request from Camunda to the application.	
If you have Spring Boot application which have running Camunda engine you could find many misleading information about how to configure Camunda to send REST request. If you using Camunda 7.7 (in `camunda-bpm-spring-boot-starter-bom` this is current version) and Spring Boot 1.5 you can follow my description.

I have my Camunda application builded with Maven. This is relevant part of `pom.xml`:
~~~ xml
   <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>1.5.6.RELEASE</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>

            <dependency>
                <groupId>org.camunda.bpm.extension.springboot</groupId>
                <artifactId>camunda-bpm-spring-boot-starter-bom</artifactId>
                <version>2.3.0-SNAPSHOT</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <dependencies>
        <dependency>
            <groupId>org.camunda.bpm.extension.springboot</groupId>
            <artifactId>camunda-bpm-spring-boot-starter-rest</artifactId>
        </dependency>
        <!--HTTP-Client and REST Connector plugin -->
        <dependency>
            <groupId>org.camunda.bpm</groupId>
            <artifactId>camunda-engine-plugin-connect</artifactId>
            <version>7.7.0</version>
        </dependency>
        <dependency>
            <groupId>org.camunda.connect</groupId>
            <artifactId>camunda-connect-http-client</artifactId>
            <version>1.0.4</version>
        </dependency>
	<repositories>
        <repository>
            <id>camunda-extensions-nexus</id>
            <url>https://app.camunda.com/nexus/content/repositories/camunda-bpm-community-extensions-snapshots</url>
            <releases>
                <enabled>false</enabled>
            </releases>
            <snapshots>
                <enabled>true</enabled>
            </snapshots>
        </repository>
    </repositories>
~~~

As you can see I added `camunda-engine-plugin-connect` and `camunda-connect-http-client`. 

Now let's create REST request in service task using Camunda Modeller (have a look at red arrow):


![Camunda service task. Adding connector ]({{ site.url }}/assets/images/camunda5.png)


Now configure request url:


 ![Camunda REST request url attribute]({{ site.url }}/assets/images/camunda1.png)  


...and type of method:


 ![Camunda REST request method ]({{ site.url }}/assets/images/camunda2.png)  


Time to configure headers:


 ![Camunda REST request headers ]({{ site.url }}/assets/images/camunda3.png)  


...and of course you can provide payload:


 ![Camunda REST request payload]({{ site.url }}/assets/images/camunda4.png) 


 This is it! You should now be able to send requests from Camunda service tasks to your application. Thanks for reading!

