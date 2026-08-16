package com.notifications.demo.email.service;

import com.notifications.demo.config.MailProperties;
import com.notifications.demo.email.EmailTemplateType;
import com.notifications.demo.email.api.EmailRequest;
import com.notifications.demo.email.api.EmailResponse;
import com.notifications.demo.email.exception.DuplicateEmailRequestException;
import com.notifications.demo.email.exception.EmailDeliveryException;
import com.notifications.demo.email.exception.EmailTemplateException;
import com.notifications.demo.email.exception.InvalidEmailRequestException;
import jakarta.mail.Address;
import jakarta.mail.BodyPart;
import jakarta.mail.Message;
import jakarta.mail.Multipart;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;
import org.thymeleaf.exceptions.TemplateInputException;

import java.util.Map;
import java.util.Properties;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EmailServiceImplTest {

    private JavaMailSender mailSender;
    private TemplateEngine templateEngine;
    private EmailServiceImpl emailService;

    @BeforeEach
    void setUp() {
        mailSender = mock(JavaMailSender.class);
        templateEngine = mock(TemplateEngine.class);
        when(mailSender.createMimeMessage()).thenReturn(new MimeMessage(Session.getInstance(new Properties())));
        when(templateEngine.process(any(String.class), any(Context.class))).thenReturn("<html><body>Rendered</body></html>");
        emailService = new EmailServiceImpl(mailSender, templateEngine, properties());
    }

    @Test
    void sendsOtpEmailWithMultipartHtmlAndText() throws Exception {
        EmailResponse response = emailService.sendEmail(request(EmailTemplateType.OTP, Map.of(
                "firstName", "Tanaka",
                "otp", "384921",
                "expiresInMinutes", 10
        )));

        ArgumentCaptor<MimeMessage> captor = ArgumentCaptor.forClass(MimeMessage.class);
        verify(mailSender).send(captor.capture());
        MimeMessage sentMessage = captor.getValue();

        assertThat(response.getDeliveryStatus()).isEqualTo("SENT");
        assertThat(sentMessage.getSubject()).isEqualTo("Your one-time password");
        Address[] recipients = sentMessage.getRecipients(Message.RecipientType.TO);
        assertThat(recipients).hasSize(1);
        assertThat(recipients[0].toString()).isEqualTo("tenant@example.com");

        Multipart multipart = (Multipart) sentMessage.getContent();
        assertThat(multipart.getCount()).isEqualTo(1);
        BodyPart alternativePart = multipart.getBodyPart(0);
        Multipart alternativeMultipart = (Multipart) alternativePart.getContent();
        assertThat(alternativeMultipart.getCount()).isEqualTo(2);
        assertThat(alternativeMultipart.getBodyPart(0).getContent().toString()).contains("384921");
        assertThat(alternativeMultipart.getBodyPart(1).getContent().toString()).contains("Rendered");
    }

    @Test
    void selectsCorrectTemplateAndSubject() {
        emailService.sendEmail(request(EmailTemplateType.WELCOME, Map.of("firstName", "Tanaka")));

        verify(templateEngine).process(eq("email/welcome"), any(Context.class));
    }

    @Test
    void rejectsMissingVariables() {
        assertThatThrownBy(() -> emailService.sendEmail(request(EmailTemplateType.OTP, Map.of(
                "firstName", "Tanaka",
                "otp", "384921"
        ))))
                .isInstanceOf(InvalidEmailRequestException.class)
                .hasMessageContaining("expiresInMinutes");
    }

    @Test
    void rejectsInvalidRecipientAddress() {
        EmailRequest request = request(EmailTemplateType.WELCOME, Map.of("firstName", "Tanaka"));
        request.setRecipient("invalid-email");

        assertThatThrownBy(() -> emailService.sendEmail(request))
                .isInstanceOf(InvalidEmailRequestException.class)
                .hasMessageContaining("recipient");
    }

    @Test
    void wrapsMailFailures() {
        doThrow(new MailSendException("SMTP down")).when(mailSender).send(any(MimeMessage.class));

        assertThatThrownBy(() -> emailService.sendEmail(request(EmailTemplateType.WELCOME, Map.of("firstName", "Tanaka"))))
                .isInstanceOf(EmailDeliveryException.class);
    }

    @Test
    void wrapsTemplateFailures() {
        when(templateEngine.process(any(String.class), any(Context.class)))
                .thenThrow(new TemplateInputException("missing"));

        assertThatThrownBy(() -> emailService.sendEmail(request(EmailTemplateType.WELCOME, Map.of("firstName", "Tanaka"))))
                .isInstanceOf(EmailTemplateException.class);
    }

    @Test
    void preventsDuplicateCorrelationIdReuse() {
        EmailRequest request = request(EmailTemplateType.WELCOME, Map.of("firstName", "Tanaka"));
        request.setCorrelationId("same-id");

        emailService.sendEmail(request);

        assertThatThrownBy(() -> emailService.sendEmail(request))
                .isInstanceOf(DuplicateEmailRequestException.class);
    }

    private EmailRequest request(EmailTemplateType type, Map<String, Object> variables) {
        EmailRequest request = new EmailRequest();
        request.setRecipient("tenant@example.com");
        request.setTemplateType(type);
        request.setVariables(variables);
        return request;
    }

    private MailProperties properties() {
        MailProperties properties = new MailProperties();
        properties.setFromAddress("no-reply@example.com");
        properties.setFromName("[PLATFORM_NAME]");
        properties.setReplyTo("support@example.com");
        properties.setFrontendUrl("https://frontend.example.com");
        properties.setSupportEmail("support@example.com");
        properties.setLogoUrl("https://frontend.example.com/logo.png");
        properties.setPlatformName("[PLATFORM_NAME]");
        properties.setPrimaryColor("#1F6FEB");
        return properties;
    }
}
