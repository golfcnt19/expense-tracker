package dev.golfcnt19.expense.web

import dev.golfcnt19.expense.domain.Category
import dev.golfcnt19.expense.service.ExpenseService
import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.util.UriComponentsBuilder
import java.time.LocalDate
import java.util.UUID

@RestController
@RequestMapping("/api/expenses")
@Validated
class ExpenseController(
    private val service: ExpenseService,
) {

    @PostMapping
    fun create(
        @Valid @RequestBody request: ExpenseRequest,
        uriBuilder: UriComponentsBuilder,
    ): ResponseEntity<ExpenseResponse> {
        val created = service.create(request)
        val location = uriBuilder.path("/api/expenses/{id}").buildAndExpand(created.id).toUri()
        return ResponseEntity.created(location).body(created)
    }

    @GetMapping("/{id}")
    fun get(@PathVariable id: UUID): ExpenseResponse = service.get(id)

    /**
     * ค่าเริ่มต้นคือ 30 วันล่าสุด เพื่อไม่ให้เผลอสแกนทั้งตาราง
     * เมื่อ client ไม่ได้ส่งช่วงวันที่มา
     */
    @GetMapping
    fun search(
        @RequestParam(required = false)
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) from: LocalDate?,

        @RequestParam(required = false)
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) to: LocalDate?,

        @RequestParam(required = false) category: Category?,

        @RequestParam(defaultValue = "0") @Min(0) page: Int,

        @RequestParam(defaultValue = "20") @Min(1) @Max(100) size: Int,
    ): PageResponse<ExpenseResponse> {
        val end = to ?: LocalDate.now()
        val start = from ?: end.minusDays(30)
        return service.search(start, end, category, page, size)
    }

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: UUID,
        @Valid @RequestBody request: ExpenseRequest,
    ): ExpenseResponse = service.update(id, request)

    @DeleteMapping("/{id}")
    @org.springframework.web.bind.annotation.ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(@PathVariable id: UUID) = service.delete(id)

    @GetMapping("/summary")
    fun summary(
        @RequestParam(required = false)
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) from: LocalDate?,

        @RequestParam(required = false)
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) to: LocalDate?,
    ): SummaryResponse {
        val end = to ?: LocalDate.now()
        val start = from ?: end.minusDays(30)
        return service.summarise(start, end)
    }
}
