package com.notifications.demo.email.api;

import com.notifications.demo.email.EmailTemplateType;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.Map;

public class EmailRequest {

    @Email
    @NotBlank
    private String recipient;

    @NotNull
    private EmailTemplateType templateType;

    @NotNull
    private Map<String, Object> variables;

    private String correlationId;

    public String getRecipient() {
        return recipient;
    }

    public void setRecipient(String recipient) {
        this.recipient = recipient;
    }

    public EmailTemplateType getTemplateType() {
        return templateType;
    }

    public void setTemplateType(EmailTemplateType templateType) {
        this.templateType = templateType;
    }

    public Map<String, Object> getVariables() {
        return variables;
    }

    public void setVariables(Map<String, Object> variables) {
        this.variables = variables;
    }

    public String getCorrelationId() {
        return correlationId;
    }

    public void setCorrelationId(String correlationId) {
        this.correlationId = correlationId;
    }
}
