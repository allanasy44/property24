package com.notifications.demo.shared;

import com.notifications.demo.email.exception.DuplicateEmailRequestException;
import com.notifications.demo.email.exception.EmailDeliveryException;
import com.notifications.demo.email.exception.EmailTemplateException;
import com.notifications.demo.email.exception.InvalidEmailRequestException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.OffsetDateTime;
import java.util.List;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException exception) {
        List<String> details = exception.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(FieldError::getDefaultMessage)
                .toList();
        return response(HttpStatus.BAD_REQUEST, "Validation failed", details);
    }

    @ExceptionHandler(InvalidEmailRequestException.class)
    public ResponseEntity<ApiErrorResponse> handleInvalidEmailRequest(InvalidEmailRequestException exception) {
        return response(HttpStatus.BAD_REQUEST, exception.getMessage(), List.of());
    }

    @ExceptionHandler(DuplicateEmailRequestException.class)
    public ResponseEntity<ApiErrorResponse> handleDuplicate(DuplicateEmailRequestException exception) {
        return response(HttpStatus.CONFLICT, exception.getMessage(), List.of());
    }

    @ExceptionHandler(EmailTemplateException.class)
    public ResponseEntity<ApiErrorResponse> handleTemplate(EmailTemplateException exception) {
        return response(HttpStatus.UNPROCESSABLE_ENTITY, exception.getMessage(), List.of());
    }

    @ExceptionHandler(EmailDeliveryException.class)
    public ResponseEntity<ApiErrorResponse> handleDelivery(EmailDeliveryException exception) {
        return response(HttpStatus.BAD_GATEWAY, exception.getMessage(), List.of());
    }

    private ResponseEntity<ApiErrorResponse> response(HttpStatus status, String message, List<String> details) {
        return ResponseEntity.status(status)
                .body(new ApiErrorResponse(
                        OffsetDateTime.now(),
                        status.value(),
                        status.getReasonPhrase(),
                        message,
                        details
                ));
    }
}
