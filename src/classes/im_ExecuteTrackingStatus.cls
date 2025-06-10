/************************************************************************************
 * File Name        : im_ExecuteTrackingStatus.cls
 * Author           : 최준석
 * Date             : 2025-05-28
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-05-28      최준석
*************************************************************************************/

public without sharing class im_ExecuteTrackingStatus {
    @InvocableMethod(
            Label='배송 추적 컴포넌트 실행'
            Description='LWC 배송 추적 컴포넌트를 실행합니다.'
            Category='배송 추적'
    )
    public static List<Response> executeTrackingStatus(List<String> listTrackingNumber) {
        System.debug('executeTrackingStatus ::: IN');
        //LWC Spinner 활성화
        PublishMessageController.publishMessage('SHOW_SPINNER_NORMAL', '');
        System.debug('listTrackingId ::: ' + JSON.serialize(listTrackingNumber));

        Id trackingId;
        for (Tracking__c obj : [SELECT Id FROM Tracking__c WHERE Tracking_Number__c IN :listTrackingNumber]) {
            trackingId = obj.Id;
        }
//        String strJson = JSON.serializePretty(new MessageWrapper(trackingId));
        String strJson = JSON.serialize(new Map<String, Id>{
                'trackingId' => trackingId
        });
        System.debug('strJson : ' + strJson);
        //TrackingId 전달 + strJson
        PublishMessageController.publishMessage('TRACKING_STATUS', strJson);
        Response response = new Response();
        response.message = '해당 배송기록 출력했습니다.';

        //LWC Spinner 비활성화
        PublishMessageController.publishMessage('DISABLE_SPINNER_NORMAL', '');
        System.debug('executeTrackingStatus ::: OUT');

        return new List<im_ExecuteTrackingStatus.Response>{
                response
        };
    }

    public class MessageWrapper {
        Id trackingId;

        public MessageWrapper(Id trackingId) {
            this.trackingId = trackingId;
        }
    }

    public class Response {
        @InvocableVariable(Label='응답 메시지')
        public String message;
    }
}