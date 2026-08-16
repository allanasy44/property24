package com.notifications.demo.email.api;

import com.notifications.demo.email.EmailTemplateType;
import com.notifications.demo.email.exception.EmailDeliveryException;
import com.notifications.demo.email.service.EmailService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(EmailController.class)
@Import(com.notifications.demo.shared.GlobalExceptionHandler.class)
class EmailControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private EmailService emailService;

    @Test
    void returnsAcceptedForValidRequest() throws Exception {
        when(emailService.sendEmail(any())).thenReturn(new EmailResponse(
                "message-123",
                "SENT",
                OffsetDateTime.parse("2026-08-16T10:15:30Z"),
                "Email request processed successfully"
        ));

        mockMvc.perform(post("/api/v1/notifications/email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "recipient": "tenant@example.com",
                                  "templateType": "OTP",
                                  "variables": {
                                    "firstName": "Tanaka",
                                    "otp": "384921",
                                    "expiresInMinutes": 10
                                  }
                                }
                                """))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.messageId").value("message-123"))
                .andExpect(jsonPath("$.deliveryStatus").value("SENT"));
    }

    @Test
    void returnsBadRequestForValidationErrors() throws Exception {
        mockMvc.perform(post("/api/v1/notifications/email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "recipient": "not-an-email",
                                  "templateType": null,
                                  "variables": null
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Validation failed"));
    }

    @Test
    void doesNotLeakSensitiveValuesOnFailures() throws Exception {
        when(emailService.sendEmail(any())).thenThrow(new EmailDeliveryException("Failed to deliver email", new RuntimeException("smtp")));

        mockMvc.perform(post("/api/v1/notifications/email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "recipient": "tenant@example.com",
                                  "templateType": "OTP",
                                  "variables": {
                                    "firstName": "Tanaka",
                                    "otp": "384921",
                                    "expiresInMinutes": 10
                                  }
                                }
                                """))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.message").value("Failed to deliver email"))
                .andExpect(jsonPath("$.details").isArray())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("384921"))));
    }
}
