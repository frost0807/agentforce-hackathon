/************************************************************************************
 * File Name        : im_GetPartSelected.cls
 * Author           : 최준석
 * Date             : 2025-06-04
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-06-04      최준석
*************************************************************************************/
public class im_GetPartSelected {
    @InvocableMethod(
            Label='필요 부품 호출'
            Description='사용자가 필요로 하는 부품을 표시합니다.'
            Category='부품 선택'
    )
    public static List<Response> getPartSelected(List<Request> listRequest) {
        System.debug('getPartSelected ::: IN');
        System.debug('listRequest ::: ' + JSON.serializePretty(listRequest));
        Request objRequest;
        for (Request obj : listRequest) {
            objRequest = obj;
        }
        //스피너 활성화
        PublishMessageController.publishMessage('SHOW_SPINNER', '');
        DN_IFUtil.waitForSeconds(3);
        //스피너 비활성화
        PublishMessageController.publishMessage('DISABLE_SPINNER', '');

        MessagingSession objMessagingSession = AgentronAnalysisController.getMessagingSession(objRequest.messagingSessionId);

        PublishMessageController.publishMessage('PART_SELECT', JSON.serialize(objMessagingSession));



        System.debug('getPartSelected ::: OUT');
        return new List<Response>{
                new Response('필요한 부품 리스트입니다.')
        };
    }

    public class Request {
        @InvocableVariable(Label='로그인한 사용자 Id')
        public Id loginUserId;
        @InvocableVariable(Label='현재 MessagingSession의 Id')
        public Id messagingSessionId;
        @InvocableVariable(Label='현재 Page의 URL')
        public String currentPageUrl;
    }

    public class Response {
        @InvocableVariable(Label='응답 메시지')
        public String message;

        public Response(String message) {
            this.message = message;
        }
    }
}