package dev.golfcnt19.expense

import dev.golfcnt19.expense.domain.Category
import dev.golfcnt19.expense.domain.Expense
import dev.golfcnt19.expense.domain.ExpenseRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.math.BigDecimal
import java.time.LocalDate
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ExpenseApiTest {

    @Autowired private lateinit var mvc: MockMvc
    @Autowired private lateinit var repository: ExpenseRepository

    private val today: LocalDate = LocalDate.now()

    @BeforeEach
    fun clean() {
        repository.deleteAll()
    }

    private fun seed(
        amount: String,
        category: Category,
        daysAgo: Long = 0,
    ): Expense = repository.save(
        Expense(
            amount = BigDecimal(amount),
            category = category,
            spentOn = today.minusDays(daysAgo),
        ),
    )

    // ── create ────────────────────────────────────────────────────────────

    @Test
    @DisplayName("POST สร้างรายการได้ และคืน Location ที่ชี้ไปยังรายการนั้น")
    fun createsExpense() {
        val body = """{"amount":250.50,"category":"FOOD","note":"lunch","spentOn":"$today"}"""

        val result = mvc.perform(
            post("/api/expenses").contentType(MediaType.APPLICATION_JSON).content(body),
        )
            .andExpect(status().isCreated)
            .andExpect(header().exists("Location"))
            .andExpect(jsonPath("$.amount").value(250.50))
            .andExpect(jsonPath("$.category").value("FOOD"))
            .andExpect(jsonPath("$.note").value("lunch"))
            .andReturn()

        // อ่าน id จาก Location แทนการ parse JSON
        // ได้ตรวจสองอย่างพร้อมกัน: header ชี้ถูก และแถวถูกบันทึกจริง
        val location = result.response.getHeader("Location")!!
        val id = UUID.fromString(location.substringAfterLast('/'))
        assertThat(repository.findById(id)).isPresent()
    }

    @Test
    @DisplayName("note ที่มีแต่ช่องว่างถูกเก็บเป็น null ไม่ใช่สตริงว่าง")
    fun blankNoteBecomesNull() {
        val body = """{"amount":10,"category":"OTHER","note":"   ","spentOn":"$today"}"""

        mvc.perform(post("/api/expenses").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.note").doesNotExist())
    }

    // ── validation ────────────────────────────────────────────────────────

    @Test
    @DisplayName("amount เป็นศูนย์หรือติดลบถูกปฏิเสธ พร้อมบอกชื่อ field")
    fun rejectsNonPositiveAmount() {
        listOf("0", "-1").forEach { amount ->
            mvc.perform(
                post("/api/expenses")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""{"amount":$amount,"category":"FOOD","spentOn":"$today"}"""),
            )
                .andExpect(status().isBadRequest)
                .andExpect(jsonPath("$.fieldErrors.amount").exists())
        }
        assertThat(repository.count()).isZero()
    }

    @Test
    @DisplayName("วันที่ในอนาคตถูกปฏิเสธ")
    fun rejectsFutureDate() {
        val future = today.plusDays(1)

        mvc.perform(
            post("/api/expenses")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"amount":10,"category":"FOOD","spentOn":"$future"}"""),
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.fieldErrors.spentOn").exists())
    }

    @Test
    @DisplayName("category ที่ไม่มีในระบบถูกปฏิเสธ")
    fun rejectsUnknownCategory() {
        mvc.perform(
            post("/api/expenses")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"amount":10,"category":"CRYPTO","spentOn":"$today"}"""),
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    @DisplayName("size เกินเพดาน 100 ถูกปฏิเสธ กันดึงทั้งตารางในครั้งเดียว")
    fun rejectsOversizedPage() {
        mvc.perform(get("/api/expenses").param("size", "101"))
            .andExpect(status().isBadRequest)
    }

    // ── read ──────────────────────────────────────────────────────────────

    @Test
    @DisplayName("id ที่ไม่มีอยู่คืน 404 ไม่ใช่ 500")
    fun missingIdReturns404() {
        mvc.perform(get("/api/expenses/{id}", UUID.randomUUID()))
            .andExpect(status().isNotFound)
            .andExpect(jsonPath("$.status").value(404))
    }

    @Test
    @DisplayName("list เรียงจากวันที่ใหม่ไปเก่า")
    fun listsNewestFirst() {
        seed("100", Category.FOOD, daysAgo = 5)
        seed("200", Category.FOOD, daysAgo = 1)
        seed("300", Category.FOOD, daysAgo = 3)

        mvc.perform(
            get("/api/expenses")
                .param("from", today.minusDays(10).toString())
                .param("to", today.toString()),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalItems").value(3))
            .andExpect(jsonPath("$.items[0].amount").value(200.00))
            .andExpect(jsonPath("$.items[1].amount").value(300.00))
            .andExpect(jsonPath("$.items[2].amount").value(100.00))
    }

    @Test
    @DisplayName("กรอง category แล้วได้เฉพาะหมวดนั้น")
    fun filtersByCategory() {
        seed("100", Category.FOOD)
        seed("200", Category.TRANSPORT)
        seed("300", Category.FOOD)

        mvc.perform(
            get("/api/expenses")
                .param("category", "FOOD")
                .param("from", today.minusDays(1).toString())
                .param("to", today.toString()),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalItems").value(2))
    }

    @Test
    @DisplayName("รายการนอกช่วงวันที่ไม่ถูกนับ")
    fun excludesOutsideDateRange() {
        seed("100", Category.FOOD, daysAgo = 2)
        seed("999", Category.FOOD, daysAgo = 40)

        mvc.perform(
            get("/api/expenses")
                .param("from", today.minusDays(7).toString())
                .param("to", today.toString()),
        )
            .andExpect(jsonPath("$.totalItems").value(1))
            .andExpect(jsonPath("$.items[0].amount").value(100.00))
    }

    // ── summary ───────────────────────────────────────────────────────────

    @Test
    @DisplayName("summary รวมยอดต่อหมวดถูกต้อง และเรียงจากมากไปน้อย")
    fun summarisesByCategory() {
        seed("100.25", Category.FOOD)
        seed("200.75", Category.FOOD)
        seed("50", Category.TRANSPORT)

        mvc.perform(
            get("/api/expenses/summary")
                .param("from", today.minusDays(1).toString())
                .param("to", today.toString()),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.grandTotal").value(351.00))
            .andExpect(jsonPath("$.byCategory[0].category").value("FOOD"))
            .andExpect(jsonPath("$.byCategory[0].total").value(301.00))
            .andExpect(jsonPath("$.byCategory[0].count").value(2))
            .andExpect(jsonPath("$.byCategory[1].category").value("TRANSPORT"))
    }

    @Test
    @DisplayName("summary ช่วงที่ไม่มีข้อมูลคืนศูนย์ ไม่ใช่ error")
    fun emptySummaryIsZero() {
        mvc.perform(
            get("/api/expenses/summary")
                .param("from", today.minusDays(3).toString())
                .param("to", today.toString()),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.grandTotal").value(0))
            .andExpect(jsonPath("$.byCategory").isEmpty)
    }

    // ── update / delete ───────────────────────────────────────────────────

    @Test
    @DisplayName("PUT แก้ไขรายการได้")
    fun updatesExpense() {
        val existing = seed("100", Category.FOOD)

        mvc.perform(
            put("/api/expenses/{id}", existing.id)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"amount":175.25,"category":"HEALTH","note":"clinic","spentOn":"$today"}"""),
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.amount").value(175.25))
            .andExpect(jsonPath("$.category").value("HEALTH"))

        val reloaded = repository.findById(existing.id).orElseThrow()
        assertThat(reloaded.category).isEqualTo(Category.HEALTH)
    }

    @Test
    @DisplayName("DELETE ลบแล้วคืน 204 และหาไม่เจออีก")
    fun deletesExpense() {
        val existing = seed("100", Category.FOOD)

        mvc.perform(delete("/api/expenses/{id}", existing.id))
            .andExpect(status().isNoContent)

        mvc.perform(get("/api/expenses/{id}", existing.id))
            .andExpect(status().isNotFound)
    }

    @Test
    @DisplayName("DELETE id ที่ไม่มีอยู่คืน 404")
    fun deleteMissingReturns404() {
        mvc.perform(delete("/api/expenses/{id}", UUID.randomUUID()))
            .andExpect(status().isNotFound)
    }
}
