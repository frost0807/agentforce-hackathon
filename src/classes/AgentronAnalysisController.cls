/************************************************************************************
* File Name   	    : AgentronAnalysisController
* Author	  		: Jiae.Tak
* Date				: 2025-05-30
* Tester	  		:
* Target	  		:
* Description 	    : 
* Modification Log
* ===================================================================================
* Ver      Date            Author          Modification
* ===================================================================================
* 1.0      2025-05-30         Jiae.Tak          Create
************************************************************************************/
public with sharing class AgentronAnalysisController {
    /**
     * CometD 인증용 Session ID 반환
     */
    @AuraEnabled(Cacheable=false)
    public static String getSessionId() {
        try {
            // Experience Cloud에서는 UserInfo.getSessionId()가 제한될 수 있음
            // 대안: Page Reference를 통한 Session ID 획득
            return UserInfo.getSessionId();

        } catch (Exception e) {
            System.debug('getSessionId 오류: ' + e.getMessage());

            // Session ID를 직접 가져올 수 없는 경우 대안
            // Experience Cloud에서는 다른 방법 필요할 수 있음
            throw new AuraHandledException('Session ID 획득 실패: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> getData() {

        Map<String, Object> mapReturn = new Map<String, Object>();

        Map<String, String> jsonData = new Map<String, String>();
        jsonData.put('error_alarm__c', 'a0MQy000000PG4nMAG');
        String jsonString = JSON.serialize(jsonData);

        PublishMessageController.publishMessage('Error_Report', jsonString);

        return mapReturn;
    }

    /**
     * lwc전환시마다 입력해 실시간 MessagingSession Update
     * */
    @AuraEnabled
    public static void saveComponentStatus(Id messagingSessionId, Id riskAnalyzeReportId, String type) {
        if (String.isNotBlank(messagingSessionId) && String.isNotBlank(type)) {
            MessagingSession objMessagingSession = new MessagingSession();
            objMessagingSession.Id = messagingSessionId;
            objMessagingSession.RiskAnalyzeReportId__c = riskAnalyzeReportId;
            objMessagingSession.ComponentType__c = type;

            update objMessagingSession;
        }
    }

    /**
     * @InvocableMethod에서 호출해서 실시간 MessagingSession 정보 조회
     * */
    public static MessagingSession getMessagingSession(Id messagingSessionId) {
        MessagingSession objMessagingSession;
        for (MessagingSession obj : [
                SELECT Id, RiskAnalyzeReportId__c, ComponentType__c, SalesforceUserID_Prechat__c, CurrentPageURL_Prechat__c
                FROM MessagingSession
                WHERE Id = :messagingSessionId
                LIMIT 1
        ]) {
            objMessagingSession = obj;
        }

        return objMessagingSession;
    }

    @AuraEnabled
    public static Id getRiskAnalyzeReportId(String uuid) {
        Id reportId;
        for (RiskAnalyzeReport__c obj : [SELECT Id FROM RiskAnalyzeReport__c WHERE UUID__c = :uuid]) {
            reportId = obj.Id;
        }
        return reportId;
    }
}