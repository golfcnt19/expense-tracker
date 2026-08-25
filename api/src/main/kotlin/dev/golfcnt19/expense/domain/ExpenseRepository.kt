package dev.golfcnt19.expense.domain

import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.math.BigDecimal
import java.time.LocalDate
import java.util.UUID

/** ผลรวมต่อหมวด ใช้กับหน้าสรุป */
interface CategoryTotal {
    val category: Category
    val total: BigDecimal
    val count: Long
}

interface ExpenseRepository : JpaRepository<Expense, UUID> {

    /**
     * ดึงรายการตามช่วงวันที่ กรอง category ได้ (ส่ง null = ไม่กรอง)
     *
     * เขียนเป็น query เดียวที่รับ null ได้ แทนการทำ method หลายตัว
     * เพื่อให้ฐานข้อมูลใช้ index ตัวเดียวกันทุกกรณี
     */
    @Query(
        """
        SELECT e FROM Expense e
        WHERE e.spentOn BETWEEN :from AND :to
          AND (:category IS NULL OR e.category = :category)
        """,
    )
    fun search(
        @Param("from") from: LocalDate,
        @Param("to") to: LocalDate,
        @Param("category") category: Category?,
        pageable: Pageable,
    ): Page<Expense>

    /**
     * สรุปยอดต่อหมวดในช่วงวันที่
     *
     * ให้ฐานข้อมูลรวมยอดให้ ไม่ดึงทุกแถวมารวมในแอป —
     * เป็น endpoint ที่หนักที่สุด จึงเป็นเป้าหลักของ load test
     */
    @Query(
        """
        SELECT e.category AS category,
               SUM(e.amount) AS total,
               COUNT(e) AS count
        FROM Expense e
        WHERE e.spentOn BETWEEN :from AND :to
        GROUP BY e.category
        ORDER BY SUM(e.amount) DESC
        """,
    )
    fun summarise(
        @Param("from") from: LocalDate,
        @Param("to") to: LocalDate,
    ): List<CategoryTotal>
}
