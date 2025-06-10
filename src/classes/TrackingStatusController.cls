/************************************************************************************
* File Name : TrackingStatusController.cls
* Author : 최준석
* Date : 2025-05-26
* Description :
* Modification Log
* ===================================================================================
* Ver       Date        Author      Modification
* ===================================================================================
1.0         2025-05-26  최준석         Create
*************************************************************************************/
public with sharing class TrackingStatusController {
    /**
     * 배송 현황 정보를 조회하는 메소드
     * @param recordId 트래킹 레코드 ID
     * @return TrackingDisplayWrapper 배송현황 정보
     */
    @AuraEnabled(Cacheable=true)
    public static TrackingDisplayWrapper getTrackingInfo(Id recordId) {
        System.debug('getTrackingInfo ::: IN - ' + recordId);
        TrackingDisplayWrapper result = new TrackingDisplayWrapper();
        try {
            // 1. Tracking 메인 정보 조회
            Tracking__c objTracking;
            for (Tracking__c obj : [
                    SELECT Id, Tracking_Number__c, Carrier_Code__c, Tag__c, Order__c,
                            Status__c, Status__r.Status__c, Status__r.Name, Last_Update__c,
                            Destination_Country__c, Ship_From_Country__c,
                            Risk_Factor__c, Service_Type__c, Weight_Raw__c, Weight_Kg__c,
                            Pieces_Count__c, Dimensions__c, Customer_Number__c,
                            Reference_Number__c, Local_Number__c, Local_Provider__c,
                            Local_Key__c, Days_After_Order__c, Days_Of_Transit__c,
                            Days_Of_Transit_Done__c, Days_After_Last_Update__c,
                            Estimated_Delivery_Source__c, Estimated_Delivery_From__c,
                            Estimated_Delivery_To__c
                    FROM Tracking__c
                    WHERE Id = :recordId
                    LIMIT 1
            ]) {
                objTracking = obj;
            }

            if (objTracking == null) return new TrackingDisplayWrapper('배송정보를 찾을 수 없습니다.');

            // 2. Provider 정보 조회 (최신순)
            List<TrackingProvider__c> listProvider = [
                    SELECT Id, Provider_Key__c, Provider_Name__c, Alias__c,
                            Tel__c, Homepage__c, Country__c, Provider_Lang__c,
                            Service_Type__c, Latest_Sync_Status__c, Latest_Sync_Time__c,
                            Events_Hash__c
                    FROM TrackingProvider__c
                    WHERE Tracking__c = :objTracking.Id
                    ORDER BY Id DESC
            ];

            // 3. 모든 Provider의 Event 정보 조회 (시간순 정렬)
            List<TrackingProviderEvent__c> listProviderEvent = [
                    SELECT Id, TrackingProvider__c, TrackingProvider__r.Provider_Name__c,
                            Event_Time__c, Description__c, Description_Kor__c, Location__c, Stage__c,
                            Sub_Status__c, Sub_Status__r.Status__c, Sub_Status__r.Name,
                            Address__c, Provider_Sequence__c
                    FROM TrackingProviderEvent__c
                    WHERE TrackingProvider__r.Tracking__c = :objTracking.Id
                    ORDER BY Provider_Sequence__c DESC
            ];

            // 4. Milestone 정보 조회 및 Current Step 계산
            List<TrackingMilestone__c> listMilestone = [
                    SELECT Id, Key_Stage__c, Key_Stage_Kor__c, Time_ISO__c, Time_UTC__c, Description__c, Sequence__c
                    FROM TrackingMilestone__c
                    WHERE Tracking__c = :objTracking.Id
                    ORDER BY Sequence__c ASC
            ];

            // 현재 단계 계산 수정 - 완료된 가장 높은 단계를 찾기
            result.currentStep = 0; // 기본값을 0으로 설정

            // 완료된 마일스톤 중 가장 높은 sequence를 찾기
            Integer maxCompletedStep = 0;
            for (TrackingMilestone__c milestone : listMilestone) {
                if (milestone.Time_ISO__c != null && milestone.Sequence__c != null) {
                    maxCompletedStep = Math.max(maxCompletedStep, milestone.Sequence__c.intValue());
                }
            }

            if (maxCompletedStep > 0) {
                result.currentStep = maxCompletedStep;
            } else if (!listMilestone.isEmpty()) {
                // 완료된 마일스톤이 없으면 첫 번째 단계로 설정
                result.currentStep = 1;
            }

            // 5. Address 정보 조회
            List<TrackingAddress__c> listAddress = [
                    SELECT Id, Address_Type__c, Country__c, State__c, City__c,
                            Street__c, Postal_Code__c, Latitude__c, Longitude__c
                    FROM TrackingAddress__c
                    WHERE Tracking__c = :objTracking.Id
            ];

            // 6. orderDate, updateDate 계산
            result.orderDate = formatDate(System.today().addDays(objTracking.Days_After_Order__c != null ? -objTracking.Days_After_Order__c.intValue() : 0));
            result.updateDate = formatDateTime(objTracking.Last_Update__c);

            // 7. 결과 래퍼 생성
            result.success = true;
            result.objTracking = objTracking;
            result.listProvider = listProvider;
            result.listProviderEvent = listProviderEvent;
            result.listMileStone = listMilestone;
            result.listAddress = listAddress;

            System.debug('getTrackingInfo ::: OUT - Success');
        } catch (DmlException e) {
            handleException('DML ERROR LINE:' + e.getLineNumber() + '\n' + e.getMessage(), e.getMessage());
        } catch (Exception e) {
            handleException('ERROR LINE:' + e.getLineNumber() + '\n' + e.getMessage(), e.getMessage());
        }

        return result;
    }

    /**
     * Date 포맷팅 유틸리티 메소드
     * @param dateValue 포맷할 Date 객체
     * @return YYYY-MM-DD 형식의 문자열
     */
    private static String formatDate(Date dateValue) {
        if (dateValue == null) return '정보없음';

        return dateValue.year() + '-' +
                String.valueOf(dateValue.month()).leftPad(2, '0') + '-' +
                String.valueOf(dateValue.day()).leftPad(2, '0');
    }

    /**
     * DateTime 포맷팅 유틸리티 메소드
     * @param dateTimeValue 포맷할 DateTime 객체
     * @return YYYY-MM-DD HH:MM:SS 형식의 문자열
     */
    private static String formatDateTime(Datetime dateTimeValue) {
        if (dateTimeValue == null) return '정보없음';

        return dateTimeValue.year() + '-' +
                String.valueOf(dateTimeValue.month()).leftPad(2, '0') + '-' +
                String.valueOf(dateTimeValue.day()).leftPad(2, '0') + ' ' +
                String.valueOf(dateTimeValue.hour()).leftPad(2, '0') + ':' +
                String.valueOf(dateTimeValue.minute()).leftPad(2, '0') + ':' +
                String.valueOf(dateTimeValue.second()).leftPad(2, '0');
    }

    /**
     * 배송현황 정보를 담는 Wrapper 클래스
     */
    public class TrackingDisplayWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Tracking__c objTracking;
        @AuraEnabled public List<TrackingProvider__c> listProvider;
        @AuraEnabled public List<TrackingProviderEvent__c> listProviderEvent;
        @AuraEnabled public List<TrackingMilestone__c> listMileStone;
        @AuraEnabled public List<TrackingAddress__c> listAddress;
        @AuraEnabled public Integer currentStep;
        @AuraEnabled public String orderDate;
        @AuraEnabled public String updateDate;

        public TrackingDisplayWrapper() {
            this.success = false;
            this.currentStep = 1; // 기본값을 1로 변경
        }

        public TrackingDisplayWrapper(String errorMessage) {
            this();
            this.errorMessage = errorMessage;
        }
    }

    private static void handleException(String logMessage, String exceptionMessage) {
        System.debug(logMessage);
        throw new TrackingStatusControllerException(exceptionMessage);
    }

    private static void handleException(String logMessage, String exceptionMessage, SavePoint sp) {
        System.debug(logMessage);
        Database.rollback(sp);
        throw new TrackingStatusControllerException(exceptionMessage);
    }

    public class TrackingStatusControllerException extends Exception {
    }
}