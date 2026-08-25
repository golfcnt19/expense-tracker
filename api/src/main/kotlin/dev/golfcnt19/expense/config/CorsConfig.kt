package dev.golfcnt19.expense.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Configuration
import org.springframework.web.servlet.config.annotation.CorsRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer

/**
 * client ฝั่งเว็บกับ Flutter รันคนละ origin กับ API จึงต้องเปิด CORS
 *
 * ระบุ origin เป็นรายการชัดเจน ไม่ใช้ "*" เพราะ "*" ใช้ร่วมกับ
 * allowCredentials ไม่ได้ และเปิดกว้างเกินจำเป็น
 * ค่าเริ่มต้นคือ dev server ในเครื่อง ตอน deploy ทับด้วย CORS_ORIGINS
 */
@Configuration
class CorsConfig(
    @param:Value("\${app.cors.origins:http://localhost:4200,http://localhost:8081,http://localhost:5000}")
    private val origins: List<String>,
) : WebMvcConfigurer {

    override fun addCorsMappings(registry: CorsRegistry) {
        registry.addMapping("/api/**")
            .allowedOrigins(*origins.toTypedArray())
            .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
            .allowedHeaders("Content-Type", "Accept")
            .exposedHeaders("Location")
            .maxAge(3600)
    }
}
