package dev.golfcnt19.expense.web

import dev.golfcnt19.expense.domain.Category
import dev.golfcnt19.expense.domain.Expense
import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.PastOrPresent
import jakarta.validation.constraints.Size
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

/**
 * ข้อมูลขาเข้า แยกจาก entity โดยตั้งใจ
 * ไม่ให้ client กำหนด id หรือ timestamp ได้เอง
 */
data class ExpenseRequest(
    @field:NotNull(message = "amount is required")
    @field:DecimalMin(value = "0.01", message = "amount must be greater than 0")
    @field:DecimalMax(value = "99999999.99", message = "amount is too large")
    val amount: BigDecimal?,

    @field:NotNull(message = "category is required")
    val category: Category?,

    @field:Size(max = 255, message = "note must be at most 255 characters")
    val note: String? = null,

    @field:NotNull(message = "spentOn is required")
    @field:PastOrPresent(message = "spentOn cannot be in the future")
    val spentOn: LocalDate?,
)

data class ExpenseResponse(
    val id: UUID,
    val amount: BigDecimal,
    val category: Category,
    val note: String?,
    val spentOn: LocalDate,
    val createdAt: Instant,
    val updatedAt: Instant,
) {
    companion object {
        fun from(e: Expense) = ExpenseResponse(
            id = e.id,
            amount = e.amount,
            category = e.category,
            note = e.note,
            spentOn = e.spentOn,
            createdAt = e.createdAt,
            updatedAt = e.updatedAt,
        )
    }
}

data class PageResponse<T>(
    val items: List<T>,
    val page: Int,
    val size: Int,
    val totalItems: Long,
    val totalPages: Int,
)

data class CategoryTotalResponse(
    val category: Category,
    val total: BigDecimal,
    val count: Long,
)

data class SummaryResponse(
    val from: LocalDate,
    val to: LocalDate,
    val grandTotal: BigDecimal,
    val byCategory: List<CategoryTotalResponse>,
)

/** รูปแบบ error เดียวกันทุก endpoint */
data class ApiError(
    val status: Int,
    val error: String,
    val message: String,
    val fieldErrors: Map<String, String> = emptyMap(),
    val timestamp: Instant = Instant.now(),
)
