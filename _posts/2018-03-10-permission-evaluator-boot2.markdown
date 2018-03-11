---
title:  "Custom PermissionEvaluator in Spring Boot 2.0"
excerpt: "Create custom PermissionEvaluator in Spring Boot 2.0. Basic usage in controllers and thymeleaf views."
header:
  overlay_image: /assets/images/post_teaser.jpeg
  overlay_filter: 0.5 # same as adding an opacity of 0.5 to a black background
  caption: "Photo credit: [Markus Spiske](http://freeforcommercialuse.net)"
date:   2018-03-10 10:34:00 +0200
tags: spring spring-boot security thymeleaf
---
Because a few days ago we were celebrating the release of version 2.0.0 RELEASE of Spring Boot framework, today I will try to describe the element in my opinion very useful in business applications but with use of new Spring Boot framework. I mean the custom permission evaluator.
If you are securing your applications, it is not always enough to block access to a group of objects. Sometimes requirements force you to secure access to individual business objects, and in such cases, the custom permission evaluator is useful.

I have my application builded with Maven. This is the whole `pom.xml` file:
~~~ xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>permission-evaluator-boot2</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <packaging>jar</packaging>

    <name>permission-evaluator-boot2</name>
    <description>Demo project for custom permission evaluator with Spring Boot</description>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.0.0.RELEASE</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <java.version>1.8</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-thymeleaf</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.thymeleaf.extras</groupId>
            <artifactId>thymeleaf-extras-springsecurity4</artifactId>
            <version>3.0.2.RELEASE</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.16.20</version>
            <scope>provided</scope>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
       <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>


</project>
~~~

As you can see I added few spring boot starter libraries and `org.projectlombok.lombok` (you can omit the lombok because I used it to simplify logging and for creation of getters and setters). In order to use `sec:authorize` in the thymeleaf views, add the `thymeleaf-extras-springsecurity4` dependency (despite the name, it works great with Spring Security 5).
Now let's have a look at application configuration. First, the basic security config:
~~~ java
package com.example.permissionevaluatorboot2;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.security.config.annotation.web.builders.WebSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.access.expression.DefaultWebSecurityExpressionHandler;

@EnableWebSecurity
public class WebSecurityConfig extends WebSecurityConfigurerAdapter {
    @Autowired
    private CustomPermissionEvaluator customPermissionEvaluator;

    @Bean
    public UserDetailsService userDetailsService() {
        // Spring Boot 2 default PasswordEncoder is built as a DelegatingPasswordEncoder. Using
        // {noop} will forece DelegatingPasswordEncoder to use NoOpPasswordEncoder
        InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();
        manager.createUser(User.withUsername("user1").password("{noop}pass").roles("USER")
                .build());
        manager.createUser(User.withUsername("user2").password("{noop}pass").roles("USER").build());
        return manager;
    }

