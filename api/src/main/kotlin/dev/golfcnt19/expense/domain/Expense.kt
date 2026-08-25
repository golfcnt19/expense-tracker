package dev.golfcnt19.expense.domain

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.Id
import jakarta.persistence.PreUpdate
import jakarta.persistence.Table
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

enum class Category {
    FOOD,
    TRANSPORT,
    HOUSING,
    UTILITIES,
    HEALTH,
    ENTERTAINMENT,
    OTHER,
}

@Entity
@Table(name = "expense")
class Expense(
    @Id
    @Column(name = "id", nullable = false, updatable = false)
    val id: UUID = UUID.randomUUID(),

    @Column(name = "amount", nullable = false, precision = 12, scale = 2)
    var amount: BigDecimal,

    @Enumerated(EnumType.STRING)
    @Column(name = "category", nullable = false, length = 32)
    var category: Category,

    @Column(name = "note", length = 255)
    var note: String? = null,

    @Column(name = "spent_on", nullable = false)
    var spentOn: LocalDate,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),

    @Column(name = "updated_at", nullable = false)
    var updatedAt: Instant = Instant.now(),
) {
    @PreUpdate
    fun touch() {
        updatedAt = Instant.now()
    }

    // JPA เทียบ entity ด้วย id เท่านั้น ไม่ใช่ทุกฟิลด์
    // ถ้าใช้ data class Kotlin จะ generate equals จากทุก property ซึ่งผิดสำหรับ entity
    override fun equals(other: Any?): Boolean =
        this === other || (other is Expense && id == other.id)

    override fun hashCode(): Int = id.hashCode()

    override fun toString(): String =
        "Expense(id=$id, amount=$amount, category=$category, spentOn=$spentOn)"
}
