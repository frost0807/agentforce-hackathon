/************************************************************************************
 * File Name : PublishMessageController.cls
 * Author : 최준석
 * Date : 2025-06-04
 * Description :
 * Modification Log
 * ===================================================================================
 * Ver      Date        Author      Modification
 * ===================================================================================
 * 1.0      2025-06-04  최준석         Create
 *************************************************************************************/
public with sharing class PublishMessageController {
    public static void publishMessage(String channelName, String jsonString) {
        System.debug('publishMessage ::: IN');
        AgentronEvent__e agentronEvent = new AgentronEvent__e(
                ChannelName__c = channelName,
                JsonString__c = jsonString
        );
        System.debug('agentronEvent ::: ' + JSON.serializePretty(agentronEvent));

        // 플랫폼 이벤트 발행
        Database.SaveResult sr = EventBus.publish(agentronEvent);
        System.debug('sr : ' + JSON.serializePretty(sr));
        System.debug('publishMessage ::: OUT');
    }
}