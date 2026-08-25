package dev.golfcnt19.expense

import org.junit.jupiter.api.Test
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.ActiveProfiles

@SpringBootTest
@ActiveProfiles("test")
class ApiApplicationTests {

    @Test
    fun contextLoads() {
        // ยืนยันว่า context ขึ้นได้ Flyway migrate ผ่าน และ Hibernate validate schema ตรง
    }
}
