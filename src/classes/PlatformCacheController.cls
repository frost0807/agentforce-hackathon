/**
 * Created by 최준석 on 2025-05-27.
 */

public without sharing class PlatformCacheController {
    @AuraEnabled
    /**
     * 현재 로그인한 사용자의 userId를 Session Cache에 저장하는 메소드
     */
    public static void saveLoginUserId() {
        Cache.Session.getPartition('local.AgentforceCache').put('userId', UserInfo.getUserId());
    }

    /**
     * 현재 로그인한 사용자의 userId를 Session Cache에서 가져오는 메소드
     */
    @AuraEnabled
    public static Id getLoginUserId() {
        return (Id) Cache.Session.getPartition('local.AgentforceCache').get('userId');
    }
}