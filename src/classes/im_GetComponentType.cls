/************************************************************************************
 * File Name        : im_GetComponentType.cls
 * Author           : 최준석
 * Date             : 2025-06-05
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-06-05      최준석
*************************************************************************************/
public with sharing class im_GetComponentType {
    @InvocableMethod(
            Label='LWC 컴포넌트 타입 호출'
            Description='현재 화면에 렌더링된 LWC 컴포넌트의 타입을 호출합니다.'
            Category='LWC 컴포넌트 타입'
    )
    public static List<Response> getComponentType(List<Request> listRequest) {
        Request objRequest;
        for (Request obj : listRequest) {
            objRequest = obj;
        }

        Response objResponse = new Response();
        for (MessagingSession obj : [SELECT Id, ComponentType__c FROM MessagingSession WHERE Id = :objRequest.messagingSessionId]) {
            objResponse.componentType = obj.ComponentType__c;
        }

        return new List<im_GetComponentType.Response>{
                objResponse
        };
    }

    public class Request {
        @InvocableVariable(Label='현재 MessagingSession의 Id')
        public Id messagingSessionId;
    }

    public class Response {
        @InvocableVariable(Label='현재 렌더링된 LWC 컴포넌트 타입')
        public String componentType;
    }
}