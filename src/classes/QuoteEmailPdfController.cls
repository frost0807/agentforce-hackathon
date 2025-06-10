/**
 * Created by 최준석 on 2025-06-09.
 */

public with sharing class QuoteEmailPdfController {
    private final ServiceQuote__c quote;

    // StandardController에서 ServiceQuote__c 레코드를 받아옵니다.
    public QuoteEmailPdfController(ApexPages.StandardController stdController) {
        this.quote = (ServiceQuote__c)stdController.getRecord();
    }

    // 견적 항목(Line Items)을 조회하여 페이지로 전달하는 getter 메서드
    public List<ServiceQuoteLineItem__c> getLineItems() {
        return [SELECT Id, ProductId__r.Name, Quantity__c, UnitPrice__c
        FROM ServiceQuoteLineItem__c
        WHERE ServiceQuote__c = :quote.Id
        ORDER BY CreatedDate ASC];
    }
}