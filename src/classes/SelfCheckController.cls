/************************************************************************************
* File Name   	    : SelfCheckController
* Author	  		: Jiae.Tak
* Date				: 2025-06-02
* Tester	  		:
* Target	  		:
* Description 	    : 
* Modification Log
* ===================================================================================
* Ver      Date            Author          Modification
* ===================================================================================
* 1.0      2025-06-02         Jiae.Tak          Create
************************************************************************************/
public with sharing class SelfCheckController {
    @AuraEnabled(Cacheable=false)
    public static Map<String, Object> getInit(String uuid){
        System.debug('uuid : ' + uuid);
        Map<String, Object> mapReturn = new Map<String, Object>();
        try {
            RiskAnalyzeReport__c objReport = [
                    SELECT  Id, MailContent__c, MailSubject__c, Account__c, Asset__c, Asset__r.Product2Id, Asset__r.ManufactureDate, Asset__r.InstallDate, Asset__r.Product2.Name
                    FROM    RiskAnalyzeReport__c
                    WHERE   UUID__c =: uuid
                    LIMIT   1
            ];

            List<SelfCheckItem__c> listSelfCheckItems = new List<SelfCheckItem__c>([
                SELECT      Id, Sequence__c, Description__c
                FROM        SelfCheckItem__c
                WHERE       RiskAnalyzeReport__c =: objReport.Id
                ORDER BY    Sequence__c
            ]);

            mapReturn.put('selfCheckItems', listSelfCheckItems);
            mapReturn.put('objReport', objReport);
        }catch (Exception e){
            System.debug('Error in getInit: ' + e.getMessage());
            mapReturn.put('error', e.getMessage());
            mapReturn.put('selfCheckItems', new List<SelfCheckItem__c>());
        }

        return mapReturn;
    }

    @AuraEnabled(Cacheable=false)
    public static Map<String, Object> updateSelfCheckItems(List<Id> itemIds){
        Map<String, Object> mapReturn = new Map<String, Object>();
        try{
            if (itemIds != null && !itemIds.isEmpty()) {
                List<SelfCheckItem__c> itemsToUpdate = new List<SelfCheckItem__c>([
                        SELECT  Id, IsChecked__c
                        FROM    SelfCheckItem__c
                        WHERE   Id IN :itemIds
                ]);
                System.debug('itemsToUpdate : ' + itemsToUpdate);
                List<SelfCheckItem__c> listUpdate = new List<SelfCheckItem__c>();
                if (!itemsToUpdate.isEmpty()) {
                    for (SelfCheckItem__c item : itemsToUpdate) {
                        item.IsChecked__c = true;
                        listUpdate.add(item);
                    }
                    update listUpdate;
                    mapReturn.put('status', 'SUCCESS');
                    mapReturn.put('message', 'Successfully updated ' + itemsToUpdate.size() + ' records.');
                } else {
                    mapReturn.put('status', 'ERROR');
                    mapReturn.put('message', 'No matching items found for update.');
                }
            } else {
                mapReturn.put('status', 'ERROR');
                mapReturn.put('message', 'No item IDs provided for update.');
            }
        } catch (Exception e) {
            System.debug('General Error updating SelfCheckItem__c: ' + e.getMessage());
            throw new AuraHandledException('An unexpected error occurred: ' + e.getMessage());
        }
        return mapReturn;
    }

    @AuraEnabled
    public static Map<String, Object> processActionRecAndProduct(RiskAnalyzeReport__c objReport){
        Map<String ,Object> mapReturn = new Map<String, Object>();
        try{
            if (objReport != null) {
                List<SelfCheckItem__c> listCheckItem = new List<SelfCheckItem__c>([
                        SELECT  Id, IsChecked__c, Description__c
                        FROM    SelfCheckItem__c
                        WHERE   RiskAnalyzeReport__c =: objReport.Id
                ]);

                List<Product2> listProduct = new List<Product2>([
                        SELECT  Id, Name, ProductCode, Price__c, Stock__c, Quantity__c, Replacement_Cycle__c
                        FROM    Product2
                        WHERE   Family = :objReport.Asset__r.Product2.Name
                ]);

                List<Case> listCase = new List<Case>([
                        SELECT   Id, AssetId, Subject, Description, Part_Code__c, Part_Name__c, malfuction_type__c
                                ,Malfunction_Type_Detail__c, CreatedDate, Fault_Code__c, Manufacturer__c, Price__c
                                ,Date_Time_Open__c, Date_Time_Close__c
                        FROM        Case
                        WHERE       AssetId = :objReport.Asset__c
                        AND         CreatedDate = LAST_N_DAYS:365
                        ORDER BY    AssetId, CreatedDate DESC
                ]);

                List<Alarm_history__c> listAlarmHistories = new List<Alarm_history__c>([
                        SELECT Error_alarm__c
                        FROM Alarm_history__c
                        WHERE Asset__c = :objReport.Asset__c
                ]);
                System.debug('listAlarmHistories :: ' + listAlarmHistories.size());

                Set<Id> setErrorAlarmId = new Set<Id>();
                for (Alarm_history__c obj : listAlarmHistories) {
                    setErrorAlarmId.add(obj.Error_alarm__c);
                }

                List<Error_alarm__c> listErrorAlarm = new List<Error_alarm__c>([
                        SELECT Id, Code_L__c, Code_M__c, Code_Name_L__c, Code_Name_M__c, Alarm_Ex__c,
                                Occurrence__c, Expectation_1st__c, Expectation_2nd__c, Expectation_3rd__c,
                                Message__c, Reason_1__c, Reason_2__c, Reason_3__c
                        FROM Error_alarm__c
                        WHERE Id = :setErrorAlarmId
                ]);

                String strSystemPrompt = buildSystemPrompt();
                String strUserPrompt = buildUserPrompt(objReport, listCheckItem, listProduct, listCase, listErrorAlarm);

                Gemini2_5FlashApiController.Gemini2_5Request geminiRequest = new Gemini2_5FlashApiController.Gemini2_5Request(strSystemPrompt, strUserPrompt, null);
                geminiRequest.generationConfig.temperature = 0.0;
                geminiRequest.generationConfig.maxOutputTokens = 60000;
                geminiRequest.generationConfig.responseMimeType = 'application/json';
                geminiRequest.generationConfig.responseSchema = getProcessActionRecAndProduct();
                String strResponse = Gemini2_5FlashApiController.askGemini2_5Flash(geminiRequest);

                if (String.isNotBlank(strResponse)) {
                    mapReturn = processGeminiResponse(strResponse);
                    System.debug('strResponse : ' + JSON.serializePretty(strResponse));
                } else {
                    mapReturn.put('hasPredictions', false);
                    mapReturn.put('message', 'Gemini API로부터 유효한 응답을 받지 못했습니다.');
                    System.debug(LoggingLevel.WARN, 'Gemini API received no valid response.');
                }

            } else {
                mapReturn.put('status', 'ERROR');
                mapReturn.put('message', 'No item IDs provided for update.');
            }
        } catch (Exception e) {
            System.debug('General Error updating SelfCheckItem__c: ' + e.getMessage());
            throw new AuraHandledException('An unexpected error occurred: ' + e.getMessage());
        }
        return mapReturn;
    }

    private static String buildSystemPrompt() {
        return '당신은 산업용 사출성형기의 고장 및 위험 예측 전문가입니다. ' +
                '사출성형기의 구조, 작동 원리, 일반적인 고장 패턴에 대한 깊은 지식을 보유하고 있으며, ' +
                'Error Alarm 데이터와 Case 데이터를 분석하여 향후 1-2개월 내 발생할 수 있는 ' +
                '기계적 고장, 성능 저하, 부품 마모 등의 위험을 정확히 예측할 수 있습니다. ' +
                '데이터 패턴을 기반으로 근본 원인을 파악하고, 예방 정비 방안을 제시하며, ' +
                '비용 효과적인 해결책을 도출하는 것이 당신의 전문 분야입니다. ' +
                '고객에게는 LSMtron의 위험 분석 전문 Agent라는 브랜드 이미지로 소개되지만, ' +
                '실제로는 사출성형기 분야의 깊은 기술적 전문성을 바탕으로 분석을 수행합니다. ' +
                '응답은 반드시 지정된 JSON 스키마 형식을 정확히 따라야 합니다.';
    }
    private static String buildUserPrompt(
            RiskAnalyzeReport__c objReport,
            List<SelfCheckItem__c> listCheckItem,
            List<Product2> listProduct,
            List<Case> listCase,
            List<Error_alarm__c> listErrorAlarm
    ) {

        String prompt = '🔍 **사출성형기 위험 분석 요청** 🔍\n\n';
        prompt += '🏭 **[ASSET 정보: ' + objReport.Asset__c + ']**\n';
        prompt += '• Asset 제조일자: ' + (objReport.Asset__r.ManufactureDate != null ? objReport.Asset__r.ManufactureDate.format() : 'N/A') + '\n';
        prompt += '• Asset 설치일자: ' + (objReport.Asset__r.InstallDate != null ? objReport.Asset__r.InstallDate.format() : 'N/A') + '\n\n';

        prompt += '🚨 **[SelfCheckItem 시작]**\n';
        Integer selectNum = 1;
        for (SelfCheckItem__c sc : listCheckItem) {
            prompt += '--- Self Check  #' + selectNum + ' ---\n';
            prompt += '• 설명: ' + sc.Description__c + '\n';
            prompt += '• 체크여부: ' + sc.IsChecked__c + '\n';
            prompt += '-------------------------\n';
            selectNum++;
        }
        prompt += '🚨 **[SelfCheckItem 데이터 종료]**\n\n';

        prompt += '🚨 **[CASE 데이터 시작]**\n';
        Integer caseNum = 1;
        for (Case c : listCase) {
            prompt += '--- Case #' + caseNum + ' ---\n';
            prompt += '• 제목: ' + c.Subject + '\n';
            prompt += '• 설명: ' + c.Description + '\n';
            prompt += '• 고장유형: ' + (c.malfuction_type__c != null ? c.malfuction_type__c : 'N/A') + '\n';
            prompt += '• 고장상세: ' + (c.Malfunction_Type_Detail__c != null ? c.Malfunction_Type_Detail__c : 'N/A') + '\n';
            prompt += '• 부품코드: ' + (c.Part_Code__c != null ? c.Part_Code__c : 'N/A') + '\n';
            prompt += '• 부품명: ' + (c.Part_Name__c != null ? c.Part_Name__c : 'N/A') + '\n';
            prompt += '• 생성일: ' + (c.Date_Time_Open__c != null ? String.valueOf(c.Date_Time_Open__c) : 'N/A') + '\n';
            prompt += '• 종료일: ' + (c.Date_Time_Close__c != null ? String.valueOf(c.Date_Time_Close__c) : 'N/A') + '\n';

            prompt += '-------------------------\n';
            caseNum++;
        }
        prompt += '🚨 **[CASE 데이터 종료]**\n\n';

        prompt += '⚠️ **[ERROR ALARM 데이터 시작]**\n';
        Integer alarmNum = 1;
        for (Error_alarm__c alarm : listErrorAlarm) {
            prompt += '--- Alarm #' + alarmNum + ' ---\n';
            prompt += '• 코드: ' + alarm.Code_L__c + '-' + alarm.Code_M__c + '\n';
            prompt += '• 알람명: ' + (alarm.Code_Name_M__c != null ? alarm.Code_Name_M__c : 'N/A') + '\n';
            prompt += '• 설명: ' + (alarm.Alarm_Ex__c != null ? alarm.Alarm_Ex__c : 'N/A') + '\n';
            prompt += '• 발생횟수: ' + (alarm.Occurrence__c != null ? alarm.Occurrence__c : 0) + '\n';
            prompt += '• 원인1: ' + (alarm.Reason_1__c != null ? alarm.Reason_1__c : 'N/A') + '\n';
            prompt += '• 원인2: ' + (alarm.Reason_2__c != null ? alarm.Reason_2__c : 'N/A') + '\n';
            prompt += '• 예상결과1: ' + (alarm.Expectation_1st__c != null ? alarm.Expectation_1st__c : 'N/A') + '\n';
            prompt += '• 예상결과2: ' + (alarm.Expectation_2nd__c != null ? alarm.Expectation_2nd__c : 'N/A') + '\n';
            prompt += '• 메시지: ' + (alarm.Message__c != null ? alarm.Message__c : 'N/A') + '\n';
            prompt += '-------------------------\n';
            alarmNum++;
        }
        prompt += '⚠️ **[ERROR ALARM 데이터 종료]**\n\n';

        prompt += '⚠️ **[Product 데이터 시작]**\n';
        Integer productNum = 1;
        for (Product2 objProduct: listProduct) {
            prompt += '--- objProduct #' + productNum + ' ---\n';
            prompt += '• 부품명: ' + (objProduct.Name != null ? objProduct.Name : 'N/A') + '\n';
            prompt += '• 부품코드: ' + (objProduct.ProductCode != null ? objProduct.ProductCode : 'N/A') + '\n';
            prompt += '• 가격: ' + (objProduct.Price__c != null ? objProduct.Price__c.format() : 'N/A') + '\n';
            prompt += '• 재고여부: ' + (objProduct.Stock__c != null ? objProduct.Stock__c : 'N/A') + '\n';
            prompt += '• 재고수: ' + (objProduct.Quantity__c != null ? objProduct.Quantity__c.format() : 'N/A') + '\n';
            prompt += '• 교체주기: ' + (objProduct.Replacement_Cycle__c != null ? objProduct.Replacement_Cycle__c : 'N/A') + '\n';
            prompt += '-------------------------\n';
            productNum++;
        }
        prompt += '⚠️ **[Product 데이터 종료]**\n\n';
        prompt += '🔚 **[사출성형기 위험 분석 요청 완료]**\n';
        prompt += '==========================================\n\n';

        prompt += '✅ **[분석 요구사항]**\n\n';
        prompt += '📧 **1. 자가 점검 결과 기반 행동 추천:**\n';
        prompt += '     - **reportId (String):** 현재 분석 중인 RiskAnalyzeReport__c 레코드의 Id.\n'; // ✨ 새로 추가된 필드 ✨
        prompt += '     - **analysisSummary (String):** 고객의 자가 점검 `IsChecked__c` 값이 `true`인 항목들을 종합적으로 분석하여 현재 기계 상태에 대한 요약과 잠재적 문제점을 설명합니다. ' +
                '특히 `false`인 항목이 있다면, 이는 정상적인 상태를 의미하므로, `true`인 항목에 더욱 집중하여 분석합니다.\n';
        prompt += '     - **recommendedActions (Array of Objects):** 고객의 자가 점검 결과(`IsChecked__c`가 `true`인 항목)와 제공된 Case, Error Alarm 데이터를 바탕으로 구체적인 행동 추천 목록을 생성합니다.\n';
        prompt += '         - **actionIndex (Integer):** 각 추천 행동의 고유 인덱스.\n';
        prompt += '         - **faultType (String):** 예측되는 고장 유형 (예: "M)제어(알람/동작이상)"). Case 데이터의 `malfuction_type__c` 또는 Error Alarm의 `Code_Name_M__c`를 참고합니다.\n';
        prompt += '         - **faultDetailType (String):** 고장 세부 유형 (예: "M01)통신알람", "L03)유압유 누유"). Case 데이터의 `Malfunction_Type_Detail__c` 또는 Error Alarm의 `Alarm_Ex__c`를 참고합니다.\n';
        prompt += '         - **faultReason (String):** 예상되는 고장 원인 (예: "CC10)사용/부품/기능고장", "오일 열화", "센서 오작동"). Error Alarm의 `Reason_1__c`, `Reason_2__c` 또는 Case의 `Description`을 참고하여 추론합니다.\n';
        prompt += '         - **faultLocation (String):** 결함 예상 위치 (예: "EL)전장", "HY)유압부", "MO)모터부"). Case나 Error Alarm 데이터에서 유추하거나, 자가 점검 질문의 내용을 기반으로 판단합니다.\n';
        prompt += '         - **actionDescription (String):** 해당 고장 유형 및 원인에 대한 구체적이고 실행 가능한 행동 추천 내용. (예: "제어반 내부 팬 점검 및 먼지 제거, 필요시 열화상 카메라로 온도 측정", "유압유 상태 점검 및 교체", "관련 센서 단자부 청소 및 재연결").\n';
        prompt += '         - **partsNeeded (Array of Objects):** 해당 조치에 필요할 수 있는 Product2 레코드의 **`Product__c` (Id)와 `productCode`를 포함하는 객체 배열**. 제공된 Product2 데이터에서, 관련된 부품의 `Id`를 `Product__c`로, `ProductCode`를 `productCode`로 포함합니다.\n\n'; // ✨ 지침 변경 ✨

        prompt += '🎯 **[주요 지침]**\n';
        prompt += '• 제공된 **자가 점검 결과(listCheckItem)**에서 `IsChecked__c`가 `true`인 항목들을 핵심적으로 분석합니다.\n';
        prompt += '• `true`로 응답된 자가 점검 항목과 과거 Case, Error Alarm 데이터를 상호 참조하여, 어떤 고장 유형 및 원인이 현재 발생하고 있거나 발생할 가능성이 높은지 추론합니다.\n';
        prompt += '• 각 예측된 문제에 대해 요구된 항목들(faultType, faultDetailType, faultReason, faultLocation, actionDescription, partsNeeded)을 상세하게 채워야 합니다.\n';
        prompt += '• `actionDescription`은 고객이 직접 수행할 수 있는 자가 점검/예방 정비 관점에서 구체적으로 작성합니다.\n';
        prompt += '• `partsNeeded`는 Product2 데이터에서 관련 부품을 찾아 **해당 부품의 `Id`는 `Product__c` 필드에, `ProductCode`는 `productCode` 필드에 포함하는 객체(`{"Product__c": "...", "productCode": "..."}`) 형태로 제공**합니다. 해당 부품이 없으면 빈 배열로 둡니다.\n'; // ✨ 지침 변경 ✨
        prompt += '• 모든 내용은 한국어로 작성합니다.\n\n';
        prompt += '⭐ 응답 형식:** {"selfCheckReport": {...}}';

        return prompt;
    }

    private static Map<String, Object> getProcessActionRecAndProduct() {
        return new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                        'selfCheckReport' => new Map<String, Object>{
                                'type' => 'object',
                                'properties' => new Map<String, Object>{
                                        'reportId' => new Map<String, Object>{'type' => 'string', 'description' => '연관된 RiskAnalyzeReport__c 레코드의 Id'}, // ✨ 새로 추가된 필드 ✨
                                        'analysisSummary' => new Map<String, Object>{
                                                'type' => 'string',
                                                'description' => '고객의 자가 점검 결과를 종합하여 현재 기계 상태와 잠재적 문제점을 설명하는 요약'
                                        },
                                        'recommendedActions' => new Map<String, Object>{
                                                'type' => 'array',
                                                'items' => new Map<String, Object>{
                                                        'type' => 'object',
                                                        'properties' => new Map<String, Object>{
                                                                'actionIndex' => new Map<String, Object>{'type' => 'integer', 'description' => '각 추천 행동의 고유 인덱스'},
                                                                'faultType' => new Map<String, Object>{'type' => 'string', 'description' => '예측되는 고장 유형'},
                                                                'faultDetailType' => new Map<String, Object>{'type' => 'string', 'description' => '고장 세부 유형'},
                                                                'faultReason' => new Map<String, Object>{'type' => 'string', 'description' => '예상되는 고장 원인'},
                                                                'faultLocation' => new Map<String, Object>{'type' => 'string', 'description' => '결함 예상 위치'},
                                                                'actionDescription' => new Map<String, Object>{'type' => 'string', 'description' => '구체적인 행동 추천 내용'},
                                                                'partsNeeded' => new Map<String, Object>{
                                                                        'type' => 'array',
                                                                        'items' => new Map<String, Object>{
                                                                                'type' => 'object',
                                                                                'properties' => new Map<String, Object>{
                                                                                        'Product__c' => new Map<String, Object>{'type' => 'string', 'description' => 'Product2 레코드의 Id'},
                                                                                        'productCode' => new Map<String, Object>{'type' => 'string', 'description' => 'Product2 레코드의 ProductCode'}
                                                                                },
                                                                                'required' => new List<String>{'Product__c', 'productCode'}
                                                                        },
                                                                        'description' => '해당 조치에 필요할 수 있는 Product2 레코드의 Id 및 ProductCode 목록'
                                                                }
                                                        },
                                                        'required' => new List<String>{
                                                                'actionIndex',
                                                                'faultType',
                                                                'faultDetailType',
                                                                'faultReason',
                                                                'faultLocation',
                                                                'actionDescription',
                                                                'partsNeeded'
                                                        }
                                                }
                                        }
                                },
                                'required' => new List<String>{'reportId', 'analysisSummary', 'recommendedActions'}
                        }
                },
                'required' => new List<String>{'selfCheckReport'}
        };
    }

    private static Map<String, Object> processGeminiResponse(String jsonResponse) {
        Map<String, Object> returnMap = new Map<String, Object>();
        returnMap.put('hasPredictions', false); // Default to no predictions

        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

            // 'errorReportResults' 대신 'selfCheckReport'를 가져옵니다.
            Map<String, Object> selfCheckReport = (Map<String, Object>) responseMap.get('selfCheckReport');

            if (selfCheckReport == null || selfCheckReport.isEmpty()) {
                returnMap.put('message', 'No selfCheckReport found in Gemini response.');
                System.debug('No selfCheckReport found in response.');
                return returnMap;
            }

            // 'riskItems' 대신 'recommendedActions'를 가져옵니다.
            List<Object> recommendedActions = (List<Object>) selfCheckReport.get('recommendedActions');

            if (recommendedActions == null || recommendedActions.isEmpty()) {
                returnMap.put('message', 'No recommendedActions found in selfCheckReport.');
                return returnMap;
            }

            // 선택 사항: reportId도 가져와서 LWC로 전달할 수 있습니다.
            String reportId = (String) selfCheckReport.get('reportId');
            if (reportId != null) {
                returnMap.put('reportId', reportId);
            }

            // 선택 사항: analysisSummary도 가져와서 LWC로 전달할 수 있습니다.
            String analysisSummary = (String) selfCheckReport.get('analysisSummary');
            if (analysisSummary != null) {
                returnMap.put('analysisSummary', analysisSummary);
            }

            List<Map<String, Object>> displayRecommendedActions = new List<Map<String, Object>>();

            for (Object actionObj : recommendedActions) {
                Map<String, Object> actionItem = (Map<String, Object>) actionObj;

                Map<String, Object> itemToDisplay = new Map<String, Object>(); // Object 타입으로 변경하여 List<Object>를 저장할 수 있도록 함
                // Safely get string values for display, handling potential nulls
                itemToDisplay.put('id', String.valueOf(actionItem.get('actionIndex'))); // LWC의 key prop을 위해 id 추가
                itemToDisplay.put('actionIndex', actionItem.get('actionIndex'));
                itemToDisplay.put('faultType', String.valueOf(actionItem.get('faultType')));
                itemToDisplay.put('faultDetailType', String.valueOf(actionItem.get('faultDetailType')));
                itemToDisplay.put('faultReason', String.valueOf(actionItem.get('faultReason')));
                itemToDisplay.put('faultLocation', String.valueOf(actionItem.get('faultLocation')));
                itemToDisplay.put('actionDescription', String.valueOf(actionItem.get('actionDescription')));

                // partsNeeded 처리 (리스트 내부에 Map<String, String> 형태)
                List<Object> partsNeededRaw = (List<Object>) actionItem.get('partsNeeded');
                List<Map<String, String>> partsNeededFormatted = new List<Map<String, String>>();
                if (partsNeededRaw != null) {
                    for (Object partObj : partsNeededRaw) {
                        Map<String, Object> partMap = (Map<String, Object>) partObj;
                        Map<String, String> formattedPart = new Map<String, String>();
                        formattedPart.put('Product__c', String.valueOf(partMap.get('Product__c'))); // Product2 Id
                        formattedPart.put('productCode', String.valueOf(partMap.get('productCode'))); // ProductCode
                        // RiskAnalyzeReport__c는 partsNeeded 내부 객체에 포함하는 경우 여기에 추가
                        // formattedPart.put('RiskAnalyzeReport__c', String.valueOf(partMap.get('RiskAnalyzeReport__c')));
                        partsNeededFormatted.add(formattedPart);
                    }
                }
                itemToDisplay.put('partsNeeded', partsNeededFormatted); // LWC로 전달할 partsNeeded

                displayRecommendedActions.add(itemToDisplay);
            }

            returnMap.put('hasPredictions', true);
            returnMap.put('recommendedActions', displayRecommendedActions); // 'riskItems' 대신 'recommendedActions'
            returnMap.put('message', '성공적으로 자가 점검 기반 행동 추천 데이터를 로드했습니다.');

            System.debug('Total recommended actions: ' + displayRecommendedActions.size());

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing Gemini response for display: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            returnMap.put('message', '데이터 처리 중 오류가 발생했습니다: ' + e.getMessage());
        }

        System.debug('returnMap : ' + JSON.serializePretty(returnMap));
        return returnMap;
    }
}