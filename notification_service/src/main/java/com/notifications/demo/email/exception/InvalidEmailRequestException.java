package com.notifications.demo.email.exception;

public class InvalidEmailRequestException extends RuntimeException {

    public InvalidEmailRequestException(String message) {
        super(message);
    }
}
