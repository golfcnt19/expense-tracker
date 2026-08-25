package dev.golfcnt19.expense.web

import dev.golfcnt19.expense.service.ExpenseNotFoundException
import jakarta.validation.ConstraintViolationException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException

/**
 * รวมการแปลง exception เป็น response ไว้ที่เดียว
 * เพื่อให้ client เจอรูปแบบ error เหมือนกันทุก endpoint
 */
@RestControllerAdvice
class ApiExceptionHandler {

    private val log = LoggerFactory.getLogger(javaClass)

    @ExceptionHandler(ExpenseNotFoundException::class)
    fun notFound(ex: ExpenseNotFoundException): ResponseEntity<ApiError> =
        ResponseEntity.status(HttpStatus.NOT_FOUND).body(
            ApiError(
                status = HttpStatus.NOT_FOUND.value(),
                error = "Not Found",
                message = ex.message ?: "Resource not found",
            ),
        )

    /** @Valid ที่ request body ไม่ผ่าน */
    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun invalidBody(ex: MethodArgumentNotValidException): ResponseEntity<ApiError> {
        val fields = ex.bindingResult.fieldErrors.associate {
            it.field to (it.defaultMessage ?: "invalid")
        }
        return ResponseEntity.badRequest().body(
            ApiError(
                status = HttpStatus.BAD_REQUEST.value(),
                error = "Validation Failed",
                message = "Request body failed validation",
                fieldErrors = fields,
            ),
        )
    }

    /** @Min/@Max ที่ query parameter ไม่ผ่าน */
    @ExceptionHandler(ConstraintViolationException::class)
    fun invalidParam(ex: ConstraintViolationException): ResponseEntity<ApiError> {
        val fields = ex.constraintViolations.associate {
            it.propertyPath.toString().substringAfterLast('.') to it.message
        }
        return ResponseEntity.badRequest().body(
            ApiError(
                status = HttpStatus.BAD_REQUEST.value(),
                error = "Validation Failed",
                message = "Request parameters failed validation",
                fieldErrors = fields,
            ),
        )
    }

    /** ค่าที่แปลงชนิดไม่ได้ เช่น category ที่ไม่มีในระบบ หรือวันที่ผิดรูปแบบ */
    @ExceptionHandler(MethodArgumentTypeMismatchException::class)
    fun typeMismatch(ex: MethodArgumentTypeMismatchException): ResponseEntity<ApiError> =
        ResponseEntity.badRequest().body(
            ApiError(
                status = HttpStatus.BAD_REQUEST.value(),
                error = "Bad Request",
                message = "Parameter '${ex.name}' has an invalid value",
            ),
        )

    /** JSON เสีย หรือชนิดข้อมูลใน body ไม่ตรง */
    @ExceptionHandler(HttpMessageNotReadableException::class)
    fun unreadable(ex: HttpMessageNotReadableException): ResponseEntity<ApiError> =
        ResponseEntity.badRequest().body(
            ApiError(
                status = HttpStatus.BAD_REQUEST.value(),
                error = "Bad Request",
                message = "Request body is malformed or has the wrong types",
            ),
        )

    /**
     * ตัวรับสุดท้าย — log ของจริงไว้ฝั่งเซิร์ฟเวอร์
     * แต่ตอบ client แบบไม่เปิดเผยรายละเอียดภายใน
     */
    @ExceptionHandler(Exception::class)
    fun unexpected(ex: Exception): ResponseEntity<ApiError> {
        log.error("Unhandled exception", ex)
        return ResponseEntity.internalServerError().body(
            ApiError(
                status = HttpStatus.INTERNAL_SERVER_ERROR.value(),
                error = "Internal Server Error",
                message = "Something went wrong",
            ),
        )
    }
}
