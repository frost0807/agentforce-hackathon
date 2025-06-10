/************************************************************************************
 * File Name : SelfQuoteController.cls
 * Author : 최준석
 * Date : 2025-06-04
 * Description :
 * Modification Log
 * ===================================================================================
 * Ver Date Author Modification
 * ===================================================================================
 * 1.0 2025-06-04 최준석 Create
 *************************************************************************************/
public with sharing class SelfQuoteController {
    /**
     * Service Quote 데이터 조회 (수정된 메서드)
     * @param serviceQuoteId Service Quote ID (우선순위)
     * @param accountId 고객사 ID (fallback)
     * @return ServiceQuoteResult Service Quote 및 LineItem 데이터
     */
    @AuraEnabled(cacheable=true)
    public static ServiceQuoteResult getServiceQuoteData(String serviceQuoteId, String accountId) {
        ServiceQuoteResult result = new ServiceQuoteResult();

        try {
            System.debug('🔍 getServiceQuoteData called with:');
            System.debug('🔍 serviceQuoteId: ' + serviceQuoteId);
            System.debug('🔍 accountId: ' + accountId);

            // 1. serviceQuoteId가 있으면 직접 Service Quote 조회
            if (String.isNotBlank(serviceQuoteId)) {
                System.debug('📋 Service Quote ID로 직접 조회');

                List<ServiceQuote__c> quotes = [
                        SELECT Id, Name, OfferNo__c, QuoteDate__c,
                                Method_of_Payment__c, Validity__c, Packing__c, Inspection__c,
                                DeliveryCondition__c, AccountId__c, AccountId__r.Name
                        FROM ServiceQuote__c
                        WHERE Id = :serviceQuoteId
                        LIMIT 1
                ];

                if (!quotes.isEmpty()) {
                    result.serviceQuote = quotes[0];
                    result.accountName = quotes[0].AccountId__r?.Name;

                    System.debug('✅ Service Quote 조회 성공: ' + quotes[0].Id);

                    // Service Quote Line Items 조회
                    List<ServiceQuoteLineItem__c> lineItems = [
                            SELECT Id, ProductId__c, ProductId__r.Name, ProductId__r.ProductClassification__c,
                                    Quantity__c, UnitPrice__c, Unit__c
                            FROM ServiceQuoteLineItem__c
                            WHERE ServiceQuote__c = :quotes[0].Id
                            ORDER BY CreatedDate ASC
                    ];

                    result.lineItems = lineItems;
                    result.success = true;

                    System.debug('📊 Line Items 개수: ' + lineItems.size());
                    return result;
                } else {
                    System.debug('⚠️ Service Quote를 찾을 수 없음: ' + serviceQuoteId);
                }
            }

            // 2. serviceQuoteId가 없거나 조회 실패 시 accountId로 fallback
            if (String.isNotBlank(accountId)) {
                System.debug('🏢 Account ID로 fallback 조회');

                // Account 정보 조회
                List<Account> accounts = [
                        SELECT Id, Name, BillingAddress
                        FROM Account
                        WHERE Id = :accountId
                        LIMIT 1
                ];

                if (accounts.isEmpty()) {
                    throw new AuraHandledException('고객사 정보를 찾을 수 없습니다.');
                }

                result.accountName = accounts[0].Name;

                // 최신 Service Quote 조회
                List<ServiceQuote__c> quotes = [
                        SELECT Id, Name, OfferNo__c, QuoteDate__c,
                                Method_of_Payment__c, Validity__c, Packing__c, Inspection__c,
                                DeliveryCondition__c
                        FROM ServiceQuote__c
                        WHERE AccountId__c = :accountId
                        ORDER BY CreatedDate DESC
                        LIMIT 1
                ];

                if (quotes.isEmpty()) {
                    throw new AuraHandledException('견적서 정보를 찾을 수 없습니다.');
                }

                result.serviceQuote = quotes[0];

                // Service Quote Line Items 조회
                List<ServiceQuoteLineItem__c> lineItems = [
                        SELECT Id, ProductId__c, ProductId__r.Name, ProductId__r.ProductClassification__c,
                                Quantity__c, UnitPrice__c, Unit__c
                        FROM ServiceQuoteLineItem__c
                        WHERE ServiceQuote__c = :quotes[0].Id
                        ORDER BY CreatedDate ASC
                ];

                result.lineItems = lineItems;
                result.success = true;

                System.debug('✅ Account ID로 조회 성공');
            } else {
                // 둘 다 없으면 오류
                throw new AuraHandledException('Service Quote ID 또는 Account ID가 필요합니다.');
            }

        } catch (Exception e) {
            result.success = false;
            result.message = '데이터 조회 중 오류 발생: ' + e.getMessage();
            System.debug('💥 Error in getServiceQuoteData: ' + e.getMessage());
            System.debug('💥 Stack trace: ' + e.getStackTraceString());
        }

        return result;
    }

    /**
     * PDF 생성, 이메일 발송, 파일 저장
     * @param serviceQuoteId Service Quote ID
     * @param recipientEmail 수신자 이메일
     * @return ServiceQuoteSaveResult 처리 결과
     */
    @AuraEnabled
    public static ServiceQuoteSaveResult createPDFAndSendEmail(Id serviceQuoteId, String recipientEmail) {
        ServiceQuoteSaveResult result = new ServiceQuoteSaveResult();

        try {
            if (serviceQuoteId == null || String.isBlank(recipientEmail)) {
                result.success = false;
                result.message = '필수 정보가 누락되었습니다.';
                return result;
            }

            // Service Quote 및 관련 데이터 조회
            List<ServiceQuote__c> quotes = [
                    SELECT Id, Name, OfferNo__c, QuoteDate__c, AccountId__c,
                            AccountId__r.Name, AccountId__r.BillingAddress,
                            Method_of_Payment__c, Validity__c, Packing__c, Inspection__c,
                            DeliveryCondition__c
                    FROM ServiceQuote__c
                    WHERE Id = :serviceQuoteId
                    LIMIT 1
            ];

            if (quotes.isEmpty()) {
                result.success = false;
                result.message = '견적서를 찾을 수 없습니다.';
                return result;
            }

            ServiceQuote__c quote = quotes[0];

            // Line Items 조회
            List<ServiceQuoteLineItem__c> lineItems = [
                    SELECT Id, ProductId__r.Name, ProductId__r.ProductClassification__c,
                            Quantity__c, UnitPrice__c, Unit__c
                    FROM ServiceQuoteLineItem__c
                    WHERE ServiceQuote__c = :serviceQuoteId
                    ORDER BY CreatedDate ASC
            ];

            // PDF 생성
            Blob pdfBlob = generateQuotePDF(quote, lineItems);

            // 파일명 생성
            String fileName = 'Quote_' + quote.OfferNo__c + '_' +
                    String.valueOf(Date.today()).replace('-', '') + '.pdf';

            // ContentVersion 생성 (파일 저장)
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = fileName;
            contentVersion.VersionData = pdfBlob;
            contentVersion.IsMajorVersion = true;
            contentVersion.Description = '견적서 PDF - ' + quote.OfferNo__c;

            insert contentVersion;

            // ContentDocumentLink 생성 (Service Quote에 연결)
            ContentVersion insertedCV = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :contentVersion.Id
            ];

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = serviceQuoteId;
            cdl.ContentDocumentId = insertedCV.ContentDocumentId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';

            insert cdl;

            // 이메일 발송
            sendQuoteEmail(quote, lineItems, pdfBlob, fileName, recipientEmail);

            result.success = true;
            result.message = '견적서 PDF가 생성되어 ' + recipientEmail + '로 발송되었습니다.';

        } catch (Exception e) {
            result.success = false;
            result.message = 'PDF 생성/발송 중 오류 발생: ' + e.getMessage();
            System.debug('Error in createPDFAndSendEmail: ' + e.getMessage());
        }

        return result;
    }

    /**
     * HTML을 이용한 PDF 생성
     */
    public static Blob generateQuotePDF(ServiceQuote__c quote, List<ServiceQuoteLineItem__c> lineItems) {
        // 총 금액 계산
        Decimal totalAmount = 0;
        Integer totalQuantity = 0;

        for (ServiceQuoteLineItem__c item : lineItems) {
            if (item.Quantity__c != null && item.UnitPrice__c != null) {
                totalAmount += (item.Quantity__c * item.UnitPrice__c);
                totalQuantity += Integer.valueOf(item.Quantity__c);
            }
        }

        // HTML 템플릿 생성
        String htmlContent = buildQuoteHTML(quote, lineItems, totalAmount, totalQuantity);

        // HTML을 PDF로 변환
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Test PDF Content');
        } else {
            try {
                // PageReference를 이용한 PDF 생성
                pdfBlob = generatePDFFromHTML(htmlContent);
            } catch (Exception e) {
                System.debug('PDF 생성 실패, 대체 방법 사용: ' + e.getMessage());
                pdfBlob = Blob.valueOf(htmlContent); // 임시 대체
            }
        }

        return pdfBlob;
    }

    /**
     * HTML을 PDF로 변환하는 헬퍼 메서드
     */
    private static Blob generatePDFFromHTML(String htmlContent) {
        // Salesforce의 제한된 환경에서 HTML을 PDF로 변환
        // PageReference를 이용한 PDF 생성
        try {
            PageReference tempPage = Page.ServiceQuotePDF; // ServiceQuotePDF Visualforce 페이지
            if (tempPage != null) {
                tempPage.getParameters().put('htmlContent', htmlContent);
                return tempPage.getContentAsPDF();
            }
        } catch (Exception e) {
            System.debug('PageReference PDF 생성 실패: ' + e.getMessage());
        }

        // 폴백: 텍스트 기반 PDF 시뮬레이션
        return Blob.valueOf(htmlContent);
    }

    /**
     * 견적서 HTML 템플릿 생성
     */
    public static String buildQuoteHTML(ServiceQuote__c quote, List<ServiceQuoteLineItem__c> lineItems,
            Decimal totalAmount, Integer totalQuantity) {
        String html = '<!DOCTYPE html>';
        html += '<html><head>';
        html += '<meta charset="UTF-8">';
        html += '<style>';
        html += 'body { font-family: Arial, sans-serif; margin: 20px; }';
        html += 'table { width: 100%; border-collapse: collapse; margin: 10px 0; }';
        html += 'th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }';
        html += 'th { background-color: #f2f2f2; }';
        html += '.header { text-align: center; margin-bottom: 30px; }';
        html += '.total { font-weight: bold; background-color: #f0f8ff; }';
        html += '</style>';
        html += '</head><body>';

        // 헤더
        html += '<div class="header">';
        html += '<h1>견적서</h1>';
        html += '<p>Offer No: ' + (quote.OfferNo__c != null ? quote.OfferNo__c : '') + '</p>';
        html += '<p>Quote Date: ' + (quote.QuoteDate__c != null ? quote.QuoteDate__c.format() : '') + '</p>';
        html += '</div>';

        // 고객 정보
        html += '<h2>■ 사용정보</h2>';
        html += '<table>';
        html += '<tr><th>고객사</th><th>담당자</th><th>수량</th><th>금액</th></tr>';
        html += '<tr>';
        html += '<td>' + (quote.AccountId__r.Name != null ? quote.AccountId__r.Name : '') + '</td>';
        html += '<td>담당자명</td>';
        html += '<td>' + String.valueOf(totalQuantity) + '</td>';
        html += '<td>' + String.valueOf(totalAmount.setScale(0)) + '</td>';
        html += '</tr>';
        html += '</table>';

        // 부품 목록
        html += '<h2>■ 기자 출입 및 부대설비</h2>';
        html += '<table>';
        html += '<tr><th>No.</th><th>품목명</th><th>규격</th><th>수량</th><th>단가</th><th>금액</th></tr>';

        Integer index = 1;
        for (ServiceQuoteLineItem__c item : lineItems) {
            Decimal itemTotal = (item.Quantity__c != null && item.UnitPrice__c != null) ?
                    item.Quantity__c * item.UnitPrice__c : 0;

            html += '<tr>';
            html += '<td>' + String.valueOf(index++) + '</td>';
            html += '<td>' + (item.ProductId__r.Name != null ? item.ProductId__r.Name : '') + '</td>';
            html += '<td>' + (item.ProductId__r.ProductClassification__c != null ? item.ProductId__r.ProductClassification__c : '') + '</td>';
            html += '<td>' + (item.Quantity__c != null ? String.valueOf(item.Quantity__c.setScale(0)) : '0') + '</td>';
            html += '<td>' + (item.UnitPrice__c != null ? String.valueOf(item.UnitPrice__c.setScale(0)) : '0') + '</td>';
            html += '<td>' + String.valueOf(itemTotal.setScale(0)) + '</td>';
            html += '</tr>';
        }
        html += '</table>';

        // 견적 조건
        html += '<h2>■ 견적 조건</h2>';
        html += '<table>';
        html += '<tr><th>납기</th><td>' + (quote.DeliveryCondition__c != null ? quote.DeliveryCondition__c : '') + '</td>';
        html += '<th>결제조건</th><td>' + (quote.Method_of_Payment__c != null ? quote.Method_of_Payment__c : '') + '</td></tr>';
        html += '<tr><th>유효기간</th><td>' + (quote.Validity__c != null ? quote.Validity__c : '') + '</td>';
        html += '<th>포장</th><td>' + (quote.Packing__c != null ? quote.Packing__c : '') + '</td></tr>';
        html += '<tr><th>검사</th><td>' + (quote.Inspection__c != null ? quote.Inspection__c : '') + '</td>';
        html += '<th>기타</th><td>별도 명시사항 없음</td></tr>';
        html += '</table>';

        // 총 금액
        html += '<div style="margin-top: 20px; text-align: right;">';
        html += '<h3>합계 금액: ' + String.valueOf(totalAmount.setScale(0)) + '</h3>';
        html += '</div>';

        // 하단 메모
        html += '<div style="text-align: center; margin-top: 30px;">';
        html += '<p>상기와 같이 견적서를 제출합니다.</p>';
        html += '</div>';

        html += '</body></html>';

        return html;
    }

    /**
     * 견적서 이메일 발송
     */
    public static void sendQuoteEmail(ServiceQuote__c quote, List<ServiceQuoteLineItem__c> lineItems,
            Blob pdfBlob, String fileName, String recipientEmail) {

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { recipientEmail });
        email.setSubject('견적서 - ' + quote.OfferNo__c);

        String emailBody = '안녕하세요.\n\n';
        emailBody += '요청하신 견적서를 첨부하여 보내드립니다.\n\n';
        emailBody += '견적서 번호: ' + quote.OfferNo__c + '\n';
        emailBody += '견적 일자: ' + (quote.QuoteDate__c != null ? quote.QuoteDate__c.format() : '') + '\n';
        emailBody += '고객사: ' + quote.AccountId__r.Name + '\n\n';
        emailBody += '문의사항이 있으시면 언제든 연락 주시기 바랍니다.\n\n';
        emailBody += '감사합니다.';

        email.setPlainTextBody(emailBody);

        // PDF 첨부
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(fileName);
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');

        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

        // 이메일 발송
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }

    /**
     * Service Quote 및 Line Item 생성
     * @param quoteData 견적서 데이터
     * @return QuoteResult 생성 결과
     */
    @AuraEnabled
    public static QuoteResult createServiceQuote(ServiceQuoteData quoteData) {
        QuoteResult result = new QuoteResult();

        try {
            if (quoteData == null) {
                result.success = false;
                result.message = '견적서 데이터가 없습니다.';
                return result;
            }

            // Service Quote 생성
            ServiceQuote__c serviceQuote = new ServiceQuote__c();
            serviceQuote.Name = quoteData.quoteNumber;
            serviceQuote.AccountId__c = quoteData.accountId;
            serviceQuote.QuoteDate__c = Date.valueOf(quoteData.quoteDate);
            serviceQuote.OfferNo__c = quoteData.quoteNumber;
            serviceQuote.Method_of_Payment__c = '현금';
            serviceQuote.Validity__c = '견적일로부터 30일';
            serviceQuote.Packing__c = '목재포장';
            serviceQuote.Inspection__c = '사내검사';
            serviceQuote.Email__c = UserInfo.getUserEmail();
            serviceQuote.QuoteCreatedBy__c = UserInfo.getName();

            insert serviceQuote;
            result.serviceQuoteId = serviceQuote.Id;

            // Service Quote Line Items 생성
            List<ServiceQuoteLineItem__c> lineItems = new List<ServiceQuoteLineItem__c>();

            for (ServiceQuoteLineData lineData : quoteData.selectedParts) {
                ServiceQuoteLineItem__c lineItem = new ServiceQuoteLineItem__c();
                lineItem.ServiceQuote__c = serviceQuote.Id;
                lineItem.ProductId__c = lineData.productId;
                lineItem.Quantity__c = lineData.quantity;
                lineItem.UnitPrice__c = lineData.unitPrice;
                lineItem.Unit__c = 'EA';

                lineItems.add(lineItem);
            }

            if (!lineItems.isEmpty()) {
                insert lineItems;
            }

            // Account에 첨부파일 생성 (PDF 시뮬레이션)
            try {
                ContentVersion contentVersion = new ContentVersion();
                contentVersion.Title = 'Quote_' + quoteData.quoteNumber + '.pdf';
                contentVersion.PathOnClient = 'Quote_' + quoteData.quoteNumber + '.pdf';
                contentVersion.VersionData = createQuotePDF(quoteData);
                contentVersion.IsMajorVersion = true;

                insert contentVersion;

                // ContentDocumentLink 생성
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.LinkedEntityId = quoteData.accountId;
                cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';

                insert cdl;

                result.attachmentId = contentVersion.Id;

            } catch (Exception attachError) {
                System.debug('첨부파일 생성 실패: ' + attachError.getMessage());
                // 첨부파일 생성 실패해도 견적서는 생성됨
            }

            result.success = true;
            result.message = '견적서가 성공적으로 생성되었습니다.';

            System.debug('Service Quote created successfully: ' + serviceQuote.Id);

        } catch (Exception e) {
            result.success = false;
            result.message = '견적서 생성 중 오류가 발생했습니다: ' + e.getMessage();
            System.debug('Error creating service quote: ' + e.getMessage());
        }

        return result;
    }

    /**
     * 견적서 이메일 발송
     * @param serviceQuoteId Service Quote ID
     * @param recipientEmail 수신자 이메일
     * @param quoteData 견적서 데이터
     * @return EmailResult 발송 결과
     */
    @AuraEnabled
    public static EmailResult sendQuoteEmail(Id serviceQuoteId, String recipientEmail, ServiceQuoteData quoteData) {
        EmailResult result = new EmailResult();

        try {
            // 이메일 템플릿 생성
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { recipientEmail });
            email.setSubject('견적서 - ' + quoteData.quoteNumber);

            String emailBody = '안녕하세요.\n\n';
            emailBody += '요청하신 견적서를 첨부하여 보내드립니다.\n\n';
            emailBody += '견적서 번호: ' + quoteData.quoteNumber + '\n';
            emailBody += '견적 일자: ' + quoteData.quoteDate + '\n';
            emailBody += '총 금액: ' + String.valueOf(quoteData.totalAmount) + '원\n\n';
            emailBody += '문의사항이 있으시면 언제든 연락 주시기 바랍니다.\n\n';
            emailBody += '감사합니다.';

            email.setPlainTextBody(emailBody);

            // PDF 첨부파일 추가
            try {
                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName('Quote_' + quoteData.quoteNumber + '.pdf');
                attachment.setBody(createQuotePDF(quoteData));
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            } catch (Exception attachError) {
                System.debug('이메일 첨부파일 생성 실패: ' + attachError.getMessage());
            }

            // 이메일 발송
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

            result.success = true;
            result.message = '이메일이 성공적으로 발송되었습니다.';

            System.debug('Quote email sent to: ' + recipientEmail);

        } catch (Exception e) {
            result.success = false;
            result.message = '이메일 발송 중 오류가 발생했습니다: ' + e.getMessage();
            System.debug('Error sending quote email: ' + e.getMessage());
        }

        return result;
    }

    /**
     * 현재 사용자 정보 조회
     * @return User 현재 사용자
     */
    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        try {
            return [
                    SELECT Id, Name, Email, Username
                    FROM User
                    WHERE Id = :UserInfo.getUserId()
                    LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Error getting current user: ' + e.getMessage());
            throw new AuraHandledException('사용자 정보를 조회하는 중 오류가 발생했습니다.');
        }
    }

    /**
     * 견적서 PDF 생성 (시뮬레이션)
     * @param quoteData 견적서 데이터
     * @return Blob PDF 데이터
     */
    private static Blob createQuotePDF(ServiceQuoteData quoteData) {
        // 실제 환경에서는 PDF 생성 라이브러리나 Visualforce PDF 등을 사용
        // 여기서는 간단한 텍스트로 시뮬레이션
        String pdfContent = '=== 견적서 ===\n\n';
        pdfContent += '견적서 번호: ' + quoteData.quoteNumber + '\n';
        pdfContent += '견적 일자: ' + quoteData.quoteDate + '\n';
        pdfContent += '고객사: ' + (quoteData.accountId != null ? '고객사명' : 'N/A') + '\n\n';
        pdfContent += '=== 부품 목록 ===\n';

        for (ServiceQuoteLineData lineData : quoteData.selectedParts) {
            pdfContent += '제품: ' + lineData.productId + '\n';
            pdfContent += '수량: ' + lineData.quantity + '\n';
            pdfContent += '단가: ' + lineData.unitPrice + '\n';
            pdfContent += '합계: ' + lineData.totalPrice + '\n\n';
        }

        pdfContent += '총 금액: ' + quoteData.totalAmount + '원\n';

        return Blob.valueOf(pdfContent);
    }

    // Wrapper 클래스들

    /**
     * Service Quote 결과 클래스
     */
    public class ServiceQuoteResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public ServiceQuote__c serviceQuote { get; set; }
        @AuraEnabled public List<ServiceQuoteLineItem__c> lineItems { get; set; }
        @AuraEnabled public String accountName { get; set; }

        public ServiceQuoteResult() {
            this.success = false;
            this.lineItems = new List<ServiceQuoteLineItem__c>();
        }
    }

    /**
     * Service Quote 저장 결과 클래스
     */
    public class ServiceQuoteSaveResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }

        public ServiceQuoteSaveResult() {
            this.success = false;
        }
    }

    /**
     * Service Quote 데이터 구조
     */
    public class ServiceQuoteData {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String quoteNumber { get; set; }
        @AuraEnabled public String quoteDate { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Id riskAnalyzeReportId { get; set; }
        @AuraEnabled public List<ServiceQuoteLineData> selectedParts { get; set; }

        public ServiceQuoteData() {
            this.selectedParts = new List<ServiceQuoteLineData>();
        }
    }

    /**
     * Service Quote Line Item 데이터 구조
     */
    public class ServiceQuoteLineData {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
    }

    /**
     * 견적서 생성 결과 클래스
     */
    public class QuoteResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id serviceQuoteId { get; set; }
        @AuraEnabled public Id attachmentId { get; set; }

        public QuoteResult() {
            this.success = false;
            this.message = '';
        }
    }

    /**
     * 이메일 발송 결과 클래스
     */
    public class EmailResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }

        public EmailResult() {
            this.success = false;
            this.message = '';
        }
    }
}