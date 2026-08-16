package com.notifications.demo.email.service;

import com.notifications.demo.config.MailProperties;
import com.notifications.demo.email.EmailTemplateType;
import com.notifications.demo.email.api.EmailRequest;
import com.notifications.demo.email.api.EmailResponse;
import com.notifications.demo.email.exception.DuplicateEmailRequestException;
import com.notifications.demo.email.exception.EmailDeliveryException;
import com.notifications.demo.email.exception.EmailTemplateException;
import com.notifications.demo.email.exception.InvalidEmailRequestException;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import jakarta.mail.internet.InternetAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.MailException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;
import org.thymeleaf.exceptions.TemplateInputException;
import org.thymeleaf.exceptions.TemplateProcessingException;

import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class EmailServiceImpl implements EmailService {

    private static final Logger logger = LoggerFactory.getLogger(EmailServiceImpl.class);

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;
    private final MailProperties mailProperties;
    private final Set<String> processedCorrelationIds = ConcurrentHashMap.newKeySet();

    public EmailServiceImpl(JavaMailSender mailSender, TemplateEngine templateEngine, MailProperties mailProperties) {
        this.mailSender = mailSender;
        this.templateEngine = templateEngine;
        this.mailProperties = mailProperties;
    }

    @Override
    public EmailResponse sendEmail(EmailRequest request) {
        validateRequest(request);

        String correlationId = normalizeCorrelationId(request.getCorrelationId());
        if (correlationId != null && !processedCorrelationIds.add(correlationId)) {
            throw new DuplicateEmailRequestException("A request with this correlationId has already been processed");
        }

        String messageId = UUID.randomUUID().toString();
        try {
            MimeMessage mimeMessage = buildMessage(request);
            mailSender.send(mimeMessage);
            logger.info("Email sent successfully. messageId={}, correlationId={}, templateType={}",
                    messageId, safe(correlationId), request.getTemplateType());
            return new EmailResponse(
                    messageId,
                    "SENT",
                    OffsetDateTime.now(),
                    "Email request processed successfully"
            );
        } catch (MailException | MessagingException ex) {
            rollbackCorrelationId(correlationId);
            logger.warn("Email delivery failed. messageId={}, correlationId={}, templateType={}, reason={}",
                    messageId, safe(correlationId), request.getTemplateType(), ex.getClass().getSimpleName());
            throw new EmailDeliveryException("Failed to deliver email", ex);
        } catch (TemplateInputException | TemplateProcessingException ex) {
            rollbackCorrelationId(correlationId);
            logger.warn("Email template rendering failed. messageId={}, correlationId={}, templateType={}, reason={}",
                    messageId, safe(correlationId), request.getTemplateType(), ex.getClass().getSimpleName());
            throw new EmailTemplateException("Failed to process email template", ex);
        }
    }

    private MimeMessage buildMessage(EmailRequest request) throws MessagingException {
        Map<String, Object> templateVariables = new HashMap<>(request.getVariables());
        templateVariables.put("platformName", mailProperties.getPlatformName());
        templateVariables.put("primaryColor", mailProperties.getPrimaryColor());
        templateVariables.put("supportEmail", mailProperties.getSupportEmail());
        templateVariables.put("logoUrl", mailProperties.getLogoUrl());
        templateVariables.put("frontendUrl", mailProperties.getFrontendUrl());
        templateVariables.put("subject", resolveSubject(request.getTemplateType()));

        Context context = new Context();
        context.setVariables(templateVariables);

        String html = templateEngine.process(request.getTemplateType().getTemplateName(), context);
        String text = PlainTextEmailRenderer.render(request.getTemplateType(), templateVariables, mailProperties);

        MimeMessage mimeMessage = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(
                mimeMessage,
                true,
                StandardCharsets.UTF_8.name()
        );
        helper.setTo(request.getRecipient());
        helper.setFrom(mailProperties.getFromAddress(), mailProperties.getFromName());
        if (mailProperties.getReplyTo() != null && !mailProperties.getReplyTo().isBlank()) {
            helper.setReplyTo(mailProperties.getReplyTo());
        }
        helper.setSubject(resolveSubject(request.getTemplateType()));
        helper.setText(text, html);
        return mimeMessage;
    }

    private void validateRequest(EmailRequest request) {
        EmailTemplateType templateType = request.getTemplateType();
        Map<String, Object> variables = request.getVariables();
        validateRecipient(request.getRecipient());
        if (templateType == null) {
            throw new InvalidEmailRequestException("templateType is required");
        }
        if (variables == null) {
            throw new InvalidEmailRequestException("variables are required");
        }

        Set<String> missing = new HashSet<>();
        for (String field : templateType.getRequiredVariables()) {
            Object value = variables.get(field);
            if (value == null || (value instanceof String stringValue && stringValue.isBlank())) {
                missing.add(field);
            }
        }
        if (!missing.isEmpty()) {
            throw new InvalidEmailRequestException("Missing required variables: " + String.join(", ", missing));
        }

        if (templateType == EmailTemplateType.OTP) {
            String otp = String.valueOf(variables.get("otp"));
            if (!otp.matches("\\d{4,8}")) {
                throw new InvalidEmailRequestException("OTP must be 4 to 8 digits");
            }
            Integer expiresInMinutes = parsePositiveInteger(variables.get("expiresInMinutes"), "expiresInMinutes");
            variables.put("expiresInMinutes", expiresInMinutes);
        }

        if (templateType == EmailTemplateType.PASSWORD_RESET) {
            parsePositiveInteger(variables.get("expiresInMinutes"), "expiresInMinutes");
            validateUrlVariable(variables.get("resetUrl"), "resetUrl");
        }

        if (templateType == EmailTemplateType.EMAIL_VERIFICATION) {
            validateUrlVariable(variables.get("verificationUrl"), "verificationUrl");
        }
    }

    private void validateRecipient(String recipient) {
        try {
            InternetAddress address = new InternetAddress(recipient);
            address.validate();
        } catch (Exception exception) {
            throw new InvalidEmailRequestException("recipient must be a valid email address");
        }
    }

    private Integer parsePositiveInteger(Object value, String field) {
        try {
            int parsed = Integer.parseInt(String.valueOf(value));
            if (parsed <= 0) {
                throw new InvalidEmailRequestException(field + " must be a positive integer");
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw new InvalidEmailRequestException(field + " must be a positive integer");
        }
    }

    private void validateUrlVariable(Object value, String field) {
        String url = String.valueOf(value);
        if (!(url.startsWith("http://") || url.startsWith("https://"))) {
            throw new InvalidEmailRequestException(field + " must be a valid URL");
        }
    }

    private String resolveSubject(EmailTemplateType templateType) {
        return templateType.getSubject().replace("[PLATFORM_NAME]", mailProperties.getPlatformName());
    }

    private String normalizeCorrelationId(String correlationId) {
        if (correlationId == null || correlationId.isBlank()) {
            return null;
        }
        return correlationId.trim();
    }

    private void rollbackCorrelationId(String correlationId) {
        if (correlationId != null) {
            processedCorrelationIds.remove(correlationId);
        }
    }

    private String safe(String value) {
        return value == null ? "n/a" : value;
    }
}