    @Override
    public void configure(WebSecurity web) throws Exception {
        DefaultWebSecurityExpressionHandler handler = new DefaultWebSecurityExpressionHandler();
        handler.setPermissionEvaluator(customPermissionEvaluator);
        web.expressionHandler(handler);
    }
}
~~~
As you can see I added two users. Both has role `USER`. Spring Security 5 uses `DelegatingPasswordEncoder` to delegate password encoding to one of many implementation of PasswordEncoder (read more [Spring Security 5 Password Encoding](https://spring.io/blog/2017/11/01/spring-security-5-0-0-rc1-released#password-encoding)). 
Please also pay attention to the `public void configure (WebSecurity web)` method. It is necessary for the `thymeleaf-extra-security4` to function properly and allow to use method `sec:authorize="hasPermission(...)"` in html view like shown on below snippet (part of `documents.html`):
~~~ html
    <span th:if="${#authorization.expression('hasPermission(__${doc.id}__ ,''ConfidentialDocument'', ''read'')')}">
                 <a th:href="@{/document/__${doc.id}__}" th:text="${'Edit ' + doc.fileName}"></a>
            </span>
~~~
In this example I used `# authorization` because I do not see any other way to send a parameter existing in the context of this page (`doc.id`) to spring security.
One of the most important configuration is `MethodSecurityConfig.class`:
~~~ java
@Configuration
@EnableGlobalMethodSecurity(prePostEnabled = true)
public class MethodSecurityConfig extends GlobalMethodSecurityConfiguration {
    @Bean
    public CustomPermissionEvaluator customPermissionEvaluator() {
        return new CustomPermissionEvaluator();
    }

    @Override
    protected MethodSecurityExpressionHandler createExpressionHandler() {
        DefaultMethodSecurityExpressionHandler expressionHandler =
                new DefaultMethodSecurityExpressionHandler();
        expressionHandler.setPermissionEvaluator(customPermissionEvaluator());
        return expressionHandler;
    }
}
~~~
It is allowing us to use `@PreAuthorize` annotation in Spring MVC controllers and set application Permission Evaluator to `CustomPermissionEvaluator.class`. Custom permission evaluator can be Spring Component and look similar to the one shown below:
~~~ java
@Component
public class CustomPermissionEvaluator implements PermissionEvaluator {
    @Autowired
    private ConfidentialDocumentsRepository confidentialDocumentsRepository;

    @Override
    public boolean hasPermission(Authentication auth, Object targetDomainObject, Object permission) {
        // I will not implement this method just because I don't needed in this demo.
        throw new UnsupportedOperationException();
    }

    @Override
    public boolean hasPermission(Authentication auth, Serializable targetId, String targetType, Object permission) {
        if ((auth == null) || (targetType == null) || !(permission instanceof String)) {
            return false;
        }
        ConfidentialDocument confidentialDocument =
                confidentialDocumentsRepository.findOne((Integer) targetId);
        String documentOwner = confidentialDocument.getOwner();
        UserDetails userDetails = (UserDetails) auth.getPrincipal();
        String principalLogin = userDetails.getUsername();
        // if current user is owner of document permission is granted
        if (Objects.equals(documentOwner, principalLogin)) {
            return true;
        }
        return false;
    }

}
~~~
I implemented only one method and as you can see it just simply check if current user which is trying to get permission to the document with provided `id` is owned by this user, and if yes it will grant permission to this object. This is just simple implementation but as you can see you can make Permission Evaluator as Spring component and inject some services that will help to check permission to any business resource.
Example use of `@PreAuthorize` annotation in controller is shown below:
~~~ java
    @PreAuthorize("hasPermission(#id, 'ConfidentialDocument', 'read')")
    @GetMapping("/document/{id}")
    String findById(@PathVariable Integer id, final Model model) {
        final ConfidentialDocument document =
                this.repository.findOne(id);
        model.addAttribute("document", document);
        return "document";
    }
~~~
The `@PreAuthorize` annotation refers to the `Integer id` path variable in the controller method using `#id` reference.
I create simple unit tests to test authorization (both on controllers and view).
~~~ java
@RunWith(SpringRunner.class)
@SpringBootTest
@AutoConfigureMockMvc
public class ConfidentialDocumentsControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(username = "user1")
    public void list_withUser1LoggedIn_showHrefForOwnedDocs() throws Exception {
        //testing thymeleaf sec:authorize with hasPermission
        this.mockMvc.perform(get("/"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("Edit file1.txt"),
                        containsString("Edit file2.txt"),
                        not(containsString("Edit file3.txt")))));
    }

    @Test
    @WithMockUser(username = "user2")
    public void list_withUser2LoggedIn_showHrefForOwnedDocs() throws Exception {
        //testing thymeleaf sec:authorize with hasPermission
        this.mockMvc.perform(get("/"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        not(containsString("Edit file1.txt")),
                        not(containsString("Edit file2.txt")),
                        containsString("Edit file3.txt"))));
    }

    @Test
    @WithMockUser(username = "user1")
    public void findById_withUser1LoggedInAndIdEq1_showdocsDetailsView() throws Exception {
        //test @PreAuthorize annotation on controllers
        this.mockMvc
                .perform(get("/document/1"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(view().name("document"));
    }

    @Test
    @WithMockUser(username = "user1")
    public void findById_withUser1LoggedInAndIdEq2_showDocsDetailsView() throws Exception {
        //test @PreAuthorize annotation on controllers
        this.mockMvc
                .perform(get("/document/2"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(view().name("document"));
    }

    @Test
    @WithMockUser(username = "user1")
    public void findById_withUser1LoggedInAndIdEq3_viewIsForbidden() throws Exception {
        //test @PreAuthorize annotation on controllers
        this.mockMvc
                .perform(get("/document/3"))
                .andDo(print())
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "user2")
    public void findById_withUser2LoggedInAndIdEq1_viewIsForbidden() throws Exception {
        //test @PreAuthorize annotation on controllers
        this.mockMvc
                .perform(get("/document/1"))
                .andDo(print())
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "user2")
    public void findById_withUser2LoggedInAndIdEq2_viewIsForbidden() throws Exception {
        //test @PreAuthorize annotation on controllers
        this.mockMvc
                .perform(get("/document/2"))
                .andDo(print())
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "user2")
    public void findById_withUser2LoggedInAndIdEq3_showDocDetails() throws Exception {
        //test @PreAuthorize annotation on controllers
        this.mockMvc
                .perform(get("/document/3"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(view().name("document"));
    }
}
~~~
You can find whole project in my [GitHub account](https://github.com/k0staa/Code-Addict-Repos/tree/master/permission-evaluator-boot2).

This is it! You should now be able to use `hasPermission` method both in your Spring Boot 2.0 application. Thanks for reading!

