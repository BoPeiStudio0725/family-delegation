package tw.taipei.codefest.delegation.web;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    private final AuthInterceptor auth;
    private final ScopeInterceptor scope;

    public WebConfig(AuthInterceptor auth, ScopeInterceptor scope) {
        this.auth = auth;
        this.scope = scope;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // 公開 API（不需登入）：台北通登入、據點清單、示範帳號清單
        String[] publicPaths = {"/api/auth/**", "/api/service-points/**", "/api/demo/**"};
        registry.addInterceptor(auth).addPathPatterns("/api/**").excludePathPatterns(publicPaths).order(1);
        registry.addInterceptor(scope).addPathPatterns("/api/**").excludePathPatterns(publicPaths).order(2);
    }

    /** 黑客松期間開放所有來源，方便 Flutter Web / 模擬器測試。正式上線要收緊。 */
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }
}
