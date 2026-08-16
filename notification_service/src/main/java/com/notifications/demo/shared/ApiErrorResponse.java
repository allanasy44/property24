package com.notifications.demo.shared;

import java.time.OffsetDateTime;
import java.util.List;

public class ApiErrorResponse {

    private final OffsetDateTime timestamp;
    private final int status;
    private final String error;
    private final String message;
    private final List<String> details;

    public ApiErrorResponse(OffsetDateTime timestamp, int status, String error, String message, List<String> details) {
        this.timestamp = timestamp;
        this.status = status;
        this.error = error;
        this.message = message;
        this.details = details;
    }

    public OffsetDateTime getTimestamp() {
        return timestamp;
    }

    public int getStatus() {
        return status;
    }

    public String getError() {
        return error;
    }

    public String getMessage() {
        return message;
    }

    public List<String> getDetails() {
        return details;
    }
}
