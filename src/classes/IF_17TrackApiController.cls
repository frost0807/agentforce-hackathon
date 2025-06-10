/************************************************************************************
 * File Name        : IF_17TrackApiController.cls
 * Author           : 최준석
 * Date             : 2025-05-25
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-05-25      최준석
*************************************************************************************/
public class IF_17TrackApiController {
    // 배송추적 등록(트래킹 번호 추가)
    public static TrackingResponse createTracking(TrackingRequest reqObj) {
        //Pantos Carrier Code 삽입
        for (Carrier__mdt obj : [SELECT Id, CarrierCode__c FROM Carrier__mdt WHERE DeveloperName = 'Pantos' LIMIT 1]) {
            reqObj.carrierCode = Integer.valueOf(obj.CarrierCode__c);
        }

        List<Map<String, Object>> reqList = new List<Map<String, Object>>();
        reqList.add(reqObj.toMap());
        String body = JSON.serialize(reqList);
        HttpRequest req = buildHttpRequest('CreateTracking', body);

        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('res.getBody() : ' + res.getBody());
        if (res.getStatusCode() == 200) return new TrackingResponse().fromJson(res.getBody());
        throw new CalloutException('API Error: ' + res.getBody());
    }

    // 배송추적 조회(트래킹 번호, carrier 등 전체 파라미터)
    public static TrackingResponse getTrackingInfo(TrackingRequest reqObj) {
        List<Map<String, Object>> reqList = new List<Map<String, Object>>();
        reqList.add(reqObj.toMap());
        String body = JSON.serialize(reqList);
        HttpRequest req = buildHttpRequest('GetTracking', body);

        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('res.getBody() : ' + res.getBody());
        if (res.getStatusCode() == 200) return new TrackingResponse().fromJson(res.getBody());
        throw new CalloutException('API Error: ' + res.getBody());
    }

    // 배송추적 삭제(트래킹 번호 삭제)
    public static DeleteResponse deleteTracking(TrackingRequest reqObj) {
        List<Map<String, Object>> reqList = new List<Map<String, Object>>();
        reqList.add(reqObj.toMap());
        String body = JSON.serialize(reqList);
        HttpRequest req = buildHttpRequest('DeleteTracking', body);

        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('res.getBody() : ' + res.getBody());
        if (res.getStatusCode() == 200) return new DeleteResponse().fromJson(res.getBody());
        throw new CalloutException('API Error: ' + res.getBody());
    }

    private static HttpRequest buildHttpRequest(String interfaceName, String body) {
        IFMaster__c objIfMaster = [SELECT Id, Endpoint__c, ContentType__c, Method__c FROM IFMaster__c WHERE Name = :interfaceName];
        Api__mdt objApi = [SELECT Id, ApiKey__c FROM Api__mdt WHERE DeveloperName = 'SeventeenTrack'];

        String endpoint = objIfMaster.Endpoint__c;
        String method = objIfMaster.Method__c;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        req.setHeader('Content-Type', objIfMaster.ContentType__c);
        req.setHeader('17token', objApi.ApiKey__c);
        req.setBody(body);
        System.debug('req ::: ' + req);
        return req;
    }

    /**********************************************************************
     *                      Request Wrapper Class
     **********************************************************************/
    public class TrackingRequest {
        // [요청 파라미터] -- 예약어·오브젝트명 회피(Wrapper 필드), toMap에서만 실제 API 명칭 사용
        public String trackNumber;              // 실제는 'number'
        public Integer carrierCode;             // 실제는 'carrier'
        public String langCode;                 // 실제는 'lang'
        public String emailAddress;             // 실제는 'email'
        public String orderId;                  // 실제는 'order'
        public String userTag;                  // 실제는 'tag'
        public String destCountryCode;          // 실제는 'destination_country'
        public String shipFromCountryCode;      // 실제는 'ship_from_country'
        public Boolean autoDetectCarrier;       // 실제는 'auto_detect'

        public TrackingRequest() {
        }
        public TrackingRequest(String trackNumber) {
            this.trackNumber = trackNumber;
        }

        public Map<String, Object> toMap() {
            Map<String, Object> mapData = new Map<String, Object>();
            mapData.put('number', trackNumber);
            if (carrierCode != null) mapData.put('carrier', carrierCode);
            if (langCode != null) mapData.put('lang', langCode);
            if (emailAddress != null) mapData.put('email', emailAddress);
            if (orderId != null) mapData.put('order', orderId);
            if (userTag != null) mapData.put('tag', userTag);
            if (destCountryCode != null) mapData.put('destination_country', destCountryCode);
            if (shipFromCountryCode != null) mapData.put('ship_from_country', shipFromCountryCode);
            if (autoDetectCarrier != null) mapData.put('auto_detect', autoDetectCarrier);
            return mapData;
        }
    }

    /**********************************************************************
     *          Response Wrapper Class(register, gettrackinfo)
     **********************************************************************/
    public class TrackingResponse {
        public Integer respCode;
        public String respMsg;
        public TrackingDataWrapper respData;

        public TrackingResponse fromJson(String strJson) {
            Map<String, Object> mapData = (Map<String, Object>) JSON.deserializeUntyped(strJson);
            this.respCode = (Integer) mapData.get('code');
            this.respMsg = (String) mapData.get('msg');
            if (mapData.containsKey('data')) {
                this.respData = new TrackingDataWrapper().fromMap((Map<String, Object>) mapData.get('data'));
            }
            return this;
        }
    }
    public class TrackingDataWrapper {
        public List<TrackingAcceptedWrapper> accepted = new List<TrackingAcceptedWrapper>();
        public List<TrackingRejectedWrapper> rejected = new List<TrackingRejectedWrapper>();

        public TrackingDataWrapper fromMap(Map<String, Object> dataMap) {
            if (dataMap.containsKey('accepted')) {
                List<Object> arr = (List<Object>) dataMap.get('accepted');
                for (Object o : arr) {
                    this.accepted.add(new TrackingAcceptedWrapper().fromMap((Map<String, Object>) o));
                }
            }
            if (dataMap.containsKey('rejected')) {
                List<Object> arr = (List<Object>) dataMap.get('rejected');
                for (Object o : arr) {
                    this.rejected.add(new TrackingRejectedWrapper().fromMap((Map<String, Object>) o));
                }
            }
            return this;
        }
    }
    public class TrackingAcceptedWrapper {
        public String trackNumber;
        public Integer carrierCode;
        public String userTag;
        public String orderId;
        public String destCountryCode;
        public String shipFromCountryCode;
        public TrackInfoDetailWrapper trackInfoDetail;

        public TrackingAcceptedWrapper fromMap(Map<String, Object> m) {
            this.trackNumber = (String) m.get('number');
            this.carrierCode = (m.containsKey('carrier') ? (Integer) m.get('carrier') : null);
            this.userTag = (String) m.get('tag');
            this.orderId = (String) m.get('order');
            this.destCountryCode = (String) m.get('destination_country');
            this.shipFromCountryCode = (String) m.get('ship_from_country');
            this.trackInfoDetail = m.containsKey('track_info') && m.get('track_info') != null
                    ? new TrackInfoDetailWrapper().fromMap((Map<String, Object>) m.get('track_info'))
                    : null;
            return this;
        }
    }
    public class TrackInfoDetailWrapper {
        // 모든 주요 파라미터와 중첩 구조를 반영
        public ShippingInfoWrapper shippingInfo;
        public TrackStatusWrapper latestStatus;
        public TrackEventWrapper latestEvent;
        public TimeMetricsWrapper timeMetrics;
        public List<MilestoneWrapper> milestone;
        public MiscInfoWrapper miscInfo;
        public TrackingProvidersWrapper tracking; // providers, events, etc.

        public TrackInfoDetailWrapper fromMap(Map<String, Object> m) {
            if (m.containsKey('shipping_info') && m.get('shipping_info') != null)
                this.shippingInfo = new ShippingInfoWrapper().fromMap((Map<String, Object>) m.get('shipping_info'));
            if (m.containsKey('latest_status') && m.get('latest_status') != null)
                this.latestStatus = new TrackStatusWrapper().fromMap((Map<String, Object>) m.get('latest_status'));
            if (m.containsKey('latest_event') && m.get('latest_event') != null)
                this.latestEvent = new TrackEventWrapper().fromMap((Map<String, Object>) m.get('latest_event'));
            if (m.containsKey('time_metrics') && m.get('time_metrics') != null)
                this.timeMetrics = new TimeMetricsWrapper().fromMap((Map<String, Object>) m.get('time_metrics'));
            if (m.containsKey('milestone') && m.get('milestone') != null) {
                this.milestone = new List<MilestoneWrapper>();
                for (Object o : (List<Object>) m.get('milestone')) {
                    this.milestone.add(new MilestoneWrapper().fromMap((Map<String, Object>) o));
                }
            }
            if (m.containsKey('misc_info') && m.get('misc_info') != null)
                this.miscInfo = new MiscInfoWrapper().fromMap((Map<String, Object>) m.get('misc_info'));
            if (m.containsKey('tracking') && m.get('tracking') != null)
                this.tracking = new TrackingProvidersWrapper().fromMap((Map<String, Object>) m.get('tracking'));
            return this;
        }
    }
    public class ShippingInfoWrapper {
        public AddressWrapper shipperAddress;
        public AddressWrapper recipientAddress;
        public ShippingInfoWrapper fromMap(Map<String, Object> m) {
            if (m.containsKey('shipper_address') && m.get('shipper_address') != null)
                this.shipperAddress = new AddressWrapper().fromMap((Map<String, Object>) m.get('shipper_address'));
            if (m.containsKey('recipient_address') && m.get('recipient_address') != null)
                this.recipientAddress = new AddressWrapper().fromMap((Map<String, Object>) m.get('recipient_address'));
            return this;
        }
    }
    public class AddressWrapper {
        public String country;
        public String stateRegion;
        public String cityName;
        public String streetName;
        public String postalCode;
        public CoordinatesWrapper coordinates;
        public AddressWrapper fromMap(Map<String, Object> m) {
            this.country = (String) m.get('country');
            this.stateRegion = (String) m.get('state');
            this.cityName = (String) m.get('city');
            this.streetName = (String) m.get('street');
            this.postalCode = (String) m.get('postal_code');
            if (m.containsKey('coordinates') && m.get('coordinates') != null)
                this.coordinates = new CoordinatesWrapper().fromMap((Map<String, Object>) m.get('coordinates'));
            return this;
        }
    }
    public class CoordinatesWrapper {
        public Decimal longitude;
        public Decimal latitude;
        public CoordinatesWrapper fromMap(Map<String, Object> m) {
            this.longitude = (m.containsKey('longitude') ? (Decimal) m.get('longitude') : null);
            this.latitude = (m.containsKey('latitude') ? (Decimal) m.get('latitude') : null);
            return this;
        }
    }
    public class TrackStatusWrapper {
        public String statusMain;
        public String statusSub;
        public String statusDesc;
        public TrackStatusWrapper fromMap(Map<String, Object> m) {
            this.statusMain = (String) m.get('status');
            this.statusSub = (String) m.get('sub_status');
            this.statusDesc = (String) m.get('sub_status_descr');
            return this;
        }
    }
    public class TrackEventWrapper {
        public String eventTimeIso;
        public String eventTimeUtc;
        public EventTimeRawWrapper eventTimeRaw;
        public String eventDesc;
        public String eventLocation;
        public String eventStage;
        public String eventSubStatus;
        public AddressWrapper eventAddress;
        public TrackEventWrapper fromMap(Map<String, Object> m) {
            this.eventTimeIso = (String) m.get('time_iso');
            this.eventTimeUtc = (String) m.get('time_utc');
            if (m.containsKey('time_raw') && m.get('time_raw') != null)
                this.eventTimeRaw = new EventTimeRawWrapper().fromMap((Map<String, Object>) m.get('time_raw'));
            this.eventDesc = (String) m.get('description');
            this.eventLocation = (String) m.get('location');
            this.eventStage = (String) m.get('stage');
            this.eventSubStatus = (String) m.get('sub_status');
            if (m.containsKey('address') && m.get('address') != null)
                this.eventAddress = new AddressWrapper().fromMap((Map<String, Object>) m.get('address'));
            return this;
        }
    }
    public class EventTimeRawWrapper {
        public String dateRaw;
        public String timeRaw;
        public String timezoneRaw;
        public EventTimeRawWrapper fromMap(Map<String, Object> m) {
            this.dateRaw = (String) m.get('date');
            this.timeRaw = (String) m.get('time');
            this.timezoneRaw = (String) m.get('timezone');
            return this;
        }
    }
    public class TimeMetricsWrapper {
        public Integer daysAfterOrder;
        public Integer daysOfTransit;
        public Integer daysOfTransitDone;
        public Integer daysAfterLastUpdate;
        public EstimatedDeliveryWrapper estimatedDelivery;
        public TimeMetricsWrapper fromMap(Map<String, Object> m) {
            this.daysAfterOrder = (m.containsKey('days_after_order') ? (Integer) m.get('days_after_order') : null);
            this.daysOfTransit = (m.containsKey('days_of_transit') ? (Integer) m.get('days_of_transit') : null);
            this.daysOfTransitDone = (m.containsKey('days_of_transit_done') ? (Integer) m.get('days_of_transit_done') : null);
            this.daysAfterLastUpdate = (m.containsKey('days_after_last_update') ? (Integer) m.get('days_after_last_update') : null);
            if (m.containsKey('estimated_delivery_date') && m.get('estimated_delivery_date') != null)
                this.estimatedDelivery = new EstimatedDeliveryWrapper().fromMap((Map<String, Object>) m.get('estimated_delivery_date'));
            return this;
        }
    }
    public class EstimatedDeliveryWrapper {
        public String sourceType;
        public String fromDate;
        public String toDate;
        public EstimatedDeliveryWrapper fromMap(Map<String, Object> m) {
            this.sourceType = (String) m.get('source');
            this.fromDate = (String) m.get('from');
            this.toDate = (String) m.get('to');
            return this;
        }
    }
    public class MilestoneWrapper {
        public String keyStage;
        public String timeIso;
        public String timeUtc;
        public EventTimeRawWrapper timeRaw;
        public MilestoneWrapper fromMap(Map<String, Object> m) {
            this.keyStage = (String) m.get('key_stage');
            this.timeIso = (String) m.get('time_iso');
            this.timeUtc = (String) m.get('time_utc');
            if (m.containsKey('time_raw') && m.get('time_raw') != null)
                this.timeRaw = new EventTimeRawWrapper().fromMap((Map<String, Object>) m.get('time_raw'));
            return this;
        }
    }
    public class MiscInfoWrapper {
        public Integer riskFactor;
        public String serviceType;
        public String weightRaw;
        public Decimal weightKg;
        public Integer piecesCount;
        public String dimensionsRaw;
        public String customerNum;
        public String referenceNum;
        public String localNum;
        public String localProviderName;
        public Integer localKeyId;
        public MiscInfoWrapper fromMap(Map<String, Object> m) {
            this.riskFactor = (m.containsKey('risk_factor') ? (Integer) m.get('risk_factor') : null);
            this.serviceType = (String) m.get('service_type');
            this.weightRaw = (String) m.get('weight_raw');
            this.weightKg = (m.containsKey('weight_kg') ? (Decimal) m.get('weight_kg') : null);
            this.piecesCount = (m.containsKey('pieces') ? (Integer) m.get('pieces') : null);
            this.dimensionsRaw = (String) m.get('dimensions');
            this.customerNum = (String) m.get('customer_number');
            this.referenceNum = (String) m.get('reference_number');
            this.localNum = (String) m.get('local_number');
            this.localProviderName = (String) m.get('local_provider');
            this.localKeyId = (m.containsKey('local_key') ? (Integer) m.get('local_key') : null);
            return this;
        }
    }
    public class TrackingProvidersWrapper {
        public Integer providersHash;
        public List<TrackingProviderInfoWrapper> providers;
        // Hash, etc.
        public Integer eventsHash;
        public List<TrackEventWrapper> events;

        public TrackingProvidersWrapper fromMap(Map<String, Object> m) {
            this.providersHash = m.containsKey('providers_hash') ? (Integer) m.get('providers_hash') : null;
            this.providers = new List<TrackingProviderInfoWrapper>();
            if (m.containsKey('providers') && m.get('providers') != null) {
                for (Object o : (List<Object>) m.get('providers')) {
                    this.providers.add(new TrackingProviderInfoWrapper().fromMap((Map<String, Object>) o));
                }
            }
            this.eventsHash = m.containsKey('events_hash') ? (Integer) m.get('events_hash') : null;
            this.events = new List<TrackEventWrapper>();
            if (m.containsKey('events') && m.get('events') != null) {
                for (Object o : (List<Object>) m.get('events')) {
                    this.events.add(new TrackEventWrapper().fromMap((Map<String, Object>) o));
                }
            }
            return this;
        }
    }
    public class TrackingProviderInfoWrapper {
        public ProviderDetailWrapper providerDetail;
        public String providerLang;
        public String serviceType;
        public String latestSyncStatus;
        public String latestSyncTime;
        public Integer eventsHash;
        public List<TrackEventWrapper> providerEvents;

        public TrackingProviderInfoWrapper fromMap(Map<String, Object> m) {
            if (m.containsKey('provider') && m.get('provider') != null)
                this.providerDetail = new ProviderDetailWrapper().fromMap((Map<String, Object>) m.get('provider'));
            this.providerLang = (String) m.get('provider_lang');
            this.serviceType = (String) m.get('service_type');
            this.latestSyncStatus = (String) m.get('latest_sync_status');
            this.latestSyncTime = (String) m.get('latest_sync_time');
            this.eventsHash = (m.containsKey('events_hash') ? (Integer) m.get('events_hash') : null);
            this.providerEvents = new List<TrackEventWrapper>();
            if (m.containsKey('events') && m.get('events') != null) {
                for (Object o : (List<Object>) m.get('events')) {
                    this.providerEvents.add(new TrackEventWrapper().fromMap((Map<String, Object>) o));
                }
            }
            return this;
        }
    }
    public class ProviderDetailWrapper {
        public Integer providerKey;
        public String providerName;
        public String providerAlias;
        public String providerTel;
        public String providerHomepage;
        public String providerCountry;
        public ProviderDetailWrapper fromMap(Map<String, Object> m) {
            this.providerKey = (m.containsKey('key') ? (Integer) m.get('key') : null);
            this.providerName = (String) m.get('name');
            this.providerAlias = (String) m.get('alias');
            this.providerTel = (String) m.get('tel');
            this.providerHomepage = (String) m.get('homepage');
            this.providerCountry = (String) m.get('country');
            return this;
        }
    }
    public class TrackingRejectedWrapper {
        public String trackNumber;
        public ErrorDetailWrapper errorDetail;

        public TrackingRejectedWrapper fromMap(Map<String, Object> m) {
            this.trackNumber = (String) m.get('number');
            if (m.containsKey('error') && m.get('error') != null) {
                this.errorDetail = new ErrorDetailWrapper().fromMap((Map<String, Object>) m.get('error'));
            }
            return this;
        }
    }
    public class ErrorDetailWrapper {
        public Integer errorCode;
        public String errorMessage;

        public ErrorDetailWrapper fromMap(Map<String, Object> mapData) {
            this.errorCode = (Integer) mapData.get('code');
            this.errorMessage = (String) mapData.get('message');
            return this;
        }
    }

    /**********************************************************************
     *              Response Wrapper Class(deletetrack)
     **********************************************************************/
    public class DeleteResponse {
        public Integer code;
        public String msg;
        public Object data;
        public DeleteResponse fromJson(String strJson) {
            Map<String, Object> mapData = (Map<String, Object>) JSON.deserializeUntyped(strJson);
            this.code = (Integer) mapData.get('code');
            this.msg = (String) mapData.get('msg');
            this.data = mapData.get('data');
            return this;
        }
    }
}