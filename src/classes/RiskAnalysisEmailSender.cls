/************************************************************************************
 * File Name : RiskAnalysisEmailSender.cls
 * Author : 최준석
 * Date : 2025-05-31
 * Description :
 * Modification Log
 * ===================================================================================
 * Ver Date Author Modification
 * ===================================================================================
 * 1.0 2025-05-31 최준석 Create
 *************************************************************************************/

public class RiskAnalysisEmailSender {
    // 메일 발송 제한 (Salesforce 일일 제한 고려)
    private static final Integer MAX_EMAILS_PER_BATCH = 100;

    /**
     * 위험 분석 보고서 메일을 발송하는 메인 메서드
     * @param accountId Account ID (Contact 조회용)
     * @param mailContent HTML 메일 내용
     * @param mailSubject 메일 제목 (RiskAnalyzeReport__c.MailSubject__c에서 가져온 값)
     */
    public static void sendRiskAnalysisEmail(Id accountId, String mailContent, String mailSubject) {
        try {
            // Account의 Contact 이메일 주소 조회
            List<Contact> contacts = [
                    SELECT Id, Email, Name
                    FROM Contact
                    WHERE AccountId = :accountId
                    AND Email != null
                    AND Email != ''
                    LIMIT 50
            ];

            if (contacts.isEmpty()) {
                System.debug('No contacts with email found for Account: ' + accountId);
                return;
            }

            // 메일 제목 설정 (기본값 제공)
            String emailSubject = String.isNotBlank(mailSubject) ?
                    mailSubject : '[LSMtron] 사출성형기 위험 분석 결과 - 즉시 확인 필요';

            // 메일 발송 리스트 생성
            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

            // Organization-Wide Email Address 조회 (발신자 설정)
            List<OrgWideEmailAddress> orgWideEmails = [
                    SELECT Id, Address, DisplayName
                    FROM OrgWideEmailAddress
                    WHERE Address LIKE '%lsmtron%' OR DisplayName LIKE '%LSMtron%'
                    LIMIT 1
            ];

            for (Contact contact : contacts) {
                if (emailsToSend.size() >= MAX_EMAILS_PER_BATCH) {
                    break; // 메일 발송 제한 준수
                }

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

                // 수신자 설정
                email.setToAddresses(new List<String>{contact.Email});

                // 발신자 설정 (Organization-Wide Email이 있으면 사용)
                if (!orgWideEmails.isEmpty()) {
                    email.setOrgWideEmailAddressId(orgWideEmails[0].Id);
                } else {
                    email.setSenderDisplayName('LSMtron 위험 분석 Agent');
                }

                // 메일 제목 (저장된 제목 사용)
                email.setSubject(emailSubject);

                // 메일 내용 (HTML) - Contact 이름으로 개인화
                String personalizedContent = personalizeEmailContent(mailContent, contact.Name);
                email.setHtmlBody(personalizedContent);

                // 텍스트 버전 (HTML 태그 제거)
                email.setPlainTextBody(stripHtmlTags(personalizedContent));

                // What ID 설정 (Account 연결)
                email.setWhatId(accountId);

                // Who ID 설정 (Contact 연결)
                email.setTargetObjectId(contact.Id);

                // 활동 저장 (메일 발송 기록)
                email.setSaveAsActivity(true);

                emailsToSend.add(email);
            }

            // 메일 발송 실행
            if (!emailsToSend.isEmpty()) {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailsToSend);

                // 발송 결과 로깅
                logEmailResults(results, contacts);

                System.debug('Successfully sent ' + emailsToSend.size() + ' risk analysis emails for Account: ' + accountId);
                System.debug('Email subject used: ' + emailSubject);
            } else {
                System.debug('No emails to send for Account: ' + accountId);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in sendRiskAnalysisEmail: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());

            // 에러 발생 시 관리자에게 알림
            sendErrorNotificationToAdmin(e, accountId);
        }
    }

    /**
     * 메일 내용을 개인화하는 메서드
     * @param mailContent 원본 메일 내용
     * @param contactName Contact 이름
     * @return String 개인화된 메일 내용
     */
    private static String personalizeEmailContent(String mailContent, String contactName) {
        String personalizedContent = mailContent;

        // Contact 이름으로 개인화
        if (String.isNotBlank(contactName)) {
            personalizedContent = personalizedContent.replace('담당자님께', contactName + '님께');
            personalizedContent = personalizedContent.replace('고객님의', contactName + '님의');
        }

        // 메일 하단에 발송 정보 추가
        personalizedContent += '<div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6; color: #6c757d; font-size: 12px; text-align: center;">';
        personalizedContent += '<p>발송 시간: ' + System.now().format('yyyy-MM-dd HH:mm:ss') + '</p>';
        personalizedContent += '<p>본 메일은 LSMtron 위험 분석 시스템에서 자동 발송되었습니다.</p>';
        personalizedContent += '</div>';

        return personalizedContent;
    }

    /**
     * HTML 태그를 제거하는 메서드
     * @param htmlString HTML 문자열
     * @return String 태그가 제거된 텍스트
     */
    private static String stripHtmlTags(String htmlString) {
        if (String.isBlank(htmlString)) return '';

        return htmlString.replaceAll('<[^>]+>', ' ')
                .replaceAll('\\s+', ' ')
                .trim();
    }

    /**
     * 메일 발송 결과를 로깅하는 메서드
     * @param results 메일 발송 결과 리스트
     * @param contacts 메일을 받은 Contact 리스트
     */
    private static void logEmailResults(List<Messaging.SendEmailResult> results, List<Contact> contacts) {
        Integer successCount = 0;
        Integer failureCount = 0;

        for (Integer i = 0; i < results.size(); i++) {
            Messaging.SendEmailResult result = results[i];
            String contactEmail = (i < contacts.size()) ? contacts[i].Email : 'Unknown';

            if (result.isSuccess()) {
                successCount++;
                System.debug('Email sent successfully to: ' + contactEmail);
            } else {
                failureCount++;
                System.debug(LoggingLevel.WARN, 'Email failed to: ' + contactEmail);

                // 에러 세부사항 로깅
                for (Messaging.SendEmailError error : result.getErrors()) {
                    System.debug(LoggingLevel.WARN, 'Email error: ' + error.getMessage());
                }
            }
        }

        System.debug('Email sending summary - Success: ' + successCount + ', Failed: ' + failureCount);
    }

    /**
     * 에러 발생 시 관리자에게 알림을 보내는 메서드
     * @param error 발생한 Exception
     * @param accountId Account ID
     */
    private static void sendErrorNotificationToAdmin(Exception error, Id accountId) {
        try {
            // 관리자 이메일 주소 (Custom Setting이나 Custom Metadata로 관리 권장)
            String adminEmail = 'admin@lsmtron.com'; // 실제 관리자 이메일로 변경 필요

            Messaging.SingleEmailMessage adminNotification = new Messaging.SingleEmailMessage();
            adminNotification.setToAddresses(new List<String>{adminEmail});
            adminNotification.setSubject('[시스템 알림] 위험 분석 메일 발송 오류');

            String errorBody = '위험 분석 메일 발송 중 오류가 발생했습니다.\n\n';
            errorBody += '오류 시간: ' + System.now() + '\n';
            errorBody += 'Account ID: ' + accountId + '\n';
            errorBody += '오류 메시지: ' + error.getMessage() + '\n';
            errorBody += '스택 트레이스: ' + error.getStackTraceString();

            adminNotification.setPlainTextBody(errorBody);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{adminNotification});

        } catch (Exception adminError) {
            System.debug(LoggingLevel.ERROR, 'Failed to send admin notification: ' + adminError.getMessage());
        }
    }

    /**
     * 대량 메일 발송을 위한 배치 처리 메서드 (Future 방식)
     * @param reportData Account ID, 메일 내용, 메일 제목을 포함한 맵
     * Map 구조: {accountId => 'mailContent|mailSubject'} 형태로 구분자 사용
     */
    @future
    public static void sendBulkRiskAnalysisEmails(Map<Id, String> reportData) {
        try {
            for (Id accountId : reportData.keySet()) {
                String combinedData = reportData.get(accountId);
                if (String.isNotBlank(combinedData)) {
                    // 구분자로 메일 내용과 제목 분리
                    List<String> dataParts = combinedData.split('\\|\\|\\|', 2); // ||| 구분자 사용

                    String mailContent = dataParts.size() > 0 ? dataParts[0] : '';
                    String mailSubject = dataParts.size() > 1 ? dataParts[1] : '';

                    if (String.isNotBlank(mailContent)) {
                        sendRiskAnalysisEmail(accountId, mailContent, mailSubject);
                    }
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in sendBulkRiskAnalysisEmails: ' + e.getMessage());
        }
    }

    /**
     * 호환성을 위한 오버로드 메서드 (제목 없이 호출하는 경우)
     * @param accountId Account ID
     * @param mailContent HTML 메일 내용
     */
    public static void sendRiskAnalysisEmail(Id accountId, String mailContent) {
        sendRiskAnalysisEmail(accountId, mailContent, null);
    }
}