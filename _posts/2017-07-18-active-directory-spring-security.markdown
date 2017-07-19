---
title:  "Spring Security with Active Directory and mapping Active Directory groups to roles or privileges taken from database configuration."
date:   2017-07-18 20:29:53 +0200
categories: spring spring-boot security ldap
---
 		
Shortest way to configure Spring Security with Active Directory and map Active Directory groups to your privileges/roles configuration from database and use them in application.

When creating an example configuration I used JDK 8 and the following dependencies:
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
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-ldap</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
    </dependencies>
~~~

Spring Security already provides classes needed to use Active Directory users and groups:
~~~ 
org.springframework.security.ldap.authentication.ad.ActiveDirectoryLdapAuthenticationProvider
~~~
 but functionality of this provider is very simple. In short it's job is to map Active Directory groups to Spring Security roles. Sometimes you need to have something more sophisticated. There is problably more options but I will
 show you one of the shortest and simplest but still elegant in my opinion. When using this option you can have privileges connected to roles and roles connected to Active Directory groups and be able to map this privileges to roles in your application.
 It's very handy because you can use `@Secured` annotation and security tags in JSP (or some fancy template engine) immediately. 

First we need to create our own implementation of `ActiveDirectoryLdapAuthenticationProvider`. Unfortunatly we can't extend it beacause it's final. You can go ahead and create your class, let's name it for example `CustomActiveDirectoryLdapAuthenticationProvider` (it needs to extend `AbstractLdapAuthenticationProvider`) and copy all content from original `ActiveDirectoryLdapAuthenticationProvider` to our newly created class. 
 
 Now let's move to your Spring Security configuration bean for a second. Let's say we name it `AppSecurityConfig` and it's need to extend `WebSecurityConfigurerAdapter`. It can look like that:
 
~~~ java
@Configuration
@EnableWebSecurity
@EnableGlobalMethodSecurity(securedEnabled = true)
public class AppSecurityConfig extends WebSecurityConfigurerAdapter {
        @Autowired
        private RoleDao roleDao;

        @Value("${ldap.domain}")
        private String ldapDomain;

        @Value("${ldap.url}")
        private String ldapUrl;

        @Override
        protected void configure(HttpSecurity http) throws Exception {
            http
                    .authorizeRequests()
                    .anyRequest().fullyAuthenticated()
                    .and()
                    .formLogin()
                    .loginPage("/login").defaultSuccessUrl("/", true).permitAll()
                    .and()
                    .logout().permitAll();
        }

        @Override
        protected void configure(AuthenticationManagerBuilder authManagerBuilder) throws Exception {
            authManagerBuilder
                    .authenticationProvider(activeDirectoryLdapAuthenticationProvider())
                    .userDetailsService(userDetailsService());
        }

        @Bean
        public AuthenticationManager authenticationManager() {
            return new ProviderManager(Arrays.asList(activeDirectoryLdapAuthenticationProvider()));
        }

        @Bean
        public AuthenticationProvider activeDirectoryLdapAuthenticationProvider() {
            CustomActiveDirectoryLdapAuthenticationProvider provider = new CustomActiveDirectoryLdapAuthenticationProvider(ldapDomain, ldapUrl);
            provider.setConvertSubErrorCodesToExceptions(true);
            provider.setUseAuthenticationRequestCredentials(true);
			provider.setRoleDao(roleDao);
            return provider;
        }
    }
~~~

Ok, there are a few things that you probably see in this code, which I have not discussed before. Let's go now one by one:
 * `@EnableWebSecurity` - it's just here to enable Spring Security in our application
 * `@EnableGlobalMethodSecurity(securedEnabled = true)` - is used to enable `@Secured` annotation, you can read more about this [here](http://docs.spring.io/spring-security/site/docs/4.0.0.M1/reference/htmlsingle/#enableglobalmethodsecurity) and if you want you can remove it because it's not needed in this tutorial.
 * `@Value("${ldap.domain}") private String ldapDomain;` - this is Active Directory main root (usually server domain), for example `win2k3AD.local`. It's loaded from Spring Boot `application.properties` file using `@Value` annotation. 
 * `@Value("${ldap.url}") private String ldapUrl;` - this is Active Directory server address, for example `LDAP://192.168.0.100/`. It's loaded from Spring Boot `application.properties` file using `@Value` annotation. 
 * `RoleDao` - it's my data access object which I use for accessing database which contains my configuration of roles and privileges. You need to provide some king of your own spring component to access database which you can autowire in `AppSecurityConfig`.
 * `provider.setRoleDao(roleDao);` - you need to create setter in your `CustomActiveDirectoryLdapAuthenticationProvider` and class attribute that should have type of your DAO (I will show example below).
 
Now let's modify `CustomActiveDirectoryLdapAuthenticationProvider`. I will first show fragments of code and later I will paste the whole class.

First add your DAO object as class attribute and create setter for it:
~~~ java
public final class CustmActiveDirectoryLdapAuthenticationProvider extends
		AbstractLdapAuthenticationProvider {
  private RoleDao roleDao;

  public void setRoleDao(RoleDao roleDao) {
        this.roleDao = roleDao;
  }

/* rest of code ommited */

~~~

Now we need to customize `Collection<? extends GrantedAuthority> loadUserAuthorities(DirContextOperations userData, String username, String password)` method and create method for purpose of mapping roles/privileges configuration from database to application roles (please read the comments):
~~~ java
 protected Collection<? extends GrantedAuthority> loadUserAuthorities(
            DirContextOperations userData, String username, String password) {
        String[] groups = userData.getStringAttributes("memberOf");
        if (groups == null) {
            log.debug("No values for 'memberOf' attribute. No Authorities in Active Directory!");
            return AuthorityUtils.NO_AUTHORITIES;
        }
        if (log.isDebugEnabled()) {
            logger.debug("'memberOf' attribute values: " + Arrays.asList(groups));
        }

        List<GrantedAuthority> authorities = createGrantedAuthoritiesFromLdapGroups(groups);
        return authorities;
    }

 private List<GrantedAuthority> createGrantedAuthoritiesFromLdapGroups(String[] groups) {
        List<String> groupNames = new ArrayList<>(groups.length);
		//'groups' is array of Acitve Directory groups which user that tries to authenticate has. 
        for (String group : groups) {
            String groupName = new DistinguishedName(group)
                    .removeLast().getValue();
            groupNames.add(groupName);
        }
		
		// I use Active Directory groups that user which tries to login has and get all application privileges for them from database.
		// You can map privileges or roles form database to application roles and easily use them in application for example in @Secured annotation
        List<String> privileges = roleDao.findPrivilegesForLDAPGroups(groupNames);
		
		// Your roles/privileges in database need to have 'ROLE_' prefix or you need to append it here.
		String DEFAULT_ROLE_PREFIX = "ROLE_";
        return privileges
                .stream()
                .map(privilege -> org.apache.commons.lang3.StringUtils.appendIfMissing(DEFAULT_ROLE_PREFIX, privilege))
                .map(privilege -> new SimpleGrantedAuthority(privilege))
                .collect(Collectors.toList());
    }
~~~

This should be enough to use your roles/privileges configuration in application. Thanks for reading this post! Below I will paste whole `CustomActiveDirectoryLdapAuthenticationProvider` without Java Docs ,imports and comments.

~~~ java

public final class CustomActiveDirectoryLdapAuthenticationProvider extends
		AbstractLdapAuthenticationProvider {
	private static final Pattern SUB_ERROR_CODE = Pattern
			.compile(".*data\\s([0-9a-f]{3,4}).*");

	private static final int USERNAME_NOT_FOUND = 0x525;
	private static final int INVALID_PASSWORD = 0x52e;
	private static final int NOT_PERMITTED = 0x530;
	private static final int PASSWORD_EXPIRED = 0x532;
	private static final int ACCOUNT_DISABLED = 0x533;
	private static final int ACCOUNT_EXPIRED = 0x701;
	private static final int PASSWORD_NEEDS_RESET = 0x773;
	private static final int ACCOUNT_LOCKED = 0x775;

	private final String domain;
	private final String rootDn;
	private final String url;
	private boolean convertSubErrorCodesToExceptions;
	private String searchFilter = "(&(objectClass=user)(userPrincipalName={0}))";
	
	// this is your DAO class attribute and setter
    private RoleDao roleDao;

	public void setRoleDao(RoleDao roleDao) {
        this.roleDao = roleDao;
    }

	ContextFactory contextFactory = new ContextFactory();

	public CustomActiveDirectoryLdapAuthenticationProvider(String domain, String url,
			String rootDn) {
		Assert.isTrue(StringUtils.hasText(url), "Url cannot be empty");
		this.domain = StringUtils.hasText(domain) ? domain.toLowerCase() : null;
		this.url = url;
		this.rootDn = StringUtils.hasText(rootDn) ? rootDn.toLowerCase() : null;
	}

	public CustomActiveDirectoryLdapAuthenticationProvider(String domain, String url) {
		Assert.isTrue(StringUtils.hasText(url), "Url cannot be empty");
		this.domain = StringUtils.hasText(domain) ? domain.toLowerCase() : null;
		this.url = url;
		rootDn = this.domain == null ? null : rootDnFromDomain(this.domain);
	}

	@Override
	protected DirContextOperations doAuthentication(
			UsernamePasswordAuthenticationToken auth) {
		String username = auth.getName();
		String password = (String) auth.getCredentials();

		DirContext ctx = bindAsUser(username, password);

		try {
			return searchForUser(ctx, username);
		}
		catch (NamingException e) {
			logger.error("Failed to locate directory entry for authenticated user: "
					+ username, e);
			throw badCredentials(e);
		}
		finally {
			LdapUtils.closeContext(ctx);
		}
	}

	protected Collection<? extends GrantedAuthority> loadUserAuthorities(
            DirContextOperations userData, String username, String password) {
        String[] groups = userData.getStringAttributes("memberOf");
        if (groups == null) {
            log.debug("No values for 'memberOf' attribute. No Authorities in Active Directory!");
            return AuthorityUtils.NO_AUTHORITIES;
        }
        if (log.isDebugEnabled()) {
            logger.debug("'memberOf' attribute values: " + Arrays.asList(groups));
        }

        List<GrantedAuthority> authorities = createGrantedAuthoritiesFromLdapGroups(groups);
        return authorities;
    }

	private List<GrantedAuthority> createGrantedAuthoritiesFromLdapGroups(String[] groups) {
        List<String> groupNames = new ArrayList<>(groups.length);
		//'groups' is array of Acitve Directory groups which user that tries to authenticate has. 
        for (String group : groups) {
            String groupName = new DistinguishedName(group)
                    .removeLast().getValue();
            groupNames.add(groupName);
        }
		
		// I use Active Directory groups that user which tries to login has and get all application privileges for them from database.
		// You can map privileges or roles form database to application roles and easily use them in application for example in @Secured annotation
        List<String> privileges = roleDao.findPrivilegesForLDAPGroups(groupNames);
		
		// Your roles/privileges in database need to have 'ROLE_' prefix or you need to append it here.
		String DEFAULT_ROLE_PREFIX = "ROLE_";
        return privileges
                .stream()
                .map(privilege -> org.apache.commons.lang3.StringUtils.appendIfMissing(DEFAULT_ROLE_PREFIX, privilege))
                .map(privilege -> new SimpleGrantedAuthority(privilege))
                .collect(Collectors.toList());
    }

	private DirContext bindAsUser(String username, String password) {
		final String bindUrl = url;
		Hashtable<String, String> env = new Hashtable<String, String>();
		env.put(Context.SECURITY_AUTHENTICATION, "simple");
		String bindPrincipal = createBindPrincipal(username);
		env.put(Context.SECURITY_PRINCIPAL, bindPrincipal);
		env.put(Context.PROVIDER_URL, bindUrl);
		env.put(Context.SECURITY_CREDENTIALS, password);
		env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		env.put(Context.OBJECT_FACTORIES, DefaultDirObjectFactory.class.getName());

		try {
			return contextFactory.createContext(env);
		}
		catch (NamingException e) {
			if ((e instanceof AuthenticationException)
					|| (e instanceof OperationNotSupportedException)) {
				handleBindException(bindPrincipal, e);
				throw badCredentials(e);
			}
			else {
				throw LdapUtils.convertLdapException(e);
			}
		}
	}

	private void handleBindException(String bindPrincipal, NamingException exception) {
		if (logger.isDebugEnabled()) {
			logger.debug("Authentication for " + bindPrincipal + " failed:" + exception);
		}
		int subErrorCode = parseSubErrorCode(exception.getMessage());
		if (subErrorCode <= 0) {
			logger.debug("Failed to locate AD-specific sub-error code in message");
			return;
		}
		logger.info("Active Directory authentication failed: "
				+ subCodeToLogMessage(subErrorCode));
		if (convertSubErrorCodesToExceptions) {
			raiseExceptionForErrorCode(subErrorCode, exception);
		}
	}

	private int parseSubErrorCode(String message) {
		Matcher m = SUB_ERROR_CODE.matcher(message);
		if (m.matches()) {
			return Integer.parseInt(m.group(1), 16);
		}
		return -1;
	}

	private void raiseExceptionForErrorCode(int code, NamingException exception) {
		String hexString = Integer.toHexString(code);
		Throwable cause = new ActiveDirectoryAuthenticationException(hexString,
				exception.getMessage(), exception);
		switch (code) {
		case PASSWORD_EXPIRED:
			throw new CredentialsExpiredException(messages.getMessage(
					"LdapAuthenticationProvider.credentialsExpired",
					"User credentials have expired"), cause);
		case ACCOUNT_DISABLED:
			throw new DisabledException(messages.getMessage(
					"LdapAuthenticationProvider.disabled", "User is disabled"), cause);
		case ACCOUNT_EXPIRED:
			throw new AccountExpiredException(messages.getMessage(
					"LdapAuthenticationProvider.expired", "User account has expired"),
					cause);
		case ACCOUNT_LOCKED:
			throw new LockedException(messages.getMessage(
					"LdapAuthenticationProvider.locked", "User account is locked"), cause);
		default:
			throw badCredentials(cause);
		}
	}

	private String subCodeToLogMessage(int code) {
		switch (code) {
		case USERNAME_NOT_FOUND:
			return "User was not found in directory";
		case INVALID_PASSWORD:
			return "Supplied password was invalid";
		case NOT_PERMITTED:
			return "User not permitted to logon at this time";
		case PASSWORD_EXPIRED:
			return "Password has expired";
		case ACCOUNT_DISABLED:
			return "Account is disabled";
		case ACCOUNT_EXPIRED:
			return "Account expired";
		case PASSWORD_NEEDS_RESET:
			return "User must reset password";
		case ACCOUNT_LOCKED:
			return "Account locked";
		}
		return "Unknown (error code " + Integer.toHexString(code) + ")";
	}

	private BadCredentialsException badCredentials() {
		return new BadCredentialsException(messages.getMessage(
				"LdapAuthenticationProvider.badCredentials", "Bad credentials"));
	}

	private BadCredentialsException badCredentials(Throwable cause) {
		return (BadCredentialsException) badCredentials().initCause(cause);
	}

	private DirContextOperations searchForUser(DirContext context, String username)
			throws NamingException {
		SearchControls searchControls = new SearchControls();
		searchControls.setSearchScope(SearchControls.SUBTREE_SCOPE);
		String bindPrincipal = createBindPrincipal(username);
		String searchRoot = rootDn != null ? rootDn
				: searchRootFromPrincipal(bindPrincipal);

		try {
			return SpringSecurityLdapTemplate.searchForSingleEntryInternal(context,
					searchControls, searchRoot, searchFilter,
					new Object[] { bindPrincipal });
		}
		catch (IncorrectResultSizeDataAccessException incorrectResults) {
			// Search should never return multiple results if properly configured - just
			// rethrow
			if (incorrectResults.getActualSize() != 0) {
				throw incorrectResults;
			}
			// If we found no results, then the username/password did not match
			UsernameNotFoundException userNameNotFoundException = new UsernameNotFoundException(
					"User " + username + " not found in directory.", incorrectResults);
			throw badCredentials(userNameNotFoundException);
		}
	}

	private String searchRootFromPrincipal(String bindPrincipal) {
		int atChar = bindPrincipal.lastIndexOf('@');
		if (atChar < 0) {
			logger.debug("User principal '" + bindPrincipal
					+ "' does not contain the domain, and no domain has been configured");
			throw badCredentials();
		}
		return rootDnFromDomain(bindPrincipal.substring(atChar + 1,
				bindPrincipal.length()));
	}

	private String rootDnFromDomain(String domain) {
		String[] tokens = StringUtils.tokenizeToStringArray(domain, ".");
		StringBuilder root = new StringBuilder();
		for (String token : tokens) {
			if (root.length() > 0) {
				root.append(',');
			}
			root.append("dc=").append(token);
		}
		return root.toString();
	}

	String createBindPrincipal(String username) {
		if (domain == null || username.toLowerCase().endsWith(domain)) {
			return username;
		}

		return username + "@" + domain;
	}
	public void setConvertSubErrorCodesToExceptions(
			boolean convertSubErrorCodesToExceptions) {
		this.convertSubErrorCodesToExceptions = convertSubErrorCodesToExceptions;
	}

	public void setSearchFilter(String searchFilter) {
		Assert.hasText(searchFilter, "searchFilter must have text");
		this.searchFilter = searchFilter;
	}

	static class ContextFactory {
		DirContext createContext(Hashtable<?, ?> env) throws NamingException {
			return new InitialLdapContext(env, null);
		}
	}
}
~~~


 




