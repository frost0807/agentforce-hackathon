/************************************************************************************
* File Name   	    : ErrorReportController
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
public with sharing class ErrorReportController {
    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> getInit(String uuid) {
        System.debug('getInit start');
        Map<String, Object> mapReturn = new Map<String, Object>();
        if (String.isBlank(uuid)) return null;

        try {
            RiskAnalyzeReport__c objReport = [
                    SELECT Id, MailContent__c, MailSubject__c, Account__c, Asset__c, Asset__r.Product2Id, Asset__r.ManufactureDate, Asset__r.InstallDate, Asset__r.Product2.Name
                    FROM RiskAnalyzeReport__c
                    WHERE UUID__c =: uuid
                    LIMIT 1
            ];
            // WHERE UUID__c = :uuid AND Account__c = '001Qy0000172T51IAE'
            System.debug('objReport :: ' + JSON.serializePretty(objReport));
            List<Case> listCase = new List<Case>([
                    SELECT Id, AssetId, Subject, Description, Part_Code__c, Part_Name__c, malfuction_type__c
                            , Malfunction_Type_Detail__c, CreatedDate, Fault_Code__c, Manufacturer__c, Price__c
                            , Date_Time_Open__c, Date_Time_Close__c
                    FROM Case
                    WHERE AssetId = :objReport.Asset__c
                    AND CreatedDate = LAST_N_DAYS:365
                    ORDER BY AssetId, CreatedDate DESC
            ]);
            System.debug('listCase :: ' + listCase.size());

            Set<String> setString = new Set<String>();
            for (Case obj : listCase) {
                setString.add(obj.Part_Code__c);
            }

            List<Product2> listProduct = new List<Product2>([
                    SELECT Id, Name, ProductCode, Price__c,  Stock__c, Quantity__c, Replacement_Cycle__c
                    FROM Product2
                    WHERE ProductCode = :setString AND Family = :objReport.Asset__r.Product2.Name
            ]);
            System.debug('listProduct :: ' + listProduct.size());

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
            System.debug('listErrorAlarm :: ' + listErrorAlarm.size());

            String strSystemPrompt = buildSystemPrompt();
            String strUserPrompt = buildUserPrompt(objReport, listProduct, listCase, listErrorAlarm);

            Gemini2_5FlashApiController.Gemini2_5Request geminiRequest = new Gemini2_5FlashApiController.Gemini2_5Request(strSystemPrompt, strUserPrompt, null);
            geminiRequest.generationConfig.temperature = 0.0;
            geminiRequest.generationConfig.maxOutputTokens = 60000;
            geminiRequest.generationConfig.responseMimeType = 'application/json';
            geminiRequest.generationConfig.responseSchema = getErrorReportResponseSchema();
            String strResponse = Gemini2_5FlashApiController.askGemini2_5Flash(geminiRequest);

            if (String.isNotBlank(strResponse)) {
                mapReturn = processGeminiResponse(strResponse);
                System.debug('strResponse : ' + JSON.serializePretty(strResponse));
            } else {
                mapReturn.put('hasPredictions', false);
                mapReturn.put('message', 'Gemini API로부터 유효한 응답을 받지 못했습니다.');
                System.debug(LoggingLevel.WARN, 'Gemini API received no valid response.');
            }
        }catch (Exception e){
            System.debug(LoggingLevel.ERROR, 'Error in getInit: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            mapReturn.put('hasPredictions', false);
            mapReturn.put('message', '데이터 로드 중 오류가 발생했습니다: ' + e.getMessage());
        }

        System.debug('getInit end. Returning map: ' + JSON.serializePretty(mapReturn));
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
            List<Product2> listProduct,
            List<Case> listCase,
            List<Error_alarm__c> listErrorAlarm
    ) {

        String prompt = '🔍 **사출성형기 위험 분석 요청** 🔍\n\n';
        prompt += '🏭 **[ASSET 정보: ' + objReport.Asset__c + ']**\n';
        prompt += '• Asset 제조일자: ' + (objReport.Asset__r.ManufactureDate != null ? objReport.Asset__r.ManufactureDate.format() : 'N/A') + '\n';
        prompt += '• Asset 설치일자: ' + (objReport.Asset__r.InstallDate != null ? objReport.Asset__r.InstallDate.format() : 'N/A') + '\n\n';

        prompt += '🏭 **[메일 정보]**\n';
        prompt += '• 메일 제목: ' + (objReport.MailSubject__c != null ? objReport.MailSubject__c : 'N/A') + '\n';
        prompt += '• 메일 세부내용: ' + (objReport.MailContent__c != null ? objReport.MailContent__c : 'N/A') + '\n\n';

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
//            prompt += '• 생성일: ' + alarm.CreatedDate + '\n';
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
        prompt += '📧 **1. 예측 에러증상 리스트 요구사항:**\n';
        prompt += '     - **riskItems (Array of Objects):** 예측된 각 위험 항목을 나타내는 배열\n';
        prompt += '     - **faultSeverityLevel (String):** 고장 심각도 수준 (예: "매우 높음", "높음", "보통", "낮음").\n';
        prompt += '     - **expectedFaultDate (String):** 고장 예측일 (YYYY-MM-DD 형식).\n';
        prompt += '     - **componentName (String):** 관련 부품명 (예: Product2 의 ProductCode )\n';
        prompt += '     - **componentLifeExpectancy (String):** 부품 수명 (예: "잔여 수명 3개월", "교체 주기 도래").\n';
        prompt += '     - **usageAnalysis (String):** 사용량 분석 (예: "과도한 사이클 사용", "정상 범위 내 사용").\n';
        prompt += '     - **faultHistorySummary (String):** 고장 이력 분석 요약 (관련 과거 Case 및 Alarm 데이터 기반).\n';
        prompt += '     - **recommendedAction (String):** 해당 위험에 대한 권장 조치 사항 (예: "점검 필요", "부품 교체 권장", "설정 조정").\n';
        prompt += '     - **riskReason (String):** 예측된 위험의 주요 원인 요약.\n';
        prompt += '     - **impactDescription (String):** 고장 발생 시 예상되는 영향 (예: "생산 지연 2일 예상", "수리 비용 약 500만원 발생").\n\n';
        prompt += '     - **selfRepairCost (Number):** 해당 고장 발생 시 **자가 수리**로 진행할 경우 예상되는 총 비용 (단위: 원). 자가 수리가 불가능하거나 비현실적일 경우 0으로 표기합니다.\n';
        prompt += '     - **externalRepairCost (Number):** 해당 고장 발생 시 **외부 업체 수리**로 진행할 경우 예상되는 총 비용 (단위: 원). 외부 수리가 불가능하거나 비현실적일 경우 0으로 표기합니다.\n';
        prompt += '     - **costComparisonMessage (String):** 자가 수리 비용과 외부 수리 비용을 비교하여 자가 수리의 이점을 강조하는 메시지. (예: "자가 수리 시 약 30% 비용 절감 가능성이 있습니다.", "외부 수리 대비 약 20만원 절약됩니다.")\n\n';

        prompt += '🎯 **[주요 지침]**\n';
        prompt += '• 제공된 Error Alarm 및 Case 데이터를 면밀히 분석하여 예측되는 고장 증상들을 도출합니다.\n';
        prompt += '• 각 예측 에러 증상에 대해 요구된 항목들을 상세하게 채워야 합니다.\n';
        prompt += '• 예측은 향후 1-2개월 내 발생할 수 있는 위험에 초점을 맞춥니다.\n';
        prompt += '• 분석 결과는 실질적인 유지보수 계획 수립에 도움이 되어야 합니다.\n';
        prompt += '• **가장 중요한 지침: 자가 수리 비용 (selfRepairCost)과 외부 수리 비용 (externalRepairCost)을 반드시 구분하여 예측하고, 둘 중 자가 수리가 더 저렴한 경우 costComparisonMessage를 통해 그 이점을 명확히 강조합니다.**\n';
        prompt += '• 해당 데이터 목적은 고장 위험을 알리고 자가수리를 유도하기 위함입니다. \n';
        prompt += '• 자가수리, 외부수리 가격 비교를 통해 자가수리가 가성비 있는 행동이라는 것을 알리기 위함입니다. \n';
        prompt += '• 모든 내용은 한국어로 작성합니다.\n\n';

        prompt += '⭐ 응답 형식:** {"errorReportResults": {"riskItems": [...]}}';

        return prompt;
    }

    private static Map<String, Object> getErrorReportResponseSchema() {
        return new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                        'errorReportResults' => new Map<String, Object>{
                                'type' => 'object',
                                'properties' => new Map<String, Object>{
                                        'riskItems' => new Map<String, Object>{
                                                'type' => 'array',
                                                'items' => new Map<String, Object>{
                                                        'type' => 'object',
                                                        'properties' => new Map<String, Object>{
                                                                'faultSeverityLevel' => new Map<String, Object>{'type' => 'string', 'description' => '고장 심각도 수준'},
                                                                'expectedFaultDate' => new Map<String, Object>{'type' => 'string', 'description' => '고장 예측일 (YYYY-MM-DD)'},
                                                                'componentName' => new Map<String, Object>{'type' => 'string', 'description' => '관련 부품명'},
                                                                'componentLifeExpectancy' => new Map<String, Object>{'type' => 'string', 'description' => '부품 수명'},
                                                                'usageAnalysis' => new Map<String, Object>{'type' => 'string', 'description' => '사용량 분석'},
                                                                'faultHistorySummary' => new Map<String, Object>{'type' => 'string', 'description' => '고장 이력 분석 요약'},
                                                                'recommendedAction' => new Map<String, Object>{'type' => 'string', 'description' => '권장 조치 사항'},
                                                                'riskReason' => new Map<String, Object>{'type' => 'string', 'description' => '예측된 위험의 주요 원인'},
                                                                'impactDescription' => new Map<String, Object>{'type' => 'string', 'description' => '고장 발생 시 예상되는 영향'},
                                                                'selfRepairCost' => new Map<String, Object>{'type' => 'number', 'description' => '자가 수리 시 예상 비용 (원)'},
                                                                'externalRepairCost' => new Map<String, Object>{'type' => 'number', 'description' => '외부 수리 시 예상 비용 (원)'},
                                                                'costComparisonMessage' => new Map<String, Object>{'type' => 'string', 'description' => '자가 수리와 외부 수리 비용 비교 메시지'}
                                                        },
                                                        'required' => new List<String>{
                                                                'faultSeverityLevel',
                                                                'expectedFaultDate',
                                                                'componentName',
                                                                'componentLifeExpectancy',
                                                                'usageAnalysis',
                                                                'faultHistorySummary',
                                                                'recommendedAction',
                                                                'riskReason',
                                                                'impactDescription',
                                                                'selfRepairCost',
                                                                'externalRepairCost',
                                                                'costComparisonMessage'
                                                        }
                                                }
                                        }
                                },
                                'required' => new List<String>{'riskItems'}
                        }
                },
                'required' => new List<String>{'errorReportResults'}
        };
    }

    private static Map<String, Object> processGeminiResponse(String jsonResponse) {
        Map<String, Object> returnMap = new Map<String, Object>();
        returnMap.put('hasPredictions', false); // Default to no predictions

        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

            Map<String, Object> errorReportResults = (Map<String, Object>) responseMap.get('errorReportResults');

            if (errorReportResults == null || errorReportResults.isEmpty()) {
                returnMap.put('message', 'No errorReportResults found in Gemini response.');
                System.debug('No errorReportResults found in response.');
                return returnMap;
            }

            List<Object> riskItems = (List<Object>) errorReportResults.get('riskItems');

            if (riskItems == null || riskItems.isEmpty()) {
                returnMap.put('message', 'No riskItems found in errorReportResults.');
                return returnMap;
            }

            List<Map<String, String>> displayRiskItems = new List<Map<String, String>>();

            for (Object riskItemObj : riskItems) {
                Map<String, Object> riskItem = (Map<String, Object>) riskItemObj;

                Map<String, String> itemToDisplay = new Map<String, String>();
                // Safely get string values for display, handling potential nulls
                itemToDisplay.put('faultSeverityLevel', String.valueOf(riskItem.get('faultSeverityLevel')));
                itemToDisplay.put('expectedFaultDate', String.valueOf(riskItem.get('expectedFaultDate')));
                itemToDisplay.put('componentName', String.valueOf(riskItem.get('componentName')));
                itemToDisplay.put('componentLifeExpectancy', String.valueOf(riskItem.get('componentLifeExpectancy')));
                itemToDisplay.put('usageAnalysis', String.valueOf(riskItem.get('usageAnalysis')));
                itemToDisplay.put('faultHistorySummary', String.valueOf(riskItem.get('faultHistorySummary')));
                itemToDisplay.put('recommendedAction', String.valueOf(riskItem.get('recommendedAction')));
                itemToDisplay.put('riskReason', String.valueOf(riskItem.get('riskReason')));
                itemToDisplay.put('impactDescription', String.valueOf(riskItem.get('impactDescription')));

                Object selfRepairCostObj = riskItem.get('selfRepairCost');
                if (selfRepairCostObj != null) {
                    itemToDisplay.put('selfRepairCost', String.valueOf(selfRepairCostObj));
                } else {
                    itemToDisplay.put('selfRepairCost', '0');
                }

                Object externalRepairCostObj = riskItem.get('externalRepairCost');
                if (externalRepairCostObj != null) {
                    itemToDisplay.put('externalRepairCost', String.valueOf(externalRepairCostObj));
                } else {
                    itemToDisplay.put('externalRepairCost', '0');
                }

                itemToDisplay.put('costComparisonMessage', String.valueOf(riskItem.get('costComparisonMessage')));

                displayRiskItems.add(itemToDisplay);
            }

            returnMap.put('hasPredictions', true);
            returnMap.put('riskItems', displayRiskItems);
            returnMap.put('message', '성공적으로 예측 데이터를 로드했습니다.');

            System.debug('Total ' + displayRiskItems.size());

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing Gemini response for display: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            returnMap.put('message', '데이터 처리 중 오류가 발생했습니다: ' + e.getMessage());
        }

        System.debug('returnMap : ' + JSON.serializePretty(returnMap));
        return returnMap;
    }
}