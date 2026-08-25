package dev.golfcnt19.expense.service

import dev.golfcnt19.expense.domain.Category
import dev.golfcnt19.expense.domain.Expense
import dev.golfcnt19.expense.domain.ExpenseRepository
import dev.golfcnt19.expense.web.CategoryTotalResponse
import dev.golfcnt19.expense.web.ExpenseRequest
import dev.golfcnt19.expense.web.ExpenseResponse
import dev.golfcnt19.expense.web.PageResponse
import dev.golfcnt19.expense.web.SummaryResponse
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.time.LocalDate
import java.util.UUID

class ExpenseNotFoundException(id: UUID) : RuntimeException("Expense $id not found")

@Service
@Transactional(readOnly = true)
class ExpenseService(
    private val repository: ExpenseRepository,
) {

    @Transactional
    fun create(request: ExpenseRequest): ExpenseResponse {
        val expense = Expense(
            amount = request.amount!!,
            category = request.category!!,
            note = request.note?.trim()?.ifBlank { null },
            spentOn = request.spentOn!!,
        )
        return ExpenseResponse.from(repository.save(expense))
    }

    fun get(id: UUID): ExpenseResponse =
        repository.findById(id)
            .map(ExpenseResponse::from)
            .orElseThrow { ExpenseNotFoundException(id) }

    fun search(
        from: LocalDate,
        to: LocalDate,
        category: Category?,
        page: Int,
        size: Int,
    ): PageResponse<ExpenseResponse> {
        val pageable = PageRequest.of(
            page,
            size,
            Sort.by(Sort.Direction.DESC, "spentOn").and(Sort.by(Sort.Direction.DESC, "id")),
        )
        val result = repository.search(from, to, category, pageable)
        return PageResponse(
            items = result.content.map(ExpenseResponse::from),
            page = result.number,
            size = result.size,
            totalItems = result.totalElements,
            totalPages = result.totalPages,
        )
    }

    @Transactional
    fun update(id: UUID, request: ExpenseRequest): ExpenseResponse {
        val expense = repository.findById(id).orElseThrow { ExpenseNotFoundException(id) }
        expense.amount = request.amount!!
        expense.category = request.category!!
        expense.note = request.note?.trim()?.ifBlank { null }
        expense.spentOn = request.spentOn!!
        return ExpenseResponse.from(repository.save(expense))
    }

    @Transactional
    fun delete(id: UUID) {
        if (!repository.existsById(id)) throw ExpenseNotFoundException(id)
        repository.deleteById(id)
    }

    fun summarise(from: LocalDate, to: LocalDate): SummaryResponse {
        val rows = repository.summarise(from, to)
        return SummaryResponse(
            from = from,
            to = to,
            grandTotal = rows.fold(BigDecimal.ZERO) { acc, r -> acc + r.total },
            byCategory = rows.map { CategoryTotalResponse(it.category, it.total, it.count) },
        )
    }
}
