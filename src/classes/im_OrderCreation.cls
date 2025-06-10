/************************************************************************************
* File Name   	    : im_OrderCreation
* Author	  		: Jiae.Tak
* Date				: 2025-06-06
* Tester	  		:
* Target	  		:
* Description 	    :
* Modification Log
* ===================================================================================
* Ver      Date            Author          Modification
* ===================================================================================
* 1.0      2025-06-06         Jiae.Tak          Create
************************************************************************************/
public with sharing class im_OrderCreation {
    @InvocableMethod(
            Label='주문 생성'
            Description='Order 를 생성합니다.'
            Category='주문 생성'
    )
    public static List<Response> orderCreation(List<Request> listRequests){
        List<Response> responses = new List<Response>();

        if (listRequests == null || listRequests.isEmpty()) {
            responses.add(new Response('요청이 비어 있습니다.'));
            return responses;
        }

        Id messagingSessionId = listRequests[0].messagingSessionId;
        Id loginUserId = listRequests[0].loginUserId;
        System.debug('Request : ' + JSON.serializePretty(listRequests));

        // 로직 시작 전 스피너 활성화
        PublishMessageController.publishMessage('SHOW_SPINNER', '');
        System.debug('DEBUG_ORDER_CREATION: SHOW_SPINNER 이벤트 발송됨');

        try {
            if(messagingSessionId != null){
                List<MessagingSession> listMessagingSessions = [SELECT Id, RiskAnalyzeReportId__c FROM MessagingSession WHERE Id =: messagingSessionId LIMIT 1];

                if (listMessagingSessions.isEmpty()) {
                    PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                    responses.add(new Response('해당 MessagingSession을 찾을 수 없습니다.'));
                    return responses;
                }

                Id riskAnalyzeReportId = listMessagingSessions[0].RiskAnalyzeReportId__c;
                if (riskAnalyzeReportId == null) {
                    PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                    responses.add(new Response('RiskAnalyzeReportId__c가 비어 있습니다.'));
                    return responses;
                }

                List<SelectedPartItem__c> listSelectedPartItems = [
                        SELECT Id, Product__c, Product__r.Name, Quantity__c, Product__r.ProductCode, Product__r.Price__c, RiskAnalyzeReport__r.Account__c, RiskAnalyzeReport__r.Account__r.Name
                        FROM SelectedPartItem__c
                        WHERE RiskAnalyzeReport__c =: riskAnalyzeReportId
                ];

                if (listSelectedPartItems.isEmpty()) {
                    PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                    responses.add(new Response('선택된 부품 항목이 없습니다. 주문을 생성할 수 없습니다.'));
                    return responses;
                }

                try {
                    if (listSelectedPartItems[0].RiskAnalyzeReport__r.Account__c != null) {
                        Order newOrder = new Order();
                        newOrder.AccountId = listSelectedPartItems[0].RiskAnalyzeReport__r.Account__c;
                        newOrder.Status = 'Draft';
                        newOrder.EffectiveDate = Date.today();
                        newOrder.Pricebook2Id = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

                        insert newOrder;

                        List<OrderItem> newOrderItems = new List<OrderItem>();
                        Map<Id, PricebookEntry> productToPricebookEntryMap = new Map<Id, PricebookEntry>();
                        List<Id> productIds = new List<Id>();
                        for(SelectedPartItem__c item : listSelectedPartItems) { productIds.add(item.Product__c); }

                        for (PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id IN :productIds AND Pricebook2Id = :newOrder.Pricebook2Id]) {
                            productToPricebookEntryMap.put(pbe.Product2Id, pbe);
                        }

                        for (SelectedPartItem__c item : listSelectedPartItems) {
                            if (productToPricebookEntryMap.containsKey(item.Product__c)) {
                                newOrderItems.add(new OrderItem(
                                        OrderId = newOrder.Id,
                                        Product2Id = item.Product__c,
                                        Quantity = item.Quantity__c,
                                        PricebookEntryId = productToPricebookEntryMap.get(item.Product__c).Id,
                                        UnitPrice = productToPricebookEntryMap.get(item.Product__c).UnitPrice
                                ));
                            }
                        }

                        if (!newOrderItems.isEmpty()) {
                            insert newOrderItems;

                            // 이메일 발송 메서드 호출
                            Map<String, Object> emailResult = createPDFAndSendEmail(riskAnalyzeReportId);
                            System.debug('DEBUG_ORDER_CREATION: 이메일 발송 결과 - ' + emailResult);

                            // 로직 완료 후 스피너 비활성화
                            PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                            System.debug('DEBUG_ORDER_CREATION: DISABLE_SPINNER 이벤트 발송됨');

                            responses.add(new Response('Order (' + newOrder.OrderNumber + ') 및 ' + newOrderItems.size() + '개의 OrderItem이 성공적으로 생성되었습니다.'));
                        } else {
                            PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                            responses.add(new Response('생성할 OrderItem이 없습니다.'));
                        }
                    } else {
                        PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                        responses.add(new Response('SelectedPartItem에서 계정 정보를 찾을 수 없습니다.'));
                    }
                } catch (Exception e) {
                    PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                    responses.add(new Response('주문 생성 중 오류가 발생했습니다: ' + e.getMessage()));
                }

            } else {
                PublishMessageController.publishMessage('DISABLE_SPINNER', '');
                responses.add(new Response('messagingSessionId가 비어 있습니다.'));
            }

        } catch (Exception e) {
            // 예상치 못한 오류 발생 시에도 스피너 비활성화
            PublishMessageController.publishMessage('DISABLE_SPINNER', '');
            System.debug('ERROR_ORDER_CREATION: 예상치 못한 오류 - ' + e.getMessage());
            responses.add(new Response('주문 생성 중 예상치 못한 오류가 발생했습니다: ' + e.getMessage()));
        }

        return responses;
    }

    public static Map<String,Object> createPDFAndSendEmail(Id riskAnalyzeReportId) {
        Map<String,Object> result = new Map<String,Object>();
        try {
            List<ServiceQuote__c> quotes = [
                    SELECT Id, Name, OfferNo__c, QuoteDate__c, AccountId__c, AccountId__r.Name,
                            Method_of_Payment__c, Validity__c, Packing__c, Inspection__c,
                            DeliveryCondition__c, RiskAnalyzeReport__c, Email__c
                    FROM ServiceQuote__c
                    WHERE RiskAnalyzeReport__c = :riskAnalyzeReportId LIMIT 1
            ];

            if (quotes.isEmpty()) {
                result.put('status', 'ERROR');
                result.put('message', '견적서를 찾을 수 없습니다. RiskAnalyzeReportId: ' + riskAnalyzeReportId);
                System.debug('ERROR_EMAIL_PROCESS: 견적서를 찾을 수 없습니다. RiskAnalyzeReportId: ' + riskAnalyzeReportId);
                return result;
            }
            ServiceQuote__c quote = quotes[0];
            System.debug('DEBUG_EMAIL_PROCESS: ServiceQuote found: ' + quote.Id + ' - OfferNo: ' + quote.OfferNo__c);

            List<ServiceQuoteLineItem__c> lineItems = [
                    SELECT Id, ProductId__r.Name, ProductId__r.ProductClassification__c, Quantity__c, UnitPrice__c, Unit__c
                    FROM ServiceQuoteLineItem__c
                    WHERE ServiceQuote__c = :quote.Id ORDER BY CreatedDate ASC
            ];

            if (lineItems.isEmpty()) {
                result.put('status', 'ERROR');
                result.put('message', '견적서에 라인 항목이 없습니다. 이메일을 생성할 수 없습니다.');
                System.debug('ERROR_EMAIL_PROCESS: 견적서에 라인 항목이 없습니다. 견적서 Id: ' + quote.Id);
                return result;
            }
            System.debug('DEBUG_EMAIL_PROCESS: ServiceQuoteLineItems found: ' + lineItems.size());

            // HTML 본문 생성
            String htmlBody = generateQuoteHtml(quote, lineItems);
            System.debug('DEBUG_EMAIL_PROCESS: Generated HTML Body length: ' + htmlBody.length());

            // 이메일 주소 목록
            List<String> contactEmailList = new List<String>();
            contactEmailList.add('jiae.tak@daeunextier.com');
            contactEmailList.add('jiae.salesforce@gmail.com');
            contactEmailList.add('junesuk.choi@daeunextier.com');

            if (contactEmailList.isEmpty()) {
                result.put('status', 'ERROR');
                result.put('message', '발송할 이메일 주소가 없습니다.');
                System.debug('ERROR_EMAIL_PROCESS: 발송할 이메일 주소가 없습니다.');
                return result;
            }
            System.debug('DEBUG_EMAIL_PROCESS: Target Email Addresses: ' + String.join(contactEmailList, ', '));

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.toAddresses = contactEmailList;
            message.htmlBody = htmlBody;
            message.subject = '견적서 - ' + quote.OfferNo__c;
            message.setSaveAsActivity(false);

            OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'jiaetak' LIMIT 1];

            if (owea.isEmpty()) {
                result.put('status', 'ERROR');
                System.debug('FATAL_ERROR_EMAIL_PROCESS: 검증된 조직 전체 이메일 주소를 찾을 수 없습니다.');
                return result;
            } else {
                message.setOrgWideEmailAddressId(owea[0].Id);
                System.debug('OrgWideEmailAddressId: ' + owea[0].Id);
            }

            Id contactIdToAssociate = null;
            List<Contact> relatedContacts = [SELECT Id FROM Contact WHERE AccountId = :quote.AccountId__c LIMIT 1];
            if (!relatedContacts.isEmpty()) {
                contactIdToAssociate = relatedContacts[0].Id;
            }

            if (contactIdToAssociate != null) {
                message.setTargetObjectId(contactIdToAssociate);
                message.setSaveAsActivity(true);
            } else {
                System.debug('DEBUG_EMAIL_PROCESS: Associated Contact not found for Account ' + quote.AccountId__c + '. Email activity will not be linked to a specific contact.');
                message.setSaveAsActivity(false);
            }

            Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {message};
            System.debug('DEBUG_EMAIL_PROCESS: SingleEmailMessage prepared. Subject: ' + message.subject + ', To: ' + message.toAddresses);

            // 이메일 발송 시도
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
            System.debug('DEBUG_EMAIL_PROCESS: Messaging.sendEmail call completed. Checking results...');

            if (results != null && !results.isEmpty()) {
                for (Integer i = 0; i < results.size(); i++) {
                    Messaging.SendEmailResult res = results[i];
                    System.debug('DEBUG_EMAIL_PROCESS: Result for message ' + (i+1) + ' (isSuccess): ' + res.isSuccess());
                    if (res.isSuccess()) {
                        System.debug('SUCCESS_EMAIL_PROCESS: 이메일이 성공적으로 발송되었습니다.');
                        result.put('status', 'SUCCESS');
                        result.put('message', '견적서가 ' + String.join(contactEmailList, ', ') + '로 발송되었습니다.');
                    } else {
                        System.debug('ERROR_EMAIL_PROCESS: 이메일 발송 실패 - 메시지 ' + (i+1));
                        String errorMessages = '';
                        if (res.getErrors() != null && !res.getErrors().isEmpty()) {
                            System.debug('res.getError : ' + res.getErrors());
                        } else {
                            errorMessages = '상세 오류 정보를 찾을 수 없습니다.';
                            System.debug('ERROR_EMAIL_PROCESS_DETAILS: 상세 오류 정보를 찾을 수 없습니다.');
                        }
                        result.put('status', 'ERROR');
                        result.put('message', '이메일 발송 중 오류 발생: ' + errorMessages);
                    }
                }
            } else {
                result.put('status', 'ERROR');
                result.put('message', 'Messaging.sendEmail 호출 후 결과를 받지 못했습니다. (results is null or empty)');
                System.debug('ERROR_EMAIL_PROCESS: Messaging.sendEmail 호출 후 결과를 받지 못했습니다. results 배열이 비어있거나 null 입니다.');
            }

        } catch (Exception e) {
            result.put('status', 'ERROR');
            result.put('message', '이메일 발송 중 치명적인 오류 발생: ' + e.getMessage() + ' at line ' + e.getLineNumber() + ' (' + e.getStackTraceString() + ')');
            System.debug('FATAL_ERROR_EMAIL_PROCESS: ' + e.getMessage() + ' at line ' + e.getLineNumber() + '\nStack Trace: ' + e.getStackTraceString());
        }

        System.debug('result : '  + result);
        return result;
    }

    /**
     * 견적서 HTML 생성 메서드 (로고 위치 수정)
     */
    private static String generateQuoteHtml(ServiceQuote__c quote, List<ServiceQuoteLineItem__c> lineItems) {
        Decimal totalAmount = 0;
        Decimal totalQuantity = 0;

        // 총액 및 총수량 계산
        for(ServiceQuoteLineItem__c item : lineItems) {
            if(item.Quantity__c != null && item.UnitPrice__c != null) {
                totalAmount += (item.Quantity__c * item.UnitPrice__c);
                totalQuantity += item.Quantity__c;
            }
        }

        // 견적 날짜 포맷팅
        String formattedQuoteDate = '';
        if (quote.QuoteDate__c != null) {
            Date quoteDate = quote.QuoteDate__c;
            formattedQuoteDate = quoteDate.year() + '. ' +
                    String.valueOf(quoteDate.month()).leftPad(2, '0') + '. ' +
                    String.valueOf(quoteDate.day()).leftPad(2, '0') + '.';
        }

        // Static Resource URL 생성 (LSMtronLogo - SVG 파일)
        String orgDomain = System.URL.getOrgDomainUrl().toExternalForm();
        String logoUrl = orgDomain + '/resource/LSMtronLogo';

        String htmlBody = '<!DOCTYPE html>';
        htmlBody += '<html><head>';
        htmlBody += '<meta charset="UTF-8">';
        htmlBody += '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
        htmlBody += '<style>';
        htmlBody += 'body { font-family: "Malgun Gothic", "맑은 고딕", Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }';
        htmlBody += '.quote-container { max-width: 900px; margin: 0 auto; padding: 40px; background-color: white; color: #000; border: 2px solid #000; }';

        // 수정된 제목 섹션 스타일
        htmlBody += '.quote-title-section { margin-bottom: 40px; border-bottom: 3px solid #000; padding-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }';
        htmlBody += '.main-title { font-size: 2.5rem; font-weight: bold; margin: 0; letter-spacing: 4px; flex: 1; text-align: center; }';
        htmlBody += '.company-logo { width: 120px; height: 60px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }';
        htmlBody += '.logo-image { max-width: 100%; max-height: 100%; object-fit: contain; }';

        htmlBody += '.section-header { font-size: 1.2rem; font-weight: bold; margin: 30px 0 15px 0; padding: 8px 0; border-bottom: 2px solid #000; }';
        htmlBody += '.parts-table { width: 100%; border-collapse: collapse; margin-bottom: 30px; font-size: 13px; border: 1px solid #000; }';
        htmlBody += '.parts-table thead th { background-color: #f5f5f5; font-weight: bold; padding: 6px 8px; text-align: center; border: 1px solid #000; font-size: 14px; }';
        htmlBody += '.parts-table tbody td { padding: 5px 8px; border: 1px solid #000; vertical-align: middle; background-color: white; }';
        htmlBody += '.center { text-align: center; }';
        htmlBody += '.right { text-align: right; font-family: "Courier New", monospace; font-weight: 500; }';
        htmlBody += '.total-row { font-weight: bold; }';
        htmlBody += '.total-row td { border-top: 2px solid #000; padding: 8px; background-color: #f5f5f5; font-weight: bold; }';
        htmlBody += '.total-quantity { background-color: white !important; color: #000 !important; }';
        htmlBody += '.total-amount-cell { background-color: white !important; color: #c41e3a !important; font-size: 1rem; font-family: "Courier New", monospace; }';
        htmlBody += '.quote-details { margin: 30px 0; padding: 20px; border: 1px solid #000; background-color: #f9f9f9; }';
        htmlBody += '.quote-info-row { display: flex; justify-content: space-between; margin-bottom: 12px; align-items: center; }';
        htmlBody += '.quote-info-row:last-child { margin-bottom: 0; }';
        htmlBody += '.quote-info-item { flex: 1; display: flex; align-items: center; padding: 0 10px; }';
        htmlBody += '.quote-info-item .label { font-weight: bold; min-width: 80px; margin-right: 10px; }';
        htmlBody += '.quote-info-item .value { flex: 1; }';
        htmlBody += '.conditions-table { width: 100%; border-collapse: collapse; border: 1px solid #000; margin: 30px 0; }';
        htmlBody += '.conditions-table td { padding: 6px 12px; border: 1px solid #000; font-size: 13px; }';
        htmlBody += '.condition-label { background-color: #f5f5f5; font-weight: bold; width: 15%; text-align: center; }';
        htmlBody += '.condition-value { background-color: white; width: 35%; padding-left: 15px; }';
        htmlBody += '.memo-section { text-align: center; margin: 40px 0; font-size: 14px; font-weight: 500; padding: 20px; border-top: 1px solid #ccc; }';
        htmlBody += '</style>';
        htmlBody += '</head><body>';

        htmlBody += '<div class="quote-container">';

        // 수정된 제목 섹션 - flexbox로 좌우 정렬
        htmlBody += '<div class="quote-title-section">';
        htmlBody += '<h1 class="main-title">견적서</h1>';
        htmlBody += '<div class="company-logo">';
        htmlBody += '<img src="' + logoUrl + '" alt="LSMtron" class="logo-image" />';
        htmlBody += '</div>';
        htmlBody += '</div>';

        // 견적 항목 섹션
        htmlBody += '<div class="parts-section">';
        htmlBody += '<h2 class="section-header">■ 견적 항목</h2>';
        htmlBody += '<table class="parts-table">';
        htmlBody += '<thead>';
        htmlBody += '<tr>';
        htmlBody += '<th>No.</th>';
        htmlBody += '<th>품목명</th>';
        htmlBody += '<th>규격</th>';
        htmlBody += '<th>수량</th>';
        htmlBody += '<th>단가</th>';
        htmlBody += '<th>금액</th>';
        htmlBody += '</tr>';
        htmlBody += '</thead>';
        htmlBody += '<tbody>';

        // 라인 아이템들
        Integer index = 1;
        for(ServiceQuoteLineItem__c item : lineItems) {
            Decimal itemTotal = (item.Quantity__c != null && item.UnitPrice__c != null) ?
                    (item.Quantity__c * item.UnitPrice__c) : 0;

            htmlBody += '<tr>';
            htmlBody += '<td class="center">' + index + '</td>';
            htmlBody += '<td>' + (item.ProductId__r.Name != null ? item.ProductId__r.Name : '') + '</td>';
            htmlBody += '<td>' + (item.ProductId__r.ProductClassification__c != null ? item.ProductId__r.ProductClassification__c : '') + '</td>';
            htmlBody += '<td class="center">' + (item.Quantity__c != null ? String.valueOf(item.Quantity__c.intValue()) : '0') + '</td>';
            htmlBody += '<td class="right">' + formatCurrency(item.UnitPrice__c) + '</td>';
            htmlBody += '<td class="right">' + formatCurrency(itemTotal) + '</td>';
            htmlBody += '</tr>';
            index++;
        }

        // 합계 행
        htmlBody += '<tr class="total-row">';
        htmlBody += '<td class="center" colspan="3">합계</td>';
        htmlBody += '<td class="center total-quantity">' + String.valueOf(totalQuantity.intValue()) + '</td>';
        htmlBody += '<td class="center">총액</td>';
        htmlBody += '<td class="right total-amount-cell">' + formatCurrency(totalAmount) + '</td>';
        htmlBody += '</tr>';

        htmlBody += '</tbody>';
        htmlBody += '</table>';
        htmlBody += '</div>';

        // 견적서 정보
        htmlBody += '<div class="quote-details">';
        htmlBody += '<div class="quote-info-row">';
        htmlBody += '<div class="quote-info-item">';
        htmlBody += '<span class="label">Offer No:</span>';
        htmlBody += '<span class="value">' + (quote.OfferNo__c != null ? quote.OfferNo__c : '') + '</span>';
        htmlBody += '</div>';
        htmlBody += '<div class="quote-info-item">';
        htmlBody += '<span class="label">Quote Date:</span>';
        htmlBody += '<span class="value">' + formattedQuoteDate + '</span>';
        htmlBody += '</div>';
        htmlBody += '</div>';
        htmlBody += '<div class="quote-info-row">';
        htmlBody += '<div class="quote-info-item">';
        htmlBody += '<span class="label">고객사:</span>';
        htmlBody += '<span class="value">' + (quote.AccountId__r.Name != null ? quote.AccountId__r.Name : '') + '</span>';
        htmlBody += '</div>';
        htmlBody += '<div class="quote-info-item">';
        htmlBody += '<span class="label">담당자:</span>';
        htmlBody += '<span class="value">담당자명</span>';
        htmlBody += '</div>';
        htmlBody += '</div>';
        htmlBody += '</div>';

        // 조건 테이블
        htmlBody += '<table class="conditions-table">';
        htmlBody += '<tr>';
        htmlBody += '<td class="condition-label">납기:</td>';
        htmlBody += '<td class="condition-value">' + (quote.DeliveryCondition__c != null ? quote.DeliveryCondition__c : '') + '</td>';
        htmlBody += '<td class="condition-label">결제조건:</td>';
        htmlBody += '<td class="condition-value">' + (quote.Method_of_Payment__c != null ? quote.Method_of_Payment__c : '') + '</td>';
        htmlBody += '</tr>';
        htmlBody += '<tr>';
        htmlBody += '<td class="condition-label">포장:</td>';
        htmlBody += '<td class="condition-value">' + (quote.Packing__c != null ? quote.Packing__c : '') + '</td>';
        htmlBody += '<td class="condition-label">검사:</td>';
        htmlBody += '<td class="condition-value">' + (quote.Inspection__c != null ? quote.Inspection__c : '') + '</td>';
        htmlBody += '</tr>';
        htmlBody += '<tr>';
        htmlBody += '<td class="condition-label">유효기간:</td>';
        htmlBody += '<td class="condition-value">' + (quote.Validity__c != null ? quote.Validity__c : '') + '</td>';
        htmlBody += '<td class="condition-label">기타:</td>';
        htmlBody += '<td class="condition-value">별도 명시사항 없음</td>';
        htmlBody += '</tr>';
        htmlBody += '</table>';

        // 하단 메모
        htmlBody += '<div class="memo-section">';
        htmlBody += '<p>상기와 같이 견적서를 제출합니다.</p>';
        htmlBody += '</div>';

        htmlBody += '</div>'; // quote-container 닫기
        htmlBody += '</body></html>';

        return htmlBody;
    }

    /**
     * 통화 포맷팅 헬퍼 메서드
     */
    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0';

        // 소수점 제거하고 정수로 변환
        Long intAmount = amount.longValue();

        // 3자리마다 콤마 추가
        String amountStr = String.valueOf(intAmount);
        String formattedAmount = '';
        Integer counter = 0;

        for (Integer i = amountStr.length() - 1; i >= 0; i--) {
            if (counter > 0 && Math.mod(counter, 3) == 0) {
                formattedAmount = ',' + formattedAmount;
            }
            formattedAmount = amountStr.substring(i, i + 1) + formattedAmount;
            counter++;
        }

        return formattedAmount;
    }

    /**
     * [수정됨] PDF 첨부 대신 HTML 본문을 포함하여 이메일을 발송하는 메서드
     */
    public static void sendQuoteEmail(ServiceQuote__c quote, String htmlBody, String recipientEmail) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{ recipientEmail });
        email.setSubject('견적서 - ' + quote.OfferNo__c);

        List<OrgWideEmailAddress> orgWideEmails = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'jiaetak' LIMIT 1];
        // 발신자 설정 (Organization-Wide Email이 있으면 사용)
        if (!orgWideEmails.isEmpty()) {
            email.setOrgWideEmailAddressId(orgWideEmails[0].Id);
        } else {
            email.setSenderDisplayName('LSMtron 위험 분석 Agent');
        }

        // [수정] setPlainTextBody 대신 setHtmlBody 사용
        email.setHtmlBody(htmlBody);

        // 이메일 발송
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });
    }

    // --- Request/Response 내부 클래스는 기존과 동일 ---
    public class Request {
        @InvocableVariable(Label='로그인한 사용자 Id') public Id loginUserId;
        @InvocableVariable(Label='현재 MessagingSession의 Id') public Id messagingSessionId;
    }
    public class Response {
        @InvocableVariable(Label='응답 메시지') public String message;
        public Response(String message) { this.message = message; }
    }
}