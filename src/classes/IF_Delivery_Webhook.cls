@RestResource(urlMapping='/delivery/webhook')
global with sharing class IF_Delivery_Webhook {
    @HttpPost
    global static void getPost() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        // 받은 데이터 파싱 및 처리
        System.debug('Received Webhook: ' + body);
    }
}