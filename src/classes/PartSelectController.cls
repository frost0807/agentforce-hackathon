/************************************************************************************
 * File Name : PartSelectController.cls
 * Author : 최준석
 * Date : 2025-06-04
 * Description :
 * Modification Log
 * ===================================================================================
 * Ver      Date        Author      Modification
 * ===================================================================================
 * 1.0      2025-06-04  최준석         Create
 *************************************************************************************/
public with sharing class PartSelectController {

    // 기본 RiskAnalyzeReport ID (데모용) - 실제 사용 시 제거 필요
    private static final String DEFAULT_RISK_ANALYZE_REPORT_ID = 'a0PQy000001ebWXMAY';

    /**
     * Product2 목록과 SelectedPartItem 목록을 분리해서 조회
     * @param riskAnalyzeReportId 위험 분석 보고서 ID
     * @return PartListResult Product2 목록과 SelectedPartItem 목록
     */
    @AuraEnabled(Cacheable=true)
    public static PartListResult getRecommendedParts(Id riskAnalyzeReportId) {
        PartListResult result = new PartListResult();

        try {
            System.debug('🔍 Input riskAnalyzeReportId: ' + riskAnalyzeReportId);

            // riskAnalyzeReportId가 없으면 기본값 사용 (데모용)
            if (riskAnalyzeReportId == null) {
                riskAnalyzeReportId = DEFAULT_RISK_ANALYZE_REPORT_ID;
                System.debug('⚠️ Using default ID: ' + riskAnalyzeReportId);
            }

            System.debug('🔍 Processing riskAnalyzeReportId: ' + riskAnalyzeReportId);

            // 1. RiskAnalyzeReport에서 Asset 정보 조회
            List<RiskAnalyzeReport__c> reports = [
                    SELECT Id, Asset__c, Asset__r.Product2Id, Asset__r.Product2.ProductCode
                    FROM RiskAnalyzeReport__c
                    WHERE Id = :riskAnalyzeReportId
                    AND Asset__c != NULL
                    AND Asset__r.Product2Id != NULL
                    LIMIT 1
            ];

            if (reports.isEmpty()) {
                System.debug('❌ RiskAnalyzeReport not found or missing Asset/Product info');
                result.success = false;
                result.message = 'RiskAnalyzeReport not found: ' + riskAnalyzeReportId;
                return result;
            }

            String assetProductCode = reports[0].Asset__r.Product2.ProductCode;
            System.debug('🎯 Asset ProductCode: ' + assetProductCode);

            // 2. 해당 ProductCode를 Family로 하는 모든 Product2 조회
            List<Product2> relatedProducts = [
                    SELECT Id, Name, ProductCode, Family,
                            ProductClassification__c, Replacement_Cycle__c,
                            Purchase_Company__c, Shipping_Lead_Time__c, Quantity__c,
                            Price__c, IsActive
                    FROM Product2
                    WHERE IsActive = TRUE
                    AND Family = :assetProductCode
                    ORDER BY ProductCode ASC
                    LIMIT 2000
            ];

            if (relatedProducts.isEmpty()) {
                System.debug('❌ No related products found for Family: ' + assetProductCode);
                result.success = false;
                result.message = 'No related products found';
                return result;
            }

            System.debug('📦 Found related products: ' + relatedProducts.size());

            // 3. 해당 보고서의 모든 SelectedPartItem 조회
            System.debug('🔍 Querying SelectedPartItem for report: ' + riskAnalyzeReportId);
            List<SelectedPartItem__c> selectedParts = [
                    SELECT Id, Product__c, Quantity__c, ExternalId__c,
                            PartCode__c, PartName__c, ListPrice__c
                    FROM SelectedPartItem__c
                    WHERE RiskAnalyzeReport__c = :riskAnalyzeReportId
            ];

            System.debug('🎯 Found selected parts: ' + selectedParts.size());

            // 선택된 부품들 상세 로그
            for (SelectedPartItem__c part : selectedParts) {
                System.debug('   └── ' + part.PartCode__c + ' (Product: ' + part.Product__c + ', Qty: ' + part.Quantity__c + ')');
            }

            // 4. 결과 설정
            result.products = relatedProducts;
            result.selectedParts = selectedParts;
            result.success = true;

            System.debug('✅ Returning result - Products: ' + result.products.size() + ', Selected Parts: ' + result.selectedParts.size());

            return result;

        } catch (Exception e) {
            System.debug('💥 Error retrieving recommended parts: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.success = false;
            result.message = e.getMessage();
            return result;
        }
    }

    /**
     * 기준 Product의 ProductCode 조회 (화면 표시용)
     * @param riskAnalyzeReportId 위험 분석 보고서 ID
     * @return String 기준 ProductCode
     */
    @AuraEnabled(Cacheable=true)
    public static String getBaseProductCode(Id riskAnalyzeReportId) {
        try {
            System.debug('🔍 Getting base product code for: ' + riskAnalyzeReportId);

            // riskAnalyzeReportId가 없으면 기본값 사용
            if (riskAnalyzeReportId == null) {
                riskAnalyzeReportId = DEFAULT_RISK_ANALYZE_REPORT_ID;
                System.debug('⚠️ Using default ID for base product: ' + riskAnalyzeReportId);
            }

            // 1. RiskAnalyzeReport에서 Asset의 Product 정보 조회
            List<RiskAnalyzeReport__c> reports = [
                    SELECT Id, Asset__c, Asset__r.Product2Id, Asset__r.Product2.ProductCode
                    FROM RiskAnalyzeReport__c
                    WHERE Id = :riskAnalyzeReportId
                    AND Asset__c != NULL
                    AND Asset__r.Product2Id != NULL
                    LIMIT 1
            ];

            if (!reports.isEmpty()) {
                String productCode = reports[0].Asset__r.Product2.ProductCode;
                System.debug('✅ Found base product code: ' + productCode);
                return productCode;
            }

            System.debug('⚠️ No base product found, returning demo code');
            return 'DEMO-BASE-PRODUCT';

        } catch (Exception e) {
            System.debug('💥 Error retrieving base product code: ' + e.getMessage());
            return 'DEMO-BASE-PRODUCT';
        }
    }

    /**
     * 선택된 부품들을 SelectedPartItem__c 객체에 저장 (완전 동기화)
     * @param selectedParts 저장할 부품 정보 리스트
     * @return PartSaveResult 저장 결과
     */
    @AuraEnabled
    public static PartSaveResult saveSelectedParts(List<SelectedPartData> selectedParts) {
        PartSaveResult result = new PartSaveResult();

        try {
            System.debug('🔍 SaveSelectedParts called with parts count: ' + (selectedParts != null ? selectedParts.size() : 0));

            if (selectedParts == null || selectedParts.isEmpty()) {
                System.debug('⚠️ No parts provided - will clear all selections for default report. Consider passing specific report ID for clearing.');
                // 이전: return saveSelectedPartsIncremental(DEFAULT_RISK_ANALYZE_REPORT_ID, new List<SelectedPartData>());
                // 변경 제안: LWC에서 명시적 ID로 호출하도록 유도하거나, 이 메소드의 시그니처를 변경하여 ID를 받아야 함.
                // LWC에서 `saveSelectedParts({ reportIdFromLwc: this.effectiveRiskAnalyzeReportId, selectedPartsData: [] })` 형태로 호출하는 것을 권장.
                // 여기서는 우선 이전 로직을 유지하되, 주석으로 명시합니다. 실제 운영 시에는 이 부분을 명확히 해야 합니다.
                return saveSelectedPartsIncremental(DEFAULT_RISK_ANALYZE_REPORT_ID, new List<SelectedPartData>());
            }

            // riskAnalyzeReportId 추출
            Id riskAnalyzeReportId = selectedParts[0].riskAnalyzeReportId;
            System.debug('🔍 Extracted riskAnalyzeReportId from first part: ' + riskAnalyzeReportId);

            if (riskAnalyzeReportId == null) {
                // LWC에서 selectedPartsData의 각 항목에 riskAnalyzeReportId를 채워 보내므로, 이 경우는 드물어야 합니다.
                riskAnalyzeReportId = DEFAULT_RISK_ANALYZE_REPORT_ID;
                System.debug('⚠️ No ID provided in selectedParts[0], using default: ' + riskAnalyzeReportId);
            }

            // LWC에서 이미 각 partData에 riskAnalyzeReportId를 설정해서 보내므로, 아래 보정 로직은 중복일 수 있으나 안전장치로 둡니다.
            for (SelectedPartData part : selectedParts) {
                if (part.riskAnalyzeReportId == null) {
                    part.riskAnalyzeReportId = riskAnalyzeReportId; // 전체 작업을 통일된 ID로 수행
                    System.debug('🔧 Fixed missing riskAnalyzeReportId for product: ' + part.productId + ' to ' + riskAnalyzeReportId);
                } else if (part.riskAnalyzeReportId != riskAnalyzeReportId) {
                    System.debug('⚠️ Warning: Mismatched riskAnalyzeReportId in part data. Product: ' + part.productId +
                            ' PartID: ' + part.riskAnalyzeReportId + ' vs TransactionID: ' + riskAnalyzeReportId + '. Using TransactionID.');
                    part.riskAnalyzeReportId = riskAnalyzeReportId; // 일관성 유지
                }
            }

            return saveSelectedPartsIncremental(riskAnalyzeReportId, selectedParts);

        } catch (Exception e) {
            result.success = false;
            result.message = '예상치 못한 오류가 발생했습니다: ' + e.getMessage();
            System.debug('💥 General Error in saveSelectedParts: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return result;
        }
    }

    /**
     * 선택된 부품들을 upsert/delete 처리 (완전한 동기화)
     * @param riskAnalyzeReportId 위험 분석 보고서 ID
     * @param selectedParts 현재 선택된 부품 정보 리스트
     * @return PartSaveResult 저장 결과
     */
    @AuraEnabled
    public static PartSaveResult saveSelectedPartsIncremental(Id riskAnalyzeReportId, List<SelectedPartData> selectedParts) {
        PartSaveResult result = new PartSaveResult();

        try {
            System.debug('🔍 SaveSelectedPartsIncremental called');
            System.debug('🔍 riskAnalyzeReportId: ' + riskAnalyzeReportId);
            System.debug('🔍 selectedParts count: ' + (selectedParts != null ? selectedParts.size() : 0));

            if (riskAnalyzeReportId == null) {
                // 이 메소드는 명시적인 riskAnalyzeReportId를 받아야 함.
                System.debug('💥 Critical Error: riskAnalyzeReportId is null in saveSelectedPartsIncremental.');
                result.success = false;
                result.message = '위험 분석 보고서 ID가 지정되지 않았습니다.';
                return result;
            }

            System.debug('💾 Processing incremental save for report: ' + riskAnalyzeReportId);
            System.debug('📊 Current selected parts count: ' + (selectedParts != null ? selectedParts.size() : 0));

            // 1. 현재 선택된 Product ID 목록
            Set<Id> currentSelectedProductIds = new Set<Id>();
            Map<Id, SelectedPartData> currentSelectedPartsMap = new Map<Id, SelectedPartData>();

            if (selectedParts != null) {
                for (SelectedPartData partData : selectedParts) {
                    if (partData.productId == null) {
                        System.debug('⚠️ Warning: productId is null in SelectedPartData. Skipping.');
                        continue;
                    }
                    currentSelectedProductIds.add(partData.productId);
                    currentSelectedPartsMap.put(partData.productId, partData);
                    System.debug('📋 Part to save: ' + partData.productId + ' (Qty: ' + partData.quantity + ', Price: ' + partData.listPrice + ')');
                }
            }

            System.debug('🎯 Current selected product IDs: ' + currentSelectedProductIds);

            // 2. 기존 저장된 SelectedPartItem 조회
            List<SelectedPartItem__c> existingParts = [
                    SELECT Id, Product__c, Quantity__c, ExternalId__c
                    FROM SelectedPartItem__c
                    WHERE RiskAnalyzeReport__c = :riskAnalyzeReportId
            ];

            System.debug('📂 Existing parts count: ' + existingParts.size());

            Set<Id> existingProductIds = new Set<Id>();
            Map<Id, SelectedPartItem__c> existingPartsMap = new Map<Id, SelectedPartItem__c>();

            for (SelectedPartItem__c existing : existingParts) {
                existingProductIds.add(existing.Product__c);
                existingPartsMap.put(existing.Product__c, existing);
                System.debug('📂 Existing part: ' + existing.Product__c + ' (Qty: ' + existing.Quantity__c + ')');
            }

            System.debug('🔍 Existing product IDs: ' + existingProductIds);

            // 3. 삭제할 부품들 (기존에 있었지만 현재 선택되지 않은 것들)
            List<SelectedPartItem__c> partsToDelete = new List<SelectedPartItem__c>();
            for (Id existingProductId : existingProductIds) {
                if (!currentSelectedProductIds.contains(existingProductId)) {
                    partsToDelete.add(existingPartsMap.get(existingProductId));
                    System.debug('🗑️ Marked for deletion: ' + existingProductId);
                }
            }

            // 4. 추가할 부품들 (새로 선택된 것들)
            List<SelectedPartItem__c> partsToInsert = new List<SelectedPartItem__c>();
            for (Id newProductId : currentSelectedProductIds) {
                if (!existingProductIds.contains(newProductId)) {
                    SelectedPartData partData = currentSelectedPartsMap.get(newProductId);
                    SelectedPartItem__c newPart = new SelectedPartItem__c();
                    newPart.ExternalId__c = riskAnalyzeReportId + '_' + newProductId; // SelectedPartItem의 ExternalId
                    newPart.RiskAnalyzeReport__c = riskAnalyzeReportId;
                    newPart.Product__c = newProductId;
                    newPart.Quantity__c = partData.quantity;
                    // ListPrice__c는 SelectedPartItem에 직접 저장하지 않는다면 Product2나 PricebookEntry에서 가져와야 함.
                    // 현재 SelectedPartItem 객체 정의에 ListPrice__c가 있다면 설정.
                    // newPart.ListPrice__c = partData.listPrice; // 필요시 주석 해제 및 필드 확인
                    partsToInsert.add(newPart);
                    System.debug('➕ Marked for insert: ' + newProductId + ' with quantity: ' + partData.quantity);
                }
            }

            // 5. 수정할 부품들 (수량 등이 변경된 것들)
            List<SelectedPartItem__c> partsToUpdate = new List<SelectedPartItem__c>();
            for (Id commonProductId : currentSelectedProductIds) {
                if (existingProductIds.contains(commonProductId)) {
                    SelectedPartItem__c existingPart = existingPartsMap.get(commonProductId);
                    SelectedPartData newPartData = currentSelectedPartsMap.get(commonProductId);

                    Boolean needsUpdate = false;
                    if (existingPart.Quantity__c != newPartData.quantity) {
                        existingPart.Quantity__c = newPartData.quantity;
                        needsUpdate = true;
                    }
                    // SelectedPartItem에 ListPrice__c 필드가 있고, 가격도 업데이트 대상이라면 추가
                    // if (existingPart.ListPrice__c != newPartData.listPrice) { // 필드 확인 필요
                    //    existingPart.ListPrice__c = newPartData.listPrice;
                    //    needsUpdate = true;
                    // }

                    if (needsUpdate) {
                        partsToUpdate.add(existingPart);
                        System.debug('📝 Marked for update: ' + commonProductId + ' quantity: ' + newPartData.quantity);
                    }
                }
            }

            // 6. DML 실행
            Savepoint sp = Database.setSavepoint();
            try {
                Integer deletedCount = 0;
                Integer insertedCount = 0;
                Integer updatedCount = 0;

                if (!partsToDelete.isEmpty()) {
                    delete partsToDelete;
                    deletedCount = partsToDelete.size();
                    System.debug('✅ Deleted ' + deletedCount + ' parts');
                }

                if (!partsToInsert.isEmpty()) {
                    insert partsToInsert;
                    insertedCount = partsToInsert.size();
                    System.debug('✅ Inserted ' + insertedCount + ' parts');
                }

                if (!partsToUpdate.isEmpty()) {
                    update partsToUpdate;
                    updatedCount = partsToUpdate.size();
                    System.debug('✅ Updated ' + updatedCount + ' parts');
                }

                result.success = true;
                result.message = String.format('동기화 완료: 추가 {0}개, 수정 {1}개, 삭제 {2}개',
                        new String[]{
                                String.valueOf(insertedCount),
                                String.valueOf(updatedCount),
                                String.valueOf(deletedCount)
                        });

                List<SelectedPartItem__c> allSavedParts = new List<SelectedPartItem__c>();
                allSavedParts.addAll(partsToInsert); // insert 후 ID가 채워짐
                allSavedParts.addAll(partsToUpdate); // 이미 ID가 있음
                result.savedRecords = allSavedParts;

                System.debug('🎉 Incremental save completed successfully');
                System.debug('📊 Final result: ' + result.message);

            } catch (DmlException e) {
                Database.rollback(sp);
                result.success = false;
                result.message = '저장 중 DML 오류가 발생했습니다: ' + e.getDmlMessage(0);
                System.debug('💥 DML Error in incremental save: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
            }

        } catch (Exception e) {
            result.success = false;
            result.message = '저장 중 오류가 발생했습니다: ' + e.getMessage();
            System.debug('💥 Error in incremental save: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }

        return result;
    }

    /**
     * 견적서 생성 및 화면 전환 처리
     * @param riskAnalyzeReportId 위험 분석 보고서 ID
     * @param selectedParts 선택된 부품 목록
     * @return QuoteGenerationResult 처리 결과
     */
    @AuraEnabled
    public static QuoteGenerationResult generateQuoteAndTransition(Id riskAnalyzeReportId, List<SelectedPartData> selectedParts) {
        QuoteGenerationResult result = new QuoteGenerationResult();

        try {
            System.debug('🔍 GenerateQuoteAndTransition called');
            System.debug('🔍 riskAnalyzeReportId: ' + riskAnalyzeReportId);

            if (riskAnalyzeReportId == null) {
                // 운영 환경에서는 이 기본값 로직은 적절하지 않을 수 있습니다.
                // LWC에서 항상 유효한 ID를 전달하도록 보장하는 것이 좋습니다.
                riskAnalyzeReportId = DEFAULT_RISK_ANALYZE_REPORT_ID;
                System.debug('⚠️ Using default ID for quote generation: ' + riskAnalyzeReportId);
            }

            if (selectedParts == null || selectedParts.isEmpty()) {
                result.success = false;
                result.message = '선택된 부품이 없습니다.';
                return result;
            }

            // 1. SelectedPartItem upsert (기존 메서드 활용)
            PartSaveResult partSaveResult = saveSelectedPartsIncremental(riskAnalyzeReportId, selectedParts);
            if (!partSaveResult.success) {
                result.success = false;
                result.message = '부품 저장 실패: ' + partSaveResult.message;
                return result;
            }

            // 2. RiskAnalyzeReport에서 Account 정보 조회
            List<RiskAnalyzeReport__c> reports = [
                    SELECT Id, Asset__c, Asset__r.AccountId
                    FROM RiskAnalyzeReport__c
                    WHERE Id = :riskAnalyzeReportId
                    AND Asset__c != NULL
                    AND Asset__r.AccountId != NULL
                    LIMIT 1
            ];

            if (reports.isEmpty()) {
                result.success = false;
                result.message = 'Account 정보를 찾을 수 없습니다. (RiskAnalyzeReportId: ' + riskAnalyzeReportId + ')';
                return result;
            }

            Id accountId = reports[0].Asset__r.AccountId;

            // 3. Service Quote 및 LineItem upsert (riskAnalyzeReportId 전달 추가)
            Id serviceQuoteId = upsertServiceQuoteWithLineItems(accountId, riskAnalyzeReportId, selectedParts);

            result.success = true;
            result.message = '견적서 생성 완료. Service Quote ID: ' + serviceQuoteId;
            result.serviceQuoteId = serviceQuoteId;
            result.accountId = accountId;

            Map<String, String> mapServiceQuoteId = new Map<String, String>();
            mapServiceQuoteId.put('serviceQuoteId', serviceQuoteId);

            //Self Quote로 전환
            PublishMessageController.publishMessage('SELF_QUOTE', JSON.serialize(mapServiceQuoteId));

        } catch (Exception e) {
            result.success = false;
            result.message = '견적서 생성 중 오류 발생: ' + e.getMessage();
            System.debug('💥 Error in generateQuoteAndTransition: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
        }

        return result;
    }

    /**
     * Service Quote 및 LineItem upsert 처리 (External ID 기준)
     * @param accountId 고객사 ID
     * @param riskAnalyzeReportId 위험 분석 보고서 ID (External ID 구성에 사용)
     * @param selectedParts 선택된 부품 목록
     * @return Id Service Quote ID
     */
    @AuraEnabled
    public static Id upsertServiceQuoteWithLineItems(Id accountId, Id riskAnalyzeReportId, List<SelectedPartData> selectedParts) {
        try {
            // ServiceQuote__c 객체의 External ID 필드 API 이름을 정확히 지정해야 합니다.
            // 예: ExternalId__c 또는 CustomExternalIdField__c
            // 이 예제에서는 'ExternalId__c'로 가정합니다. 실제 필드 이름으로 변경하세요.
            String externalIdFieldApiName = 'ExternalId__c'; // << 중요: 실제 External ID 필드 API 이름으로 변경
            Map<String, Schema.SObjectField> serviceQuoteFields = ServiceQuote__c.SObjectType.getDescribe().fields.getMap();

            if (!serviceQuoteFields.containsKey(externalIdFieldApiName.toLowerCase())) {
                System.debug('💥 Critical Error: ServiceQuote__c External ID field (' + externalIdFieldApiName + ') not found.');
                throw new AuraHandledException('ServiceQuote__c의 External ID 필드(' + externalIdFieldApiName + ') 설정이 필요합니다.');
            }
            SObjectField serviceQuoteExternalIdField = serviceQuoteFields.get(externalIdFieldApiName.toLowerCase());


            String serviceQuoteExternalIdValue = accountId + '_' + riskAnalyzeReportId;
            System.debug('📋 Processing Service Quote upsert for External ID: ' + serviceQuoteExternalIdValue);

            ServiceQuote__c serviceQuoteToUpsert = new ServiceQuote__c();

            serviceQuoteToUpsert.put(serviceQuoteExternalIdField, serviceQuoteExternalIdValue);

            serviceQuoteToUpsert.AccountId__c = accountId;

            // ServiceQuote__c에 RiskAnalyzeReport__c 조회 필드가 있다면 설정
            // 실제 필드 API 이름으로 변경해주세요. (예: Risk_Analyze_Report_Link__c)
            String riskReportLookupApiName = 'RiskAnalyzeReport__c'; // << 중요: 실제 RiskAnalyzeReport 조회 필드 API 이름으로 변경
            if (serviceQuoteFields.containsKey(riskReportLookupApiName.toLowerCase())) {
                serviceQuoteToUpsert.put(riskReportLookupApiName, riskAnalyzeReportId);
                System.debug('INFO: Setting ' + riskReportLookupApiName + ' to ' + riskAnalyzeReportId);
            } else {
                System.debug('INFO: Lookup field ' + riskReportLookupApiName + ' not found on ServiceQuote__c. Skipping.');
            }

            serviceQuoteToUpsert.QuoteDate__c = Date.today();
            serviceQuoteToUpsert.Method_of_Payment__c = 'Cash'; // Picklist 값 확인 필요 (예: '현금')
            serviceQuoteToUpsert.Validity__c = '견적일로부터 30일';
            serviceQuoteToUpsert.Packing__c = '목재포장';
            serviceQuoteToUpsert.Inspection__c = '사내검사';
            serviceQuoteToUpsert.Email__c = UserInfo.getUserEmail();
            serviceQuoteToUpsert.QuoteCreatedBy__c = UserInfo.getName();
            serviceQuoteToUpsert.DeliveryCondition__c = '협의';

            List<ServiceQuote__c> existingQuotes = [
                    SELECT Id, OfferNo__c
                    FROM ServiceQuote__c
                    WHERE ExternalId__c = :serviceQuoteExternalIdValue // SOQL에는 실제 필드명 사용
                    LIMIT 1
            ];

            if (existingQuotes.isEmpty()) {
                serviceQuoteToUpsert.OfferNo__c = generateQuoteNumber();
                System.debug('✨ New Service Quote. OfferNo generated: ' + serviceQuoteToUpsert.OfferNo__c);
            } else {
                if (String.isBlank(existingQuotes[0].OfferNo__c)) {
                    serviceQuoteToUpsert.OfferNo__c = generateQuoteNumber();
                    System.debug('📝 Existing Service Quote but OfferNo was blank. OfferNo generated: ' + serviceQuoteToUpsert.OfferNo__c);
                }
                System.debug('📝 Updating existing Service Quote. ID: ' + existingQuotes[0].Id);
            }

            System.debug('📋 Attempting to upsert ServiceQuote: ' + JSON.serialize(serviceQuoteToUpsert));

            Database.UpsertResult upsertResult = Database.upsert(serviceQuoteToUpsert, serviceQuoteExternalIdField, false);

            if (upsertResult.isSuccess()) {
                Id upsertedQuoteId = upsertResult.getId();
                System.debug('✅ Upserted Service Quote successfully. ID: ' + upsertedQuoteId);

                syncServiceQuoteLineItems(upsertedQuoteId, selectedParts);
                return upsertedQuoteId;
            } else {
                String errors = '';
                for (Database.Error err : upsertResult.getErrors()) {
                    errors += err.getStatusCode() + ': ' + err.getMessage() + ' Fields: ' + String.join(err.getFields(), ',') + '; ';
                }
                System.debug('💥 Error upserting Service Quote: ' + errors);
                throw new AuraHandledException('Service Quote upsert 실패: ' + errors);
            }

        } catch (Exception e) {
            System.debug('💥 Error in upsertServiceQuoteWithLineItems: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Service Quote 처리 중 오류 발생: ' + e.getMessage());
        }
    }

    /**
     * Service Quote LineItem 완전 동기화 (추가/수정/삭제)
     * @param serviceQuoteId Service Quote ID
     * @param selectedParts 현재 선택된 부품 목록
     */
    private static void syncServiceQuoteLineItems(Id serviceQuoteId, List<SelectedPartData> selectedParts) {
        System.debug('🔄 Syncing LineItems for Service Quote: ' + serviceQuoteId);

        Set<Id> currentSelectedProductIds = new Set<Id>();
        Map<Id, SelectedPartData> currentSelectedPartsMap = new Map<Id, SelectedPartData>();

        if (selectedParts != null) {
            for (SelectedPartData partData : selectedParts) {
                if (partData.productId == null) continue;
                currentSelectedProductIds.add(partData.productId);
                currentSelectedPartsMap.put(partData.productId, partData);
            }
        }
        System.debug('🎯 Current selected product IDs for LineItems: ' + currentSelectedProductIds);

        List<ServiceQuoteLineItem__c> existingLineItems = [
                SELECT Id, ProductId__c, Quantity__c, UnitPrice__c, ExternalId__c
                FROM ServiceQuoteLineItem__c
                WHERE ServiceQuote__c = :serviceQuoteId
        ];
        System.debug('📂 Existing LineItems count: ' + existingLineItems.size());

        Map<Id, ServiceQuoteLineItem__c> existingLineItemsMap = new Map<Id, ServiceQuoteLineItem__c>();
        for (ServiceQuoteLineItem__c existingItem : existingLineItems) {
            existingLineItemsMap.put(existingItem.ProductId__c, existingItem);
        }

        List<ServiceQuoteLineItem__c> lineItemsToDelete = new List<ServiceQuoteLineItem__c>();
        for (ServiceQuoteLineItem__c existingItem : existingLineItems) {
            if (!currentSelectedProductIds.contains(existingItem.ProductId__c)) {
                lineItemsToDelete.add(existingItem);
                System.debug('🗑️ LineItem marked for deletion (Product): ' + existingItem.ProductId__c);
            }
        }

        List<ServiceQuoteLineItem__c> lineItemsToUpsert = new List<ServiceQuoteLineItem__c>();
        for (Id productId : currentSelectedProductIds) {
            SelectedPartData partData = currentSelectedPartsMap.get(productId);
            ServiceQuoteLineItem__c lineItem;

            if (existingLineItemsMap.containsKey(productId)) { // Update existing
                lineItem = existingLineItemsMap.get(productId);
                Boolean needsUpdate = false;
                if (lineItem.Quantity__c != partData.quantity) {
                    lineItem.Quantity__c = partData.quantity;
                    needsUpdate = true;
                }
                if (lineItem.UnitPrice__c != partData.listPrice) {
                    lineItem.UnitPrice__c = partData.listPrice;
                    needsUpdate = true;
                }
                if (needsUpdate) {
                    lineItemsToUpsert.add(lineItem);
                    System.debug('📝 LineItem marked for update (Product): ' + productId);
                }
            } else { // Insert new
                lineItem = new ServiceQuoteLineItem__c();
                lineItem.ExternalId__c = serviceQuoteId + '_' + productId; // Line Item의 External ID
                lineItem.ServiceQuote__c = serviceQuoteId;
                lineItem.ProductId__c = productId;
                lineItem.Quantity__c = partData.quantity;
                lineItem.UnitPrice__c = partData.listPrice;
                lineItem.Unit__c = 'EA'; // 기본값 설정
                lineItemsToUpsert.add(lineItem);
                System.debug('➕ LineItem marked for insert (Product): ' + productId);
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (!lineItemsToDelete.isEmpty()) {
                delete lineItemsToDelete;
                System.debug('✅ Deleted ' + lineItemsToDelete.size() + ' LineItems');
            }
            if (!lineItemsToUpsert.isEmpty()) {
                // ServiceQuoteLineItem에도 External ID 필드가 있다면 upsert ExternalId__c 사용 가능
                // 여기서는 insert/update를 분리했으므로 upsert List 사용
                upsert lineItemsToUpsert; // ID가 있으면 update, 없으면 insert
                System.debug('✅ Upserted ' + lineItemsToUpsert.size() + ' LineItems');
            }
            System.debug('🎉 LineItem sync completed.');
        } catch (DmlException e) {
            Database.rollback(sp);
            System.debug('💥 DML Error in syncServiceQuoteLineItems: ' + e.getDmlMessage(0));
            throw e; // Re-throw to be caught by calling method
        }
    }

    /**
     * 견적서 번호 생성
     */
    private static String generateQuoteNumber() {
        Date today = Date.today();
        String dateStr = today.year() +
                String.valueOf(today.month()).leftPad(2, '0') +
                String.valueOf(today.day()).leftPad(2, '0');
        // 더 강력한 고유성을 위해 시간 및 임의의 숫자 조합 강화
        Long nowTicks = Datetime.now().getTime();
        Integer randomNum = (Integer) (Math.random() * 10000); // 범위 증가
        return 'Q' + dateStr + '-' + String.valueOf(randomNum).leftPad(4, '0') + '-' + String.valueOf(nowTicks).right(4);
    }

    // Wrapper 클래스들
    public class PartListResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public List<Product2> products { get; set; }
        @AuraEnabled public List<SelectedPartItem__c> selectedParts { get; set; }

        public PartListResult() {
            this.success = false;
            this.products = new List<Product2>();
            this.selectedParts = new List<SelectedPartItem__c>();
        }
    }

    public class SelectedPartData {
        @AuraEnabled public Id riskAnalyzeReportId { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Decimal listPrice { get; set; } // LWC에서 이 값을 Product2.Price__c 또는 SelectedPartItem.ListPrice__c에서 가져옴
        @AuraEnabled public Decimal quantity { get; set; }
    }

    public class QuoteGenerationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id serviceQuoteId { get; set; }
        @AuraEnabled public Id accountId { get; set; }

        public QuoteGenerationResult() {
            this.success = false;
            this.message = '';
        }
    }

    public class PartSaveResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public List<SelectedPartItem__c> savedRecords { get; set; } // 저장/업데이트된 레코드 반환

        public PartSaveResult() {
            this.success = false;
            this.message = '';
            this.savedRecords = new List<SelectedPartItem__c>();
        }
    }
}