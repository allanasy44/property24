package com.notifications.demo.email.api;

import java.time.OffsetDateTime;

public class EmailResponse {

    private final String messageId;
    private final String deliveryStatus;
    private final OffsetDateTime timestamp;
    private final String message;

    public EmailResponse(String messageId, String deliveryStatus, OffsetDateTime timestamp, String message) {
        this.messageId = messageId;
        this.deliveryStatus = deliveryStatus;
        this.timestamp = timestamp;
        this.message = message;
    }

    public String getMessageId() {
        return messageId;
    }

    public String getDeliveryStatus() {
        return deliveryStatus;
    }

    public OffsetDateTime getTimestamp() {
        return timestamp;
    }

    public String getMessage() {
        return message;
    }
}
