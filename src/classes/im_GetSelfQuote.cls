/************************************************************************************
 * File Name        : im_GetSelfQuote.cls
 * Author           : 최준석
 * Date             : 2025-06-05
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-06-05      최준석
*************************************************************************************/
public class im_GetSelfQuote {
//    @InvocableMethod(
//    Label='자가 견적 생성'
//    Description='선택한 부품을 기반으로 견적 미리보기를 보여줍니다.'
//    Category='견적'
//    )
//    public static List<Response> getSelfQuote(List<Request> listRequest) {
//        System.debug('getPartSelected ::: IN');
//        System.debug('listRequest ::: ' + JSON.serializePretty(listRequest));
//        Request objRequest;
//        for (Request obj : listRequest) {
//            objRequest = obj;
//        }
//        MessagingSession objMessagingSession = AgentronAnalysisController.getMessagingSession(objRequest.messagingSessionId);
//
//        PublishMessageController.publishMessage('SELF_QUOTE', JSON.serialize(objMessagingSession));
//
//        System.debug('getPartSelected ::: OUT');
//        return new List<Response>{
//                new Response('필요한 부품 리스트입니다.')
//        };
//    }
//
//    public class Request {
//        @InvocableVariable(Label='로그인한 사용자 Id')
//        public Id loginUserId;
//        @InvocableVariable(Label='현재 MessagingSession의 Id')
//        public Id messagingSessionId;
//        @InvocableVariable(Label='현재 Page의 URL')
//        public String currentPageUrl;
//    }
//
//    public class Response {
//        @InvocableVariable(Label='응답 메시지')
//        public String message;
//
//        public Response(String message) {
//            this.message = message;
//        }
//    }
}