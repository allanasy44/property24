package com.notifications.demo.email.service;

import com.notifications.demo.email.api.EmailRequest;
import com.notifications.demo.email.api.EmailResponse;

public interface EmailService {

    EmailResponse sendEmail(EmailRequest request);
}
