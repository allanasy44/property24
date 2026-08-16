package com.notifications.demo.email.exception;

public class DuplicateEmailRequestException extends RuntimeException {

    public DuplicateEmailRequestException(String message) {
        super(message);
    }
}
