/************************************************************************************
* File Name   	    : im_SelfCheck
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
public with sharing class im_SelfCheck {
    @InvocableMethod(
        Label='자가점검 리스트 컴포넌트 호출'
        Description='자가점검 리스트 컴포넌트를 실행합니다.'
        Category='자가점검 리스트'
    )
    public static List<Response> executeSelfCheckComponent(List<Request> requests){
        System.debug('executeSelfCheckComponent : ' );

        Request request = new Request();
        request.RiskAnalyzeReportId = '005Qy00000H3sXhIAJ';

        String strJson = JSON.serialize(request);
        PublishMessageController.publishMessage('SELF_CHECKLIST', strJson);
        Response response = new Response();
        response.message = '자가점검 컴포넌트를 출력합니다.';
        System.debug('자가점검 response : ' + response);
        return new List<Response>{ response };
    }

    public class Request {
        @InvocableVariable(Label='위험 분석 보고서 Id')
        public Id RiskAnalyzeReportId;
    }

    public class Response {
        @InvocableVariable(Label='응답 메시지')
        public String message;
    }
}