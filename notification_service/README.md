# Notification Service

This service exposes an internal email notification API for a housing platform built with Spring Boot, Thymeleaf, and `JavaMailSender`.

## Required environment variables

See [.env.example](/home/tanaka/Documents/property24/notification_service/.env.example).

## Run locally

```bash
./mvnw spring-boot:run
```

## API

`POST /api/v1/notifications/email`

Example OTP request:

```json
{
  "recipient": "tenant@example.com",
  "templateType": "OTP",
  "variables": {
    "firstName": "Tanaka",
    "otp": "384921",
    "expiresInMinutes": 10
  },
  "correlationId": "auth-otp-123"
}
```

Example verification request:

```json
{
  "recipient": "tenant@example.com",
  "templateType": "EMAIL_VERIFICATION",
  "variables": {
    "firstName": "Tanaka",
    "verificationUrl": "https://frontend.example.com/verify?token=abc"
  }
}
```

Example reminder request:

```json
{
  "recipient": "tenant@example.com",
  "templateType": "RENT_PAYMENT_REMINDER",
  "variables": {
    "firstName": "Tanaka",
    "propertyTitle": "8 Willow Street",
    "amountDue": "$850",
    "dueDate": "2026-09-01"
  }
}
```

## Template preview/testing

Automated tests render templates without sending real email by mocking `JavaMailSender`. For quick manual preview, start the app and call the API with a local SMTP catcher such as MailHog or GreenMail.

## Security considerations

- The service only accepts approved `EmailTemplateType` values.
- Clients cannot provide raw HTML, arbitrary template paths, sender addresses, or custom subjects.
- OTPs are rendered only for delivery and are not logged, generated, persisted, or verified here.
- Error responses avoid leaking SMTP credentials and sensitive variable values.

## Caller guidance

Other microservices should call this service over the internal endpoint, provide a stable `correlationId` for idempotency, and send only the variables required by the selected template.

## Supported template types

- `OTP`: `firstName`, `otp`, `expiresInMinutes`
- `EMAIL_VERIFICATION`: `firstName`, `verificationUrl`
- `PASSWORD_RESET`: `firstName`, `resetUrl`, `expiresInMinutes`
- `WELCOME`: `firstName`
- `NEW_PROPERTY_ENQUIRY`: `firstName`, `propertyTitle`, `enquirerName`, `enquiryMessage`
- `PROPERTY_VIEWING_REQUEST`: `firstName`, `propertyTitle`, `requesterName`, `preferredDate`
- `VIEWING_REQUEST_CONFIRMATION`: `firstName`, `propertyTitle`, `preferredDate`
- `RENTAL_APPLICATION_SUBMITTED`: `firstName`, `propertyTitle`, `applicationReference`
- `RENTAL_APPLICATION_STATUS_UPDATE`: `firstName`, `propertyTitle`, `applicationStatus`
- `RENT_PAYMENT_REMINDER`: `firstName`, `propertyTitle`, `amountDue`, `dueDate`
- `PAYMENT_CONFIRMATION`: `firstName`, `propertyTitle`, `amountPaid`, `paymentDate`
- `GENERAL_NOTIFICATION`: `firstName`, `message`
