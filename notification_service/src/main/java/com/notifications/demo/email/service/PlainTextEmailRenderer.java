package com.notifications.demo.email.service;

import com.notifications.demo.config.MailProperties;
import com.notifications.demo.email.EmailTemplateType;

import java.util.Map;

final class PlainTextEmailRenderer {

    private PlainTextEmailRenderer() {
    }

    static String render(EmailTemplateType templateType, Map<String, Object> variables, MailProperties properties) {
        String firstName = String.valueOf(variables.getOrDefault("firstName", "Customer"));
        return switch (templateType) {
            case OTP -> """
                    %s

                    Hello %s,

                    Your one-time password is: %s
                    It expires in %s minutes.

                    Do not share this code with anyone. If you did not request it, please ignore this email.

                    Need help? Contact %s
                    """.formatted(properties.getPlatformName(), firstName, variables.get("otp"), variables.get("expiresInMinutes"), properties.getSupportEmail());
            case EMAIL_VERIFICATION -> base(firstName, "Verify your email address using this link: " + variables.get("verificationUrl"), properties);
            case PASSWORD_RESET -> base(firstName, "Reset your password using this link: " + variables.get("resetUrl"), properties);
            case WELCOME -> base(firstName, "Welcome to " + properties.getPlatformName() + ". We're glad you're here.", properties);
            case NEW_PROPERTY_ENQUIRY -> base(firstName, "You received a new enquiry for " + variables.get("propertyTitle") + ".", properties);
            case PROPERTY_VIEWING_REQUEST -> base(firstName, "A new viewing request was made for " + variables.get("propertyTitle") + ".", properties);
            case VIEWING_REQUEST_CONFIRMATION -> base(firstName, "Your viewing request for " + variables.get("propertyTitle") + " has been received.", properties);
            case RENTAL_APPLICATION_SUBMITTED -> base(firstName, "Your rental application for " + variables.get("propertyTitle") + " has been submitted.", properties);
            case RENTAL_APPLICATION_STATUS_UPDATE -> base(firstName, "Your application status is now " + variables.get("applicationStatus") + ".", properties);
            case RENT_PAYMENT_REMINDER -> base(firstName, "A rent payment of " + variables.get("amountDue") + " is due on " + variables.get("dueDate") + ".", properties);
            case PAYMENT_CONFIRMATION -> base(firstName, "We received your payment of " + variables.get("amountPaid") + " on " + variables.get("paymentDate") + ".", properties);
            case GENERAL_NOTIFICATION -> base(firstName, String.valueOf(variables.get("message")), properties);
        };
    }

    private static String base(String firstName, String body, MailProperties properties) {
        return """
                %s

                Hello %s,

                %s

                Need help? Contact %s
                """.formatted(properties.getPlatformName(), firstName, body, properties.getSupportEmail());
    }
}
