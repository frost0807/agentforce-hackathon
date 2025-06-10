/************************************************************************************
* File Name : TrackingController.cls
* Author : 최준석
* Date : 2025-05-25
* Description :
* Modification Log
* ===================================================================================
* Ver       Date        Author      Modification
* ===================================================================================
1.0         2025-05-25  최준석         Create
*************************************************************************************/
public with sharing class TrackingController {

    // 단계(Stage) 영어 → 한글 번역 테이블
    private static final Map<String, String> STAGE_KOR_MAP = new Map<String, String>{
            // 일반 단계
            'InfoReceived' => '정보접수',
            'PickedUp' => '픽업완료',
            'Departure' => '출발',
            'Arrival' => '도착',
            'AvailableForPickup' => '픽업가능',
            'OutForDelivery' => '배송중',
            'Delivered' => '배송완료',
            'Returning' => '반송중',
            'Returned' => '반송완료',

            // 세부 단계
            'InTransit' => '운송중',
            'Exception' => '예외상황',
            'Pending' => '대기중',
            'Processing' => '처리중',
            'CustomsClearing' => '통관중',
            'WaitingForPickup' => '픽업대기',
            'AttemptFail' => '배송실패',
            'Expired' => '기한만료',

            // 기타 상태
            'Created' => '생성됨',
            'Accepted' => '접수됨',
            'Rejected' => '거부됨',
            'Cancelled' => '취소됨'
    };

    // 이벤트 설명 → 마일스톤 매핑 테이블
    private static final Map<String, String> EVENT_TO_MILESTONE_MAP = new Map<String, String>{
            // InfoReceived 관련
            'Information Received' => 'InfoReceived',
            'Shipment information received' => 'InfoReceived',
            'Order information received' => 'InfoReceived',

            // PickedUp 관련
            'Picked up' => 'PickedUp',
            'Collection' => 'PickedUp',
            'Origin pickup' => 'PickedUp',
            'Shipment picked up' => 'PickedUp',

            // Departure 관련
            'Departed' => 'Departure',
            'Origin departure' => 'Departure',
            'Left origin country' => 'Departure',
            'Origin Onboard' => 'Departure',
            'Departure from origin' => 'Departure',

            // Arrival 관련
            'Arrived' => 'Arrival',
            'Destination arrival' => 'Arrival',
            'Destination Arrival' => 'Arrival',
            'Arrived at destination country' => 'Arrival',
            'Import scan' => 'Arrival',

            // AvailableForPickup 관련
            'Available for pickup' => 'AvailableForPickup',
            'Ready for pickup' => 'AvailableForPickup',
            'Arrival at pickup point' => 'AvailableForPickup',

            // OutForDelivery 관련
            'Out for delivery' => 'OutForDelivery',
            'Destination Out for delivery' => 'OutForDelivery',
            'On vehicle for delivery' => 'OutForDelivery',
            'Out for final delivery' => 'OutForDelivery',

            // Delivered 관련
            'Delivered' => 'Delivered',
            'Destination Delivery' => 'Delivered',
            'Successfully delivered' => 'Delivered',
            'Package delivered' => 'Delivered',
            'Delivery completed' => 'Delivered',

            // Returning 관련
            'Return to sender' => 'Returning',
            'Returning' => 'Returning',
            'Return initiated' => 'Returning',

            // Returned 관련
            'Returned to sender' => 'Returned',
            'Return completed' => 'Returned',
            'Returned' => 'Returned'
    };

    // 이벤트 설명 영어 → 한글 번역 테이블
    private static final Map<String, String> EVENT_DESCRIPTION_KOR_MAP = new Map<String, String>{
            // 배송 완료 관련
            'Destination Delivery' => '목적지 배송 완료',
            'Delivered' => '배송 완료',
            'Successfully delivered' => '배송 성공',
            'Package delivered' => '상품 배송 완료',
            'Delivery completed' => '배송 완료',

            // 배송 중 관련
            'Destination Out for delivery' => '목적지 배송 출발',
            'Out for delivery' => '배송 출발',
            'On vehicle for delivery' => '배송 차량 탑재',
            'Out for final delivery' => '최종 배송 출발',

            // 통관 관련
            'Destination Customs Clearance' => '목적지 통관 처리',
            'Customs clearance' => '통관 처리',
            'Import scan' => '수입 검사',

            // 도착 관련
            'Destination Arrival' => '목적지 도착',
            'Arrived' => '도착',
            'Arrived at destination country' => '목적지 국가 도착',
            'Arrival at pickup point' => '픽업 지점 도착',

            // 출발 관련
            'Origin Onboard' => '출발지 상차',
            'Departed' => '출발',
            'Origin departure' => '출발지 출발',
            'Left origin country' => '출발지 국가 출발',
            'Departure from origin' => '출발지에서 출발',

            // 픽업 관련
            'Picked up' => '픽업 완료',
            'Collection' => '수거 완료',
            'Origin pickup' => '출발지 픽업',
            'Shipment picked up' => '화물 픽업 완료',

            // 정보 접수 관련
            'Information Received' => '정보 접수',
            'Shipment information received' => '배송 정보 접수',
            'Order information received' => '주문 정보 접수',

            // 픽업 가능 관련
            'Available for pickup' => '픽업 가능',
            'Ready for pickup' => '픽업 준비 완료',

            // 반송 관련
            'Return to sender' => '발송인 반송',
            'Returning' => '반송 중',
            'Return initiated' => '반송 시작',
            'Returned to sender' => '발송인에게 반송 완료',
            'Return completed' => '반송 완료',
            'Returned' => '반송됨'
    };

    /**
     * @param trackingNumber  송장번호
     * @return                처리된 Tracking__c Id
     */
    public static Id upsertTracking(String trackingNumber) {
        System.debug('upsertTracking ::: IN - ' + trackingNumber);
        Id trackingId;

        /**
         * 1. 배송추적 API 생성 확인 및 생성
         */
        if (!isTrackingCreated(trackingNumber)) {
            IF_17TrackApiController.TrackingRequest trackingRequest = new IF_17TrackApiController.TrackingRequest(trackingNumber);
            IF_17TrackApiController.TrackingResponse trackingResponse = IF_17TrackApiController.createTracking(trackingRequest);
            Integer responseCode = trackingResponse.respCode;
            //0은 성공, -18019901은 이미 등록된 경우
            if (responseCode != 0 && responseCode != -18019901) {
                handleException('trackingResponse ::: ' + JSON.serializePretty(trackingResponse), getErrorDescriptionByCode(responseCode));
            }
        }

        /**
         * 2. 조회 API 호출
         */
        IF_17TrackApiController.TrackingRequest trackingRequest = new IF_17TrackApiController.TrackingRequest(trackingNumber);
        IF_17TrackApiController.TrackingResponse trackingResponse = IF_17TrackApiController.getTrackingInfo(trackingRequest);

        if (trackingResponse?.respData == null || trackingResponse.respData.accepted.isEmpty()) {
            handleException('trackingResponse ::: ' + JSON.serializePretty(trackingResponse), '배송추적 기록이 존재하지 않습니다.');
        }

        IF_17TrackApiController.TrackingAcceptedWrapper accepted = trackingResponse.respData.accepted.get(0);

        // Status 매핑 준비
        Map<String, Id> mapShippingStatusToId = new Map<String, Id>();
        for (SeventeenTrackShippingStatus__c obj : [SELECT Id, Status__c FROM SeventeenTrackShippingStatus__c]) {
            if (String.isNotBlank(obj.Status__c)) mapShippingStatusToId.put(obj.Status__c, obj.Id);
        }

        Savepoint sp = Database.setSavepoint();

        try {
            /**
             * 3. Tracking__c UPSERT (마스터 정보)
             */
            Tracking__c objTracking = new Tracking__c();
            objTracking.Tracking_Number__c = accepted.trackNumber;
            objTracking.Carrier_Code__c = accepted.carrierCode;
            objTracking.Tag__c = accepted.userTag;
//            objTracking.Order__c = accepted.orderId;
            objTracking.Status__c = mapShippingStatusToId.get(accepted.trackInfoDetail?.latestStatus?.statusMain);
            objTracking.Last_Update__c = DN_IFUtil.parseIso8601WithOffset(accepted.trackInfoDetail?.latestEvent?.eventTimeIso);
            objTracking.Destination_Country__c = accepted.destCountryCode;
            objTracking.Ship_From_Country__c = accepted.shipFromCountryCode;

            // MiscInfo 정보 설정
            if (accepted.trackInfoDetail?.miscInfo != null) {
                objTracking.Risk_Factor__c = accepted.trackInfoDetail.miscInfo.riskFactor;
                objTracking.Service_Type__c = accepted.trackInfoDetail.miscInfo.serviceType;
                objTracking.Weight_Raw__c = accepted.trackInfoDetail.miscInfo.weightRaw;
                objTracking.Weight_Kg__c = accepted.trackInfoDetail.miscInfo.weightKg;
                objTracking.Pieces_Count__c = accepted.trackInfoDetail.miscInfo.piecesCount;
                objTracking.Dimensions__c = accepted.trackInfoDetail.miscInfo.dimensionsRaw;
                objTracking.Customer_Number__c = accepted.trackInfoDetail.miscInfo.customerNum;
                objTracking.Reference_Number__c = accepted.trackInfoDetail.miscInfo.referenceNum;
                objTracking.Local_Number__c = accepted.trackInfoDetail.miscInfo.localNum;
                objTracking.Local_Provider__c = accepted.trackInfoDetail.miscInfo.localProviderName;
                objTracking.Local_Key__c = accepted.trackInfoDetail.miscInfo.localKeyId;
            }

            // TimeMetrics 정보 설정
            if (accepted.trackInfoDetail?.timeMetrics != null) {
                objTracking.Days_After_Order__c = accepted.trackInfoDetail.timeMetrics.daysAfterOrder;
                objTracking.Days_Of_Transit__c = accepted.trackInfoDetail.timeMetrics.daysOfTransit;
                objTracking.Days_Of_Transit_Done__c = accepted.trackInfoDetail.timeMetrics.daysOfTransitDone;
                objTracking.Days_After_Last_Update__c = accepted.trackInfoDetail.timeMetrics.daysAfterLastUpdate;

                if (accepted.trackInfoDetail.timeMetrics.estimatedDelivery != null) {
                    objTracking.Estimated_Delivery_Source__c = accepted.trackInfoDetail.timeMetrics.estimatedDelivery.sourceType;
                    objTracking.Estimated_Delivery_From__c = DN_IFUtil.parseIso8601WithOffset(accepted.trackInfoDetail.timeMetrics.estimatedDelivery.fromDate);
                    objTracking.Estimated_Delivery_To__c = DN_IFUtil.parseIso8601WithOffset(accepted.trackInfoDetail.timeMetrics.estimatedDelivery.toDate);
                }
            }

            upsert objTracking Tracking_Number__c;
            trackingId = objTracking.Id;

            /**
             * 4. 운송사(TrackingProvider__c) 처리
             */
            List<TrackingProvider__c> listProvider = new List<TrackingProvider__c>();
            List<IF_17TrackApiController.TrackingProviderInfoWrapper> listTrackingProvider = accepted.trackInfoDetail?.tracking?.providers;

            if (listTrackingProvider != null) {
                Integer providerSequence = listTrackingProvider.size();

                for (IF_17TrackApiController.TrackingProviderInfoWrapper providerWrapper : listTrackingProvider) {
                    TrackingProvider__c objProvider = new TrackingProvider__c();
                    objProvider.Tracking__c = trackingId;

                    // 기본 운송사 정보
                    if (providerWrapper.providerDetail != null) {
                        objProvider.Provider_Key__c = providerWrapper.providerDetail.providerKey;
                        objProvider.Provider_Name__c = providerWrapper.providerDetail.providerName;
                        objProvider.Alias__c = providerWrapper.providerDetail.providerAlias;
                        objProvider.Tel__c = providerWrapper.providerDetail.providerTel;
                        objProvider.Homepage__c = providerWrapper.providerDetail.providerHomepage;
                        objProvider.Country__c = providerWrapper.providerDetail.providerCountry;
                    }

                    // 추가 운송사 정보
                    objProvider.Provider_Lang__c = providerWrapper.providerLang;
                    objProvider.Service_Type__c = providerWrapper.serviceType;
                    objProvider.Latest_Sync_Status__c = providerWrapper.latestSyncStatus;
                    objProvider.Latest_Sync_Time__c = DN_IFUtil.parseIso8601Z(providerWrapper.latestSyncTime);
                    objProvider.Events_Hash__c = providerWrapper.eventsHash;
                    objProvider.ExternalId__c = objTracking.Tracking_Number__c + '_PROVIDER_' + providerSequence;

                    listProvider.add(objProvider);
                    providerSequence--;
                }
            }

            // 운송사들 먼저 upsert (이벤트가 참조할 수 있도록)
            if (!listProvider.isEmpty()) {
                upsert listProvider ExternalId__c;
                System.debug('Providers upserted: ' + listProvider.size());
            }

            /**
             * 5. 운송사별 이벤트(TrackingProviderEvent__c) 처리
             */
            List<TrackingProviderEvent__c> listProviderEvent = new List<TrackingProviderEvent__c>();
            List<IF_17TrackApiController.TrackEventWrapper> allEvents = new List<IF_17TrackApiController.TrackEventWrapper>();

            if (listTrackingProvider != null && !listProvider.isEmpty()) {
                // Provider ExternalId → Id 매핑 생성
                Map<String, Id> providerExternalIdToId = new Map<String, Id>();
                for (TrackingProvider__c provider : listProvider) {
                    providerExternalIdToId.put(provider.ExternalId__c, provider.Id);
                }

                Integer providerIndex = listTrackingProvider.size();
                for (IF_17TrackApiController.TrackingProviderInfoWrapper providerWrapper : listTrackingProvider) {
                    // 이 운송사의 이벤트가 없으면 스킵
                    if (providerWrapper.providerEvents == null || providerWrapper.providerEvents.isEmpty()) {
                        providerIndex--;
                        continue;
                    }

                    // 운송사 ID 찾기
                    String providerExternalId = objTracking.Tracking_Number__c + '_PROVIDER_' + providerIndex;
                    Id providerId = providerExternalIdToId.get(providerExternalId);

                    if (providerId == null) {
                        System.debug('Provider ID not found for: ' + providerExternalId);
                        providerIndex--;
                        continue;
                    }

                    // 이 운송사의 모든 이벤트 처리
                    Integer providerSequence = providerWrapper.providerEvents.size(); // 역순 정렬용

                    for (IF_17TrackApiController.TrackEventWrapper eventWrapper : providerWrapper.providerEvents) {
                        TrackingProviderEvent__c objEvent = new TrackingProviderEvent__c();
                        objEvent.TrackingProvider__c = providerId; //운송사 연결
                        objEvent.Event_Time__c = DN_IFUtil.parseIso8601WithOffset(eventWrapper.eventTimeIso);
                        objEvent.Description__c = eventWrapper.eventDesc;

                        // Description을 한글로 번역해서 Description_Kor__c에 저장
                        objEvent.Description_Kor__c = translateEventDescription(eventWrapper.eventDesc);

                        objEvent.Location__c = eventWrapper.eventLocation;
                        objEvent.Stage__c = eventWrapper.eventStage;
                        objEvent.Sub_Status__c = mapShippingStatusToId.get(eventWrapper.eventSubStatus);
                        objEvent.Address__c = JSON.serialize(eventWrapper.eventAddress);
                        objEvent.Provider_Sequence__c = providerSequence; // 운송사 내 순서
                        objEvent.ExternalId__c = objTracking.Tracking_Number__c + '_P' + providerIndex + '_E' + providerSequence;

                        listProviderEvent.add(objEvent);

                        // 마일스톤 매핑을 위해 모든 이벤트 수집
                        allEvents.add(eventWrapper);

                        providerSequence--; // 최신 이벤트가 높은 번호
                    }

                    providerIndex--;
                }
            }

            /**
             * 6. 커스텀 마일스톤(TrackingMilestone__c) 처리 - 이벤트 기반 매핑
             */
            List<TrackingMilestone__c> listMilestone = createCustomMilestones(trackingId, objTracking.Tracking_Number__c, allEvents);

            /**
             * 7. 주소정보(TrackingAddress__c) 처리
             */
            List<TrackingAddress__c> listAddress = new List<TrackingAddress__c>();

            if (accepted.trackInfoDetail?.shippingInfo != null) {
                // 송하인 주소
                IF_17TrackApiController.AddressWrapper shipperAddress = accepted.trackInfoDetail.shippingInfo.shipperAddress;
                if (shipperAddress != null) {
                    TrackingAddress__c objAddress = new TrackingAddress__c();
                    objAddress.Tracking__c = trackingId;
                    objAddress.Address_Type__c = 'SHIPPER';
                    objAddress.Country__c = shipperAddress.country;
                    objAddress.State__c = shipperAddress.stateRegion;
                    objAddress.City__c = shipperAddress.cityName;
                    objAddress.Street__c = shipperAddress.streetName;
                    objAddress.Postal_Code__c = shipperAddress.postalCode;
                    objAddress.Latitude__c = shipperAddress.coordinates?.latitude;
                    objAddress.Longitude__c = shipperAddress.coordinates?.longitude;
                    objAddress.ExternalId__c = objTracking.Tracking_Number__c + '_SHIPPER';
                    listAddress.add(objAddress);
                }

                // 수하인 주소
                IF_17TrackApiController.AddressWrapper recipientAddress = accepted.trackInfoDetail.shippingInfo.recipientAddress;
                if (recipientAddress != null) {
                    TrackingAddress__c objAddress = new TrackingAddress__c();
                    objAddress.Tracking__c = trackingId;
                    objAddress.Address_Type__c = 'RECIPIENT';
                    objAddress.Country__c = recipientAddress.country;
                    objAddress.State__c = recipientAddress.stateRegion;
                    objAddress.City__c = recipientAddress.cityName;
                    objAddress.Street__c = recipientAddress.streetName;
                    objAddress.Postal_Code__c = recipientAddress.postalCode;
                    objAddress.Latitude__c = recipientAddress.coordinates?.latitude;
                    objAddress.Longitude__c = recipientAddress.coordinates?.longitude;
                    objAddress.ExternalId__c = objTracking.Tracking_Number__c + '_RECIPIENT';
                    listAddress.add(objAddress);
                }
            }

            /**
             * 8. 모든 하위 객체들 저장
             */
            if (!listProviderEvent.isEmpty()) upsert listProviderEvent ExternalId__c;
            if (!listMilestone.isEmpty()) upsert listMilestone ExternalId__c;
            if (!listAddress.isEmpty()) upsert listAddress ExternalId__c;

            // 최종 결과 로그
            System.debug('=== 동기화 완료 ===');
            System.debug('Providers: ' + listProvider.size());
            System.debug('Provider Events: ' + listProviderEvent.size());
            System.debug('Custom Milestones: ' + listMilestone.size());
            System.debug('Addresses: ' + listAddress.size());

        } catch (DmlException e) {
            handleException('DML ERROR LINE:' + e.getLineNumber() + '\n' + e.getMessage(), e.getMessage(), sp);
        } catch (Exception e) {
            handleException('ERROR LINE:' + e.getLineNumber() + '\n' + e.getMessage(), e.getMessage(), sp);
        }

        System.debug('upsertTracking ::: OUT');
        return trackingId;
    }

    /**
     * 이벤트 기반 커스텀 마일스톤 생성
     */
    private static List<TrackingMilestone__c> createCustomMilestones(Id trackingId, String trackingNumber, List<IF_17TrackApiController.TrackEventWrapper> allEvents) {
        System.debug('createCustomMilestones ::: IN');

        // 마일스톤 순서 정의 (Metadata에서 가져오기)
        Map<String, String> mapMilestoneEngToKor = new Map<String, String>();
        Map<String, Integer> mapMilestoneToSequence = new Map<String, Integer>();
        List<String> orderedMilestones = new List<String>();

        for (MileStone__mdt obj : [SELECT DeveloperName, KeyStageKor__c, Sequence__c FROM MileStone__mdt ORDER BY Sequence__c ASC]) {
            mapMilestoneEngToKor.put(obj.DeveloperName, obj.KeyStageKor__c);
            mapMilestoneToSequence.put(obj.DeveloperName, obj.Sequence__c.intValue());
            orderedMilestones.add(obj.DeveloperName);
        }

        // 이벤트에서 마일스톤 매핑 정보 추출
        Map<String, DateTime> milestoneCompletedTimes = new Map<String, DateTime>();

        for (IF_17TrackApiController.TrackEventWrapper eventWrapper : allEvents) {
            String eventDesc = eventWrapper.eventDesc;
            String mappedMilestone = mapEventToMilestone(eventDesc);

            if (String.isNotBlank(mappedMilestone) && mapMilestoneEngToKor.containsKey(mappedMilestone)) {
                DateTime eventTime = DN_IFUtil.parseIso8601WithOffset(eventWrapper.eventTimeIso);

                // 같은 마일스톤에 여러 이벤트가 있을 경우, 가장 이른 시간을 사용
                if (!milestoneCompletedTimes.containsKey(mappedMilestone) ||
                        (eventTime != null && eventTime < milestoneCompletedTimes.get(mappedMilestone))) {
                    milestoneCompletedTimes.put(mappedMilestone, eventTime);
                }

                System.debug('Event mapped: ' + eventDesc + ' -> ' + mappedMilestone + ' at ' + eventTime);
            }
        }

        // 커스텀 마일스톤 생성
        List<TrackingMilestone__c> listMilestone = new List<TrackingMilestone__c>();

        for (String milestoneKey : orderedMilestones) {
            TrackingMilestone__c objMilestone = new TrackingMilestone__c();
            objMilestone.Tracking__c = trackingId;
            objMilestone.Key_Stage__c = milestoneKey;
            objMilestone.Key_Stage_Kor__c = mapMilestoneEngToKor.get(milestoneKey);
            objMilestone.Sequence__c = mapMilestoneToSequence.get(milestoneKey);
            objMilestone.ExternalId__c = trackingNumber + '_MILESTONE_' + mapMilestoneToSequence.get(milestoneKey);

            // 해당 마일스톤이 완료되었다면 시간 설정
            if (milestoneCompletedTimes.containsKey(milestoneKey)) {
                DateTime completedTime = milestoneCompletedTimes.get(milestoneKey);
                objMilestone.Time_ISO__c = completedTime;
                objMilestone.Time_UTC__c = completedTime;
                objMilestone.Description__c = milestoneKey + ' completed';
            } else {
                objMilestone.Time_ISO__c = null;
                objMilestone.Time_UTC__c = null;
                objMilestone.Description__c = milestoneKey + ' pending';
            }

            listMilestone.add(objMilestone);
        }

        System.debug('createCustomMilestones ::: OUT - Created ' + listMilestone.size() + ' milestones');
        return listMilestone;
    }

    /**
     * 이벤트 설명을 마일스톤으로 매핑
     */
    private static String mapEventToMilestone(String eventDescription) {
        if (String.isBlank(eventDescription)) return null;

        // 정확한 매치 시도
        if (EVENT_TO_MILESTONE_MAP.containsKey(eventDescription)) {
            return EVENT_TO_MILESTONE_MAP.get(eventDescription);
        }

        // 부분 매치 시도 (소문자 변환 후 포함 관계 확인)
        String lowerEventDesc = eventDescription.toLowerCase();

        for (String key : EVENT_TO_MILESTONE_MAP.keySet()) {
            if (lowerEventDesc.contains(key.toLowerCase()) || key.toLowerCase().contains(lowerEventDesc)) {
                return EVENT_TO_MILESTONE_MAP.get(key);
            }
        }

        // 키워드 기반 매핑
        if (lowerEventDesc.contains('information') || lowerEventDesc.contains('received') || lowerEventDesc.contains('created')) {
            return 'InfoReceived';
        } else if (lowerEventDesc.contains('picked') || lowerEventDesc.contains('pickup') || lowerEventDesc.contains('collection')) {
            return 'PickedUp';
        } else if (lowerEventDesc.contains('departed') || lowerEventDesc.contains('departure') || lowerEventDesc.contains('onboard')) {
            return 'Departure';
        } else if (lowerEventDesc.contains('arrived') || lowerEventDesc.contains('arrival') || lowerEventDesc.contains('import')) {
            return 'Arrival';
        } else if (lowerEventDesc.contains('available') || lowerEventDesc.contains('ready')) {
            return 'AvailableForPickup';
        } else if (lowerEventDesc.contains('out for delivery') || lowerEventDesc.contains('vehicle for delivery')) {
            return 'OutForDelivery';
        } else if (lowerEventDesc.contains('delivered') || lowerEventDesc.contains('delivery')) {
            return 'Delivered';
        } else if (lowerEventDesc.contains('return') && !lowerEventDesc.contains('returned')) {
            return 'Returning';
        } else if (lowerEventDesc.contains('returned')) {
            return 'Returned';
        }

        return null;
    }

    /**
     * Stage를 한글로 번역
     */
    private static String translateStage(String originalStage) {
        if (String.isBlank(originalStage)) return '';

        // 정확한 매치 시도
        if (STAGE_KOR_MAP.containsKey(originalStage)) {
            return STAGE_KOR_MAP.get(originalStage);
        }

        // 부분 매치 시도
        String lowerStage = originalStage.toLowerCase();
        for (String key : STAGE_KOR_MAP.keySet()) {
            if (lowerStage.equals(key.toLowerCase())) {
                return STAGE_KOR_MAP.get(key);
            }
        }

        // 키워드 기반 번역 (fallback)
        if (lowerStage.contains('info') || lowerStage.contains('received')) {
            return '정보접수';
        } else if (lowerStage.contains('pickup') || lowerStage.contains('picked')) {
            return '픽업완료';
        } else if (lowerStage.contains('departure') || lowerStage.contains('depart')) {
            return '출발';
        } else if (lowerStage.contains('arrival') || lowerStage.contains('arrive')) {
            return '도착';
        } else if (lowerStage.contains('delivery') && lowerStage.contains('out')) {
            return '배송중';
        } else if (lowerStage.contains('delivered') || lowerStage.contains('delivery')) {
            return '배송완료';
        } else if (lowerStage.contains('transit')) {
            return '운송중';
        } else if (lowerStage.contains('customs')) {
            return '통관중';
        } else if (lowerStage.contains('exception')) {
            return '예외상황';
        } else if (lowerStage.contains('pending')) {
            return '대기중';
        } else if (lowerStage.contains('processing')) {
            return '처리중';
        } else if (lowerStage.contains('return')) {
            return '반송중';
        }

        // 번역할 수 없는 경우 원본 반환
        return originalStage;
    }

    /**
     * 이벤트 설명을 한글로 번역
     */
    private static String translateEventDescription(String originalDescription) {
        if (String.isBlank(originalDescription)) return originalDescription;

        // 정확한 매치 시도
        if (EVENT_DESCRIPTION_KOR_MAP.containsKey(originalDescription)) {
            return EVENT_DESCRIPTION_KOR_MAP.get(originalDescription);
        }

        // 부분 매치 시도
        String lowerOriginal = originalDescription.toLowerCase();
        for (String key : EVENT_DESCRIPTION_KOR_MAP.keySet()) {
            if (lowerOriginal.equals(key.toLowerCase())) {
                return EVENT_DESCRIPTION_KOR_MAP.get(key);
            }
        }

        // 키워드 기반 번역 (fallback)
        if (lowerOriginal.contains('delivery') && lowerOriginal.contains('destination')) {
            return '목적지 배송 완료';
        } else if (lowerOriginal.contains('out for delivery')) {
            return '배송 출발';
        } else if (lowerOriginal.contains('customs clearance')) {
            return '통관 처리';
        } else if (lowerOriginal.contains('arrival') && lowerOriginal.contains('destination')) {
            return '목적지 도착';
        } else if (lowerOriginal.contains('onboard') && lowerOriginal.contains('origin')) {
            return '출발지 상차';
        } else if (lowerOriginal.contains('delivered')) {
            return '배송 완료';
        } else if (lowerOriginal.contains('pickup') || lowerOriginal.contains('picked')) {
            return '픽업 완료';
        } else if (lowerOriginal.contains('departure') || lowerOriginal.contains('departed')) {
            return '출발';
        } else if (lowerOriginal.contains('arrival') || lowerOriginal.contains('arrived')) {
            return '도착';
        } else if (lowerOriginal.contains('customs')) {
            return '통관';
        }

        // 번역할 수 없는 경우 원본 반환
        return originalDescription;
    }

    /**
     * 여러 송장 배치 처리
     */
    public static Map<String, Boolean> batchUpdateTrackings(List<String> trackingNumbers) {
        Map<String, Boolean> results = new Map<String, Boolean>();

        for (String trackingNumber : trackingNumbers) {
            try {
                upsertTracking(trackingNumber);
                results.put(trackingNumber, true);
                System.debug('배치 처리 성공: ' + trackingNumber);
            } catch (Exception e) {
                System.debug('배치 처리 실패: ' + trackingNumber + ' - ' + e.getMessage());
                results.put(trackingNumber, false);
            }
        }

        return results;
    }

    /**
     * 배송 추적 삭제 (Master-Detail로 하위 객체 자동 삭제)
     */
    public static Boolean deleteTracking(String trackingNumber) {
        try {
            List<Tracking__c> listTracking = [SELECT Id from Tracking__c where Tracking_Number__c = :trackingNumber];
            if (!listTracking.isEmpty()) {
                delete listTracking; // Master-Detail로 모든 하위 객체 자동 삭제
                System.debug('Tracking 및 모든 관련 객체 삭제 완료: ' + trackingNumber);
            }
            return true;
        } catch (Exception e) {
            System.debug('삭제 실패: ' + e.getMessage());
            return false;
        }
    }

    // 유틸리티 메소드들
    private static Boolean isTrackingCreated(String trackingNumber) {
        List<Tracking__c> listTracking = [SELECT Id from Tracking__c where Tracking_Number__c = :trackingNumber limit 1];
        return !listTracking.isEmpty();
    }

    private static String getErrorDescriptionByCode(Integer errorCode) {
        String descriptionKor;
        for (SeventeenTrackResponseCode__c obj : [SELECT Id, Description__c, DescriptionKor__c from SeventeenTrackResponseCode__c where Code__c = :errorCode limit 1]) {
            descriptionKor = obj.DescriptionKor__c;
        }
        return descriptionKor;
    }

    private static void handleException(String logMessage, String exceptionMessage) {
        System.debug(logMessage);
        throw new TrackingControllerException(exceptionMessage);
    }

    private static void handleException(String logMessage, String exceptionMessage, SavePoint sp) {
        System.debug(logMessage);
        Database.rollback(sp);
        throw new TrackingControllerException(exceptionMessage);
    }

    public class TrackingControllerException extends Exception {
    }
}