/************************************************************************************
 * File Name        : im_GetRecentTrackings.cls
 * Author           : 최준석
 * Date             : 2025-05-27
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-05-27      최준석
*************************************************************************************/
public without sharing class im_GetRecentTrackings {
    /**
     * 최근 배송 기록을 조회하는 Invocable Method
     * @param requests 요청 파라미터 리스트
     * @return 최근 배송 기록 응답 리스트 (간략 정보)
     */
    @InvocableMethod(
            Label='최근 배송 기록 조회'
            Description='사용자의 최근 배송 기록 여러건을 간략하게 조회합니다'
            Category='배송 추적'
    )
    public static List<TrackingResponse> getRecentTrackings(List<TrackingRequest> requests) {
        System.debug('getRecentTrackingRecords ::: IN');
        System.debug('requests ::: ' + JSON.serializePretty(requests));
        List<TrackingResponse> responses = new List<TrackingResponse>();

        try {
            // 요청이 없는 경우 기본 처리
            TrackingRequest request = requests.isEmpty() ? new TrackingRequest() : requests[0];
            Integer recordLimit = request.recordLimit != null ? request.recordLimit : 10;
            Id loginUserId = request.userId;

            // 최근 배송 기록 조회 (생성일자 기준 내림차순) - 간략한 필드만
            List<Tracking__c> recentTrackings = [
                    SELECT Id, Tracking_Number__c, Status__r.DescriptionKor__c, Status__r.Status__c, Status__r.StatusKor__c
                            , fm_OrderDate__c, CreatedDate
                    FROM Tracking__c
                    WHERE OwnerId = :loginUserId
                    ORDER BY fm_OrderDate__c DESC
                    LIMIT :recordLimit
            ];

            System.debug('Found ' + recentTrackings.size() + ' recent tracking records');

            // 응답 생성
            TrackingResponse response = new TrackingResponse();
//            response.success = true;
            response.message = '최근 배송 기록 ' + recentTrackings.size() + '건을 조회했습니다.\n자세히 보려면 번호를 입력해주세요.';
//            response.totalCount = recentTrackings.size();
            response.trackingRecords = new List<TrackingSummary>();
//            response.responseText = '';

//            for (Tracking__c tracking : recentTrackings) {
//                String responseLine = '';
//                responseLine += count + '. ' + tracking.Tracking_Number__c;
//                responseLine += '[' + getDisplayStatus(tracking.Status__r?.StatusKor__c, tracking.Status__r?.Status__c) + ']';
//                responseLine += '(' + tracking.Last_Update__c != null ? tracking.Last_Update__c.format('MM/dd') : tracking.CreatedDate.format('MM/dd') + ')';
//                response.responseText += responseLine + '\n';
//                count++;
//            }

            Integer count = 1;
            for (Tracking__c obj : recentTrackings) {
                TrackingSummary summary = new TrackingSummary();
                summary.trackingId = obj.Id;
                summary.displayText = '';
                summary.displayText += count + '. ' + obj.Tracking_Number__c;
                summary.displayText += ' [' + getDisplayStatus(obj.Status__r?.StatusKor__c, obj.Status__r?.Status__c) + '] ';
                summary.displayText += obj.fm_OrderDate__c != null ? obj.fm_OrderDate__c.format('MM/dd') : obj.CreatedDate.format('MM/dd') + ' 발송';
                response.trackingRecords.add(summary);
            }

//            // 각 배송 기록을 간략한 정보로 변환
//            for (Tracking__c tracking : recentTrackings) {
//                TrackingSummary summary = new TrackingSummary();
//                summary.trackingId = tracking.Id;
//                summary.trackingNumber = tracking.Tracking_Number__c;
//                summary.displayStatus = getDisplayStatus(tracking.Status__r?.StatusKor__c, tracking.Status__r?.Status__c);
//                summary.lastUpdateDate = tracking.Last_Update__c != null ?
//                        tracking.Last_Update__c.format('MM/dd') :
//                        tracking.CreatedDate.format('MM/dd');
//
//                // Community Cloud 도메인 URL 가져오기 + 상세 페이지 패스 결합
////                String baseUrl = Site.getBaseUrl();
////                String detailPath = '/s/trackingstatus?c__trackingId=' + tracking.Id;
////                String fullUrl = baseUrl + detailPath;
////                String fullUrl = 'https://orgfarm-2bd4fdfcf2.my.site.com/support/s/trackingstatus?c__trackingId=' + tracking.Id;
//
//                // 송장번호만 클릭 가능한 링크로 생성 (나머지는 일반 텍스트)
////                String trackingNumberLink = '<a href="' + fullUrl + '" target="_self">' + tracking.Tracking_Number__c + '</a>';
//                summary.displayText = tracking.Tracking_Number__c + '[' + summary.displayStatus + '](' + summary.lastUpdateDate + ')';
//
//                response.trackingRecords.add(summary);
//            }

            responses.add(response);
            System.debug('responses ::: ' + JSON.serialize(responses));
            System.debug('getRecentTrackingRecords ::: OUT - Success');

        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());

            TrackingResponse errorResponse = new TrackingResponse();
//            errorResponse.success = false;
            errorResponse.message = '배송 기록 조회 중 오류가 발생했습니다: ' + e.getMessage();
//            errorResponse.totalCount = 0;
//            errorResponse.trackingRecords = new List<TrackingSummary>();

            responses.add(errorResponse);
        }

        return responses;
    }

    /**
     * 표시용 상태 메시지 생성
     */
    private static String getDisplayStatus(String koreanStatus, String englishStatus) {
        if (String.isNotBlank(koreanStatus)) {
            return koreanStatus;
        } else if (String.isNotBlank(englishStatus)) {
            // 영어 상태를 한글로 매핑
            Map<String, String> statusMap = new Map<String, String>{
                    'InfoReceived' => '정보접수',
                    'PickedUp' => '픽업완료',
                    'InTransit' => '운송중',
                    'OutForDelivery' => '배송중',
                    'Delivered' => '배송완료',
                    'Exception' => '배송예외',
                    'Returned' => '반송완료'
            };
            return statusMap.get(englishStatus) != null ? statusMap.get(englishStatus) : englishStatus;
        }
        return '확인중';
    }

    /**
     * 요청 파라미터 클래스
     */
    public class TrackingRequest {
        @InvocableVariable(Label='로그인 유저 Id' Description='현재 로그인한 사용자의 Id')
        public Id userId;
        @InvocableVariable(Label='조회할 레코드 수' Description='조회할 최근 배송 기록 수 (기본값: 10)')
        public Integer recordLimit;
    }

    /**
     * 응답 클래스
     */
    public class TrackingResponse {
//        @InvocableVariable(Label='성공 여부')
//        public Boolean success;

        @InvocableVariable(Label='응답 메시지')
        public String message;

//        @InvocableVariable(Label='총 레코드 수')
//        public Integer totalCount;
//
        @InvocableVariable(Label='배송 기록 요약 목록')
        public List<TrackingSummary> trackingRecords;

//        @InvocableVariable(Label='응답 결과')
//        public String responseText;
    }

    /**
     * 배송 정보 요약 클래스 (채팅용 간략 정보)
     */
    public class TrackingSummary {
        @InvocableVariable(Label='배송 ID')
        public Id trackingId;

//        @InvocableVariable(Label='송장번호')
//        public String trackingNumber;
//
//        @InvocableVariable(Label='상태')
//        public String displayStatus;
//
//        @InvocableVariable(Label='마지막 업데이트')
//        public String lastUpdateDate;

        @InvocableVariable(Label='채팅 표시용 링크 텍스트')
        public String displayText;
    }
}