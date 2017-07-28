---
title:  "Sharing information over JMX in Wildlfy"
excerpt: "How to share informations over JMX in Spring application and Wildlfy server"
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2017-07-23 10:30:00 +0200
categories: spring wildfly
tags: spring spring-boot wildlfy jmx
---
 		
In my last task at work I had to share some data from application running on Wildlfy 10 via JMX. It's very simple task but there is a plenty misleading information in the internet and that's why I would like to discuss it in this post.


When creating an example configuration I used JDK 8 and Spring Boot starter dependency:
~~~ xml
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>1.5.3.RELEASE</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <java.version>1.8</java.version>
    </properties>

    <dependencies>
    <!-- nothing more needed to fulfill task-->
   </dependencies>
~~~

Let's say we want to have information about quantity and names of users registred in our application shared via JMX. First let's create class containing information that we want to share.
~~~ java
@Component
@ManagedResource(objectName = "jmxMyApplication:name=AppUsersInfo")
public class ApplicationUsersJmxInfoService {
    @Autowired
    private UsersService usersService;

    private List<String> registredUsers;

    @ManagedOperation
    public List<String> refreshRegistredUsersListInJmx() {
        return registredUsers = usersService
                .findRegistredUsers()
                .stream()
                .map(user -> user.toString())
                .collect(Collectors.toList());

    }

    @ManagedAttribute
    public List<String> getRegistredUsers() {
        if (isNull(registredUsers)) {
            refreshRegistredUsersListInJmx();
        }
        return registredUsers;
    }
}

~~~

I will now explain essential parts of the code that relate to the JMX sharing.  
  * `@ManagedResource(objectName = "jmxMyApplication:name=AppUsersInfo")` - `@ManagedResource` annotation indicates to register instances of a class with a JMX. `objectName` attribute value indicates JMX domain name which in this case has value of `jmxMyApplication`, and after the colon the name of the shared resource which in this case has value `AppUsersInfo`.
  * `@ManagedOperation` - method-level annotation that indicates to expose a given method as a JMX operation.
  * `@ManagedAttribute` - method-level annotation that indicates to expose a given object property as a JMX attribute. To share attribute via JMX we need to provide accessors and/or mutators.
The above configuration is enough to share data over JMX. If you start application using Spring Boot embedded server you can simply run Java Mission Control and it will automatically show local JVM instances and your JMX data should be visible in MBean tab.
If you deploy your application in Wildfly and want to be able to see JMX info you need to enable administration console and add admin user. I will not discuss the configuration of Wildfly in this post, but if you run Wildfly in docker you can simply use the following `Dockerfile`:
~~~
FROM jboss/wildfly
RUN /opt/jboss/wildfly/bin/add-user.sh admin admin --silent
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
~~~
and run container using following commands:
~~~
docker build --tag=jboss/wildfly-admin . 
docker run -it -p 9990:9990 jboss/wildfly-admin
~~~

Unfortunately you can't simply access Wildlfy JMX using standard Java Mission Control or JConsole from your JDK directory. Shortest way is to use `jconsole.sh` or `jconsole.bat` script from `{wildfly_path}/bin/` folder. You can use it from remote machine but please use `jconsole.*` script from same version of Wildfly which you connectiong to (you really don't need whole Wildfly package, only `jboss-cli-client.jar` is important because it is used when running JConsole but I will not explain it in detail). 
After JConsole start you will need to specify the http-remoting-jmx protocol address. In case you run docker container from above example your address may look that way: `service:jmx:http-remoting-jmx://192.168.99.100:9990` where `192.168.99.100` is your docker IP and `9990` is Wildfly admin console port. Next enter the Wildfly admin console Username and Password which is `admin`, `admin` if you use Dockerfile from above example. Now you should see JMX data in MBean tab of JConsole. Thanks for reading!  


