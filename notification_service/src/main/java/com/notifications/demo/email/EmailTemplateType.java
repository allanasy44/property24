package com.notifications.demo.email;

import java.util.Set;

public enum EmailTemplateType {
    OTP(
            "Your one-time password",
            "email/otp",
            Set.of("firstName", "otp", "expiresInMinutes")
    ),
    EMAIL_VERIFICATION(
            "Verify your email address",
            "email/email-verification",
            Set.of("firstName", "verificationUrl")
    ),
    PASSWORD_RESET(
            "Reset your password",
            "email/password-reset",
            Set.of("firstName", "resetUrl", "expiresInMinutes")
    ),
    WELCOME(
            "Welcome to [PLATFORM_NAME]",
            "email/welcome",
            Set.of("firstName")
    ),
    NEW_PROPERTY_ENQUIRY(
            "New property enquiry received",
            "email/new-property-enquiry",
            Set.of("firstName", "propertyTitle", "enquirerName", "enquiryMessage")
    ),
    PROPERTY_VIEWING_REQUEST(
            "New property viewing request",
            "email/property-viewing-request",
            Set.of("firstName", "propertyTitle", "requesterName", "preferredDate")
    ),
    VIEWING_REQUEST_CONFIRMATION(
            "Your viewing request has been received",
            "email/viewing-request-confirmation",
            Set.of("firstName", "propertyTitle", "preferredDate")
    ),
    RENTAL_APPLICATION_SUBMITTED(
            "Rental application submitted",
            "email/rental-application-submitted",
            Set.of("firstName", "propertyTitle", "applicationReference")
    ),
    RENTAL_APPLICATION_STATUS_UPDATE(
            "Rental application status update",
            "email/rental-application-status-update",
            Set.of("firstName", "propertyTitle", "applicationStatus")
    ),
    RENT_PAYMENT_REMINDER(
            "Rent payment reminder",
            "email/rent-payment-reminder",
            Set.of("firstName", "propertyTitle", "amountDue", "dueDate")
    ),
    PAYMENT_CONFIRMATION(
            "Payment confirmation",
            "email/payment-confirmation",
            Set.of("firstName", "propertyTitle", "amountPaid", "paymentDate")
    ),
    GENERAL_NOTIFICATION(
            "Important update from [PLATFORM_NAME]",
            "email/general-notification",
            Set.of("firstName", "message")
    );

    private final String subject;
    private final String templateName;
    private final Set<String> requiredVariables;

    EmailTemplateType(String subject, String templateName, Set<String> requiredVariables) {
        this.subject = subject;
        this.templateName = templateName;
        this.requiredVariables = requiredVariables;
    }

    public String getSubject() {
        return subject;
    }

    public String getTemplateName() {
        return templateName;
    }

    public Set<String> getRequiredVariables() {
        return requiredVariables;
    }
}
