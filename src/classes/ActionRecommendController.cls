/************************************************************************************
* File Name   	    : ActionRecommendController
* Author	  		: Jiae.Tak
* Date				: 2025-06-04
* Tester	  		:
* Target	  		:
* Description 	    : Updated for HTML/Document download with PDF corruption fix
* Modification Log
* ===================================================================================
* Ver      Date            Author          Modification
* ===================================================================================
* 1.0      2025-06-04         Jiae.Tak          Create
* 1.1      2025-06-08         Updated           Change to Document-based approach
* 1.2      2025-06-08         Updated           Fix PDF corruption issues
************************************************************************************/
public with sharing class ActionRecommendController {
    @AuraEnabled
    public static Map<String, Object> processActionRecAndProduct(Id reportId) {
        Map<String, Object> mapReturn = new Map<String, Object>();
        if (String.isBlank(reportId)) return null;
        try {
            RiskAnalyzeReport__c objReport = [
                    SELECT Id, MailContent__c, MailSubject__c, Account__c, Asset__c, Asset__r.Product2Id, Asset__r.ManufactureDate, Asset__r.InstallDate, Asset__r.Product2.Name
                    FROM RiskAnalyzeReport__c
                    WHERE Id = :reportId
                    LIMIT 1
            ];

            List<ActionRecommendation__c> listActionRecommendation = new List<ActionRecommendation__c>([
                    SELECT Id, AnalysisSummary__c
                    FROM ActionRecommendation__c
                    WHERE RiskAnalyzeReport__c = :objReport.Id
                    LIMIT 1
            ]);

            if (!listActionRecommendation.isEmpty()) {
                System.debug('존재함!');
                ActionRecommendation__c objActionRecommendation = listActionRecommendation[0];

                List<ActionRecommendationItem__c> listActionRecommendationItems = new List<ActionRecommendationItem__c>([
                        SELECT Id, faultDetailType__c, faultLocation__c, actionIndex__c, actionDescription__c, faultType__c, faultReason__c, isChecked__c
                        FROM ActionRecommendationItem__c
                        WHERE ActionRecommendation__c = :objActionRecommendation.Id
                ]);

                // SelectedPartItem__c 를 효율적으로 조회하기 위해 ActionRecommendationItem__c ID들을 수집
                Set<Id> setActionItemIds = new Set<Id>();
                for (ActionRecommendationItem__c obj : listActionRecommendationItems) {
                    setActionItemIds.add(obj.Id);
                }

                // ActionRecommendationItem__c ID를 기준으로 SelectedPartItem__c 조회
                List<SelectedPartItem__c> listSelectedPartItems = new List<SelectedPartItem__c>();
                if (!setActionItemIds.isEmpty()) {
                    listSelectedPartItems = [
                            SELECT Id, Product__c, PartCode__c, Quantity__c, ActionRecommendationItem__c, Product__r.ProductCode
                            FROM SelectedPartItem__c
                            WHERE ActionRecommendationItem__c IN :setActionItemIds
                    ];
                }

                // SelectedPartItem__c를 ActionRecommendationItem__c ID별로 그룹화
                Map<Id, List<SelectedPartItem__c>> mapPartsByActionItem = new Map<Id, List<SelectedPartItem__c>>();
                for (SelectedPartItem__c part : listSelectedPartItems) {
                    if (!mapPartsByActionItem.containsKey(part.ActionRecommendationItem__c)) {
                        mapPartsByActionItem.put(part.ActionRecommendationItem__c, new List<SelectedPartItem__c>());
                    }
                    mapPartsByActionItem.get(part.ActionRecommendationItem__c).add(part);
                }

                // processGeminiResponse와 동일한 구조로 데이터 구성
                mapReturn.put('hasPredictions', true);
                mapReturn.put('analysisSummary', objActionRecommendation.AnalysisSummary__c);
                mapReturn.put('actionRecommendationId', objActionRecommendation.Id);

                List<Map<String, Object>> displayRecommendedActions = new List<Map<String, Object>>();
                for (ActionRecommendationItem__c actionItem : listActionRecommendationItems) {
                    Map<String, Object> itemToDisplay = new Map<String, Object>();
                    itemToDisplay.put('Id', actionItem.Id);
                    itemToDisplay.put('actionIndex', actionItem.actionIndex__c);
                    itemToDisplay.put('faultType', actionItem.faultType__c);
                    itemToDisplay.put('faultDetailType', actionItem.faultDetailType__c);
                    itemToDisplay.put('faultReason', actionItem.faultReason__c);
                    itemToDisplay.put('faultLocation', actionItem.faultLocation__c);
                    itemToDisplay.put('actionDescription', actionItem.actionDescription__c);
                    itemToDisplay.put('isChecked', actionItem.isChecked__c);

                    List<Map<String, String>> partsNeededFormatted = new List<Map<String, String>>();
                    List<SelectedPartItem__c> partsForThisAction = mapPartsByActionItem.get(actionItem.Id);
                    if (partsForThisAction != null) {
                        for (SelectedPartItem__c part : partsForThisAction) {
                            Map<String, String> formattedPart = new Map<String, String>();
                            formattedPart.put('Id', part.Id);
                            formattedPart.put('Product__c', part.Product__c);
                            formattedPart.put('productCode', part.Product__r.ProductCode);
                            formattedPart.put('quantity', String.valueOf(part.Quantity__c));
                            partsNeededFormatted.add(formattedPart);
                        }
                    }
                    itemToDisplay.put('partsNeeded', partsNeededFormatted);
                    displayRecommendedActions.add(itemToDisplay);
                }
                mapReturn.put('recommendedActions', displayRecommendedActions);
                mapReturn.put('message', '기존 Action Recommendation 데이터를 성공적으로 로드했습니다.');

                System.debug('Existing Action Recommendation loaded: ' + JSON.serializePretty(mapReturn));

            } else {
                System.debug('존재하지 않음!');

                List<SelfCheckItem__c> listCheckItem = new List<SelfCheckItem__c>([
                        SELECT Id, IsChecked__c, Description__c
                        FROM SelfCheckItem__c
                        WHERE RiskAnalyzeReport__c = :objReport.Id
                ]);
                System.debug('listCheckItem :: ' + listCheckItem);

                List<Product2> listProduct = new List<Product2>([
                        SELECT Id, Name, ProductCode, Price__c, Stock__c, Quantity__c, Replacement_Cycle__c
                        FROM Product2
                        WHERE Family = :objReport.Asset__r.Product2.Name
                ]);
                System.debug('listProduct :: ' + listProduct);

                List<Case> listCase = new List<Case>([
                        SELECT Id, AssetId, Subject, Description, Part_Code__c, Part_Name__c, malfuction_type__c
                                , Malfunction_Type_Detail__c, CreatedDate, Fault_Code__c, Manufacturer__c, Price__c
                                , Date_Time_Open__c, Date_Time_Close__c
                        FROM Case
                        WHERE AssetId = :objReport.Asset__c
                        AND CreatedDate = LAST_N_DAYS:365
                        ORDER BY AssetId, CreatedDate DESC
                ]);
                System.debug('listCase :: ' + listCase);

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
                System.debug('listErrorAlarm :: ' + listErrorAlarm);

                String strSystemPrompt = buildSystemPrompt();
                String strUserPrompt = buildUserPrompt(objReport, listCheckItem, listProduct, listCase, listErrorAlarm);

                Gemini2_5FlashApiController.Gemini2_5Request geminiRequest = new Gemini2_5FlashApiController.Gemini2_5Request(strSystemPrompt, strUserPrompt, null);
                geminiRequest.generationConfig.temperature = 0.0;
                geminiRequest.generationConfig.maxOutputTokens = 60000;
                geminiRequest.generationConfig.responseMimeType = 'application/json';
                geminiRequest.generationConfig.responseSchema = getProcessActionRecAndProduct();
                String strResponse = Gemini2_5FlashApiController.askGemini2_5Flash(geminiRequest);

                if (String.isNotBlank(strResponse)) {
                    mapReturn = processGeminiResponse(objReport, strResponse);
                    mapReturn.put('reportId', objReport.Id);

                    System.debug('strResponse : ' + JSON.serializePretty(strResponse));
                } else {
                    mapReturn.put('hasPredictions', false);
                    mapReturn.put('reportId', objReport.Id);
                    mapReturn.put('message', 'Gemini API로부터 유효한 응답을 받지 못했습니다.');
                    System.debug(LoggingLevel.WARN, 'Gemini API received no valid response.');
                }
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
        for (Product2 objProduct : listProduct) {
            prompt += '--- objProduct #' + productNum + ' ---\n';
            prompt += '• Product2 Id: ' + (objProduct.Id != null ? objProduct.Id : 'N/A') + '\n';
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
        prompt += '     - **analysisSummary (String):** 고객의 자가 점검 `IsChecked__c` 값이 `true`인 항목들을 종합적으로 분석하여 현재 기계 상태에 대한 요약과 잠재적 문제점을 설명합니다. ' +
                '특히 `false`인 항목이 있다면, 이는 정상적인 상태를 의미하므로, `true`인 항목에 더욱 집중하여 분석합니다.\n';
        prompt += '     - **recommendedActions (Array of Objects):** 고객의 자가 점검 결과(`IsChecked__c`가 `true`인 항목)와 제공된 Case, Error Alarm 데이터를 바탕으로 구체적인 행동 추천 목록을 생성합니다.\n';
        prompt += '         - **actionIndex (Integer):** 각 추천 행동의 고유 인덱스.\n';
        prompt += '         - **faultType (String):** 예측되는 고장 유형 (예: "M)제어(알람/동작이상)"). Case 데이터의 `malfuction_type__c` 또는 Error Alarm의 `Code_Name_M__c`를 참고합니다.\n';
        prompt += '         - **faultDetailType (String):** 고장 세부 유형 (예: "M01)통신알람", "L03)유압유 누유"). Case 데이터의 `Malfunction_Type_Detail__c` 또는 Error Alarm의 `Alarm_Ex__c`를 참고합니다.\n';
        prompt += '         - **faultReason (String):** 예상되는 고장 원인 (예: "CC10)사용/부품/기능고장", "오일 열화", "센서 오작동"). Error Alarm의 `Reason_1__c`, `Reason_2__c` 또는 Case의 `Description`을 참고하여 추론합니다.\n';
        prompt += '         - **faultLocation (String):** 결함 예상 위치 (예: "EL)전장", "HY)유압부", "MO)모터부"). Case나 Error Alarm 데이터에서 유추하거나, 자가 점검 질문의 내용을 기반으로 판단합니다.\n';
        prompt += '         - **actionDescription (String):** 해당 고장  유형 및 원인에 대한 구체적이고 실행 가능한 행동 추천 내용. (예: "제어반 내부 팬 점검 및 먼지 제거, 필요시 열화상 카메라로 온도 측정", "유압유 상태 점검 및 교체", "관련 센서 단자부 청소 및 재연결").\n';
        prompt += '         - **partsNeeded (Array of Objects):** 해당 조치에 필요할 수 있는 Product2 레코드의 **`Id`,`productCode`, `quantity` 를 포함하는 객체 배열**. 제공된 Product2 데이터에서 관련된 부품의 `Id`를 `Product__c`로, `productCode`를 `productCode`로, 데이터 분석 후 필요한 부품의 개수를 `quantity`로 포함합니다.\n\n';

        prompt += '🎯 **[주요 지침]**\n';
        prompt += '• 제공된 **SelfCheckItem(listCheckItem)**에서 `IsChecked__c`가 `true`인 항목들을 핵심적으로 분석합니다.\n';
        prompt += '• `true`로 응답된 자가 점검 항목과 과거 Case, Error Alarm 데이터를 상호 참조하여, 어떤 고장 유형 및 원인이 현재 발생하고 있거나 발생할 가능성이 높은지 추론합니다.\n';
        prompt += '• 각 예측된 문제에 대해 요구된 항목들(faultType, faultDetailType, faultReason, faultLocation, actionDescription, partsNeeded)을 상세하게 채워야 합니다.\n';
        prompt += '• `actionDescription`은 고객이 직접 수행할 수 있는 자가 점검/예방 정비 관점에서 구체적으로 작성합니다.\n';
        prompt += '• `partsNeeded`는 Product2 데이터에서 관련 부품을 찾아 **해당 부품(Product2 Object) 의 `Id`는 `Product__c` 필드에, 해당 부품(Product2 Object)의 ProductCode 는 `productCode` 필드, 추천 행동 지침에서 필요한 부품의 개수는 `quantity` 필드로 (`{"Product__c": "...", "productCode": "...", "quantity": "..."}`) 형태로 제공**합니다. 해당 부품이 없으면 빈 배열로 둡니다.\n';
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
                                        'analysisSummary' => new Map<String, Object>{
                                                'type' => 'string',
                                                'description' => '고객의 자가 점검 결과를 종합하여 현재 기계 상태와 잠재적 문제점을 설명하는 요약'
                                        },
                                        'recommendedActions' => new Map<String, Object>{
                                                'type' => 'array',
                                                'items' => new Map<String, Object>{
                                                        'type' => 'object',
                                                        'properties' => new Map<String, Object>{
                                                                'actionIndex' => new Map<String, Object>{
                                                                        'type' => 'integer', 'description' => '각 추천 행동의 고유 인덱스'
                                                                },
                                                                'faultType' => new Map<String, Object>{
                                                                        'type' => 'string', 'description' => '예측되는 고장 유형'
                                                                },
                                                                'faultDetailType' => new Map<String, Object>{
                                                                        'type' => 'string', 'description' => '고장 세부 유형'
                                                                },
                                                                'faultReason' => new Map<String, Object>{
                                                                        'type' => 'string', 'description' => '예상되는 고장 원인'
                                                                },
                                                                'faultLocation' => new Map<String, Object>{
                                                                        'type' => 'string', 'description' => '결함 예상 위치'
                                                                },
                                                                'actionDescription' => new Map<String, Object>{
                                                                        'type' => 'string', 'description' => '구체적인 행동 추천 내용'
                                                                },
                                                                'partsNeeded' => new Map<String, Object>{
                                                                        'type' => 'array',
                                                                        'items' => new Map<String, Object>{
                                                                                'type' => 'object',
                                                                                'properties' => new Map<String, Object>{
                                                                                        'Product__c' => new Map<String, Object>{
                                                                                                'type' => 'string', 'description' => 'Product2 레코드의 Id'
                                                                                        },
                                                                                        'productCode' => new Map<String, Object>{
                                                                                                'type' => 'string', 'description' => 'Product2 레코드의 ProductCode'
                                                                                        },
                                                                                        'quantity' => new Map<String, Object>{
                                                                                                'type' => 'string', 'description' => '필요한 수량'
                                                                                        }
                                                                                },
                                                                                'required' => new List<String>{
                                                                                        'Product__c', 'productCode'
                                                                                }
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
                                'required' => new List<String>{
                                        'analysisSummary', 'recommendedActions'
                                }
                        }
                },
                'required' => new List<String>{
                        'selfCheckReport'
                }
        };
    }

    private static Map<String, Object> processGeminiResponse(RiskAnalyzeReport__c objReport, String jsonResponse) {
        Map<String, Object> returnMap = new Map<String, Object>();
        returnMap.put('hasPredictions', false);

        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            Map<String, Object> selfCheckReport = (Map<String, Object>) responseMap.get('selfCheckReport');
            if (selfCheckReport == null || selfCheckReport.isEmpty()) {
                returnMap.put('message', 'No selfCheckReport found in Gemini response.');
                System.debug('No selfCheckReport found in response.');
                return returnMap;
            }

            List<Object> recommendedActions = (List<Object>) selfCheckReport.get('recommendedActions');
            if (recommendedActions == null || recommendedActions.isEmpty()) {
                returnMap.put('message', 'No recommendedActions found in selfCheckReport.');
                return returnMap;
            }

            String analysisSummary = (String) selfCheckReport.get('analysisSummary');
            if (analysisSummary != null) {
                returnMap.put('analysisSummary', analysisSummary);
            }

            ActionRecommendation__c objActionRecommendation = new ActionRecommendation__c();
            objActionRecommendation.AnalysisSummary__c = analysisSummary;
            objActionRecommendation.RiskAnalyzeReport__c = objReport.Id;

            try {
                insert objActionRecommendation;
                System.debug('objActionRecommendation inserted: ' + objActionRecommendation.Id);
                returnMap.put('actionRecommendationId', objActionRecommendation.Id);
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'Error inserting ActionRecommendation__c: ' + e.getMessage());
                returnMap.put('message', 'ActionRecommendation__c 레코드 저장 중 오류 발생: ' + e.getMessage());
                return returnMap;
            }

            List<Map<String, Object>> displayRecommendedActions = new List<Map<String, Object>>();
            List<ActionRecommendationItem__c> listActionItemToInsert = new List<ActionRecommendationItem__c>();
            List<List<SelectedPartItem__c>> listOfPartsForActionItems = new List<List<SelectedPartItem__c>>();

            for (Object actionObj : recommendedActions) {
                Map<String, Object> actionItem = (Map<String, Object>) actionObj;

                ActionRecommendationItem__c actionItemRec = new ActionRecommendationItem__c();
                actionItemRec.ActionRecommendation__c = objActionRecommendation.Id;
                actionItemRec.actionIndex__c = String.valueOf(actionItem.get('actionIndex'));
                actionItemRec.faultType__c = String.valueOf(actionItem.get('faultType'));
                actionItemRec.faultDetailType__c = String.valueOf(actionItem.get('faultDetailType'));
                actionItemRec.faultReason__c = String.valueOf(actionItem.get('faultReason'));
                actionItemRec.faultLocation__c = String.valueOf(actionItem.get('faultLocation'));
                actionItemRec.actionDescription__c = String.valueOf(actionItem.get('actionDescription'));
                actionItemRec.RiskAnalyzeReport__c = objReport.Id;
                listActionItemToInsert.add(actionItemRec);

                List<SelectedPartItem__c> currentActionParts = new List<SelectedPartItem__c>();
                List<Object> partsNeededRaw = (List<Object>) actionItem.get('partsNeeded');
                if (partsNeededRaw != null) {
                    for (Object partObj : partsNeededRaw) {
                        Map<String, Object> partMap = (Map<String, Object>) partObj;
                        String productId = String.valueOf(partMap.get('Product__c'));
                        String quantity = String.valueOf(partMap.get('quantity'));

                        SelectedPartItem__c objItem = new SelectedPartItem__c();
                        objItem.Product__c = productId;
                        objItem.Quantity__c = Integer.valueOf(quantity);
                        objItem.RiskAnalyzeReport__c = objReport.Id;
                        objItem.ExternalId__c = objReport.Id + '_' + productId;
                        currentActionParts.add(objItem);
                    }
                }
                listOfPartsForActionItems.add(currentActionParts);
            }

            if (!listActionItemToInsert.isEmpty()) {
                try {
                    insert listActionItemToInsert;

                    List<SelectedPartItem__c> finalPartsToInsert = new List<SelectedPartItem__c>();
                    for (Integer i = 0; i < listActionItemToInsert.size(); i++) {
                        ActionRecommendationItem__c savedActionItem = listActionItemToInsert[i];
                        List<SelectedPartItem__c> partsForThisAction = listOfPartsForActionItems[i];

                        for (SelectedPartItem__c part : partsForThisAction) {
                            part.ActionRecommendationItem__c = savedActionItem.Id;
                            finalPartsToInsert.add(part);
                        }
                    }

                    if (!finalPartsToInsert.isEmpty()) {
                        insert finalPartsToInsert;
                        System.debug('finalPartsToInsert inserted: ' + finalPartsToInsert);

                        Set<Id> insertedPartItemIds = new Set<Id>();
                        for (SelectedPartItem__c part : finalPartsToInsert) {
                            insertedPartItemIds.add(part.Id);
                        }
                        List<SelectedPartItem__c> retrievedParts = [SELECT Id, Product__c, Quantity__c, ActionRecommendationItem__c, PartCode__c FROM SelectedPartItem__c WHERE Id IN :insertedPartItemIds];

                        Map<Id, List<SelectedPartItem__c>> mapRetrievedPartsByActionItem = new Map<Id, List<SelectedPartItem__c>>();
                        for (SelectedPartItem__c part : retrievedParts) {
                            if (!mapRetrievedPartsByActionItem.containsKey(part.ActionRecommendationItem__c)) {
                                mapRetrievedPartsByActionItem.put(part.ActionRecommendationItem__c, new List<SelectedPartItem__c>());
                            }
                            mapRetrievedPartsByActionItem.get(part.ActionRecommendationItem__c).add(part);
                        }

                        for (Integer i = 0; i < listActionItemToInsert.size(); i++) {
                            ActionRecommendationItem__c savedActionItem = listActionItemToInsert[i];

                            Map<String, Object> itemToDisplay = new Map<String, Object>();
                            itemToDisplay.put('Id', savedActionItem.Id);
                            itemToDisplay.put('actionIndex', savedActionItem.actionIndex__c);
                            itemToDisplay.put('faultType', savedActionItem.faultType__c);
                            itemToDisplay.put('faultDetailType', savedActionItem.faultDetailType__c);
                            itemToDisplay.put('faultReason', savedActionItem.faultReason__c);
                            itemToDisplay.put('faultLocation', savedActionItem.faultLocation__c);
                            itemToDisplay.put('actionDescription', savedActionItem.actionDescription__c);
                            itemToDisplay.put('isChecked', savedActionItem.isChecked__c);

                            List<Map<String, String>> partsNeededFormatted = new List<Map<String, String>>();
                            List<SelectedPartItem__c> partsForThisAction = mapRetrievedPartsByActionItem.get(savedActionItem.Id);
                            if (partsForThisAction != null) {
                                for (SelectedPartItem__c part : partsForThisAction) {
                                    Map<String, String> formattedPart = new Map<String, String>();
                                    formattedPart.put('Id', part.Id);
                                    formattedPart.put('Product__c', part.Product__c);
                                    formattedPart.put('productCode', part.PartCode__c);
                                    formattedPart.put('quantity', String.valueOf(part.Quantity__c));
                                    partsNeededFormatted.add(formattedPart);
                                }
                            }
                            itemToDisplay.put('partsNeeded', partsNeededFormatted);
                            displayRecommendedActions.add(itemToDisplay);
                        }
                    }

                } catch (DmlException e) {
                    System.debug(LoggingLevel.ERROR, 'Error inserting ActionRecommendationItem__c or SelectedPartItem__c: ' + e.getMessage());
                    returnMap.put('message', '세부 레코드 또는 부품 레코드 저장 중 오류 발생: ' + e.getMessage());
                    return returnMap;
                }
            }

            returnMap.put('hasPredictions', true);
            returnMap.put('recommendedActions', displayRecommendedActions);
            returnMap.put('message', '성공적으로 자가 점검 기반 행동 추천 데이터를 로드했습니다.');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing Gemini response for display: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            returnMap.put('message', '데이터 처리 중 오류가 발생했습니다: ' + e.getMessage());
        }

        System.debug('returnMap : ' + JSON.serializePretty(returnMap));
        return returnMap;
    }

    @AuraEnabled
    public static Map<String, Object> updateActionRecommendationItems(List<Id> itemIds) {
        Map<String, Object> response = new Map<String, Object>();
        response.put('success', false);

        if (itemIds == null || itemIds.isEmpty()) {
            response.put('message', '업데이트할 항목 ID가 제공되지 않았습니다.');
            System.debug(LoggingLevel.WARN, 'No item IDs provided for update.');
            return response;
        }

        List<ActionRecommendationItem__c> itemsToUpdate = new List<ActionRecommendationItem__c>();
        for (Id itemId : itemIds) {
            itemsToUpdate.add(new ActionRecommendationItem__c(
                    Id = itemId,
                    isChecked__c = true
            ));
        }
        try {
            update itemsToUpdate;
            response.put('success', true);
            response.put('message', '선택된 추천 항목이 성공적으로 업데이트되었습니다.');
            System.debug('Successfully updated ActionRecommendationItem__c records: ' + itemIds.size() + ' records.');
        } catch (DmlException e) {
            response.put('message', '항목 업데이트 중 오류가 발생했습니다: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Error updating ActionRecommendationItem__c records: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
        }

        return response;
    }

    @AuraEnabled
    public static DocumentDownloadResponse getDocumentDataForDownload(Id reportId) {
        System.debug('=== getDocumentDataForDownload 시작 ===');
        System.debug('reportId: ' + reportId);

        try {
            Long startTime = System.currentTimeMillis();

            List<ContentDocumentLink> documentLinks = [
                    SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate, ContentDocument.FileExtension
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :reportId
                    AND (ContentDocument.Title LIKE '자가수리매뉴얼_%'
                    OR ContentDocument.Title LIKE '매뉴얼_%'
                    OR ContentDocument.Title LIKE 'TestManual_%')
                    ORDER BY ContentDocument.CreatedDate DESC
                    LIMIT 10
            ];

            System.debug('찾은 문서 수: ' + documentLinks.size());
            for (ContentDocumentLink link : documentLinks) {
                System.debug('문서: ' + link.ContentDocument.Title + ' (확장자: ' + link.ContentDocument.FileExtension + ')');
            }

            if (documentLinks.isEmpty()) {
                throw new AuraHandledException('해당 보고서에 연결된 매뉴얼 파일을 찾을 수 없습니다.');
            }

            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink link : documentLinks) {
                contentDocumentIds.add(link.ContentDocumentId);
            }

            List<ContentVersion> contentVersions = [
                    SELECT Id, Title, VersionData, FileExtension, ContentSize, ContentDocumentId, Checksum
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :contentDocumentIds
                    AND IsLatest = true
                    ORDER BY CreatedDate DESC
            ];

            if (contentVersions.isEmpty()) {
                throw new AuraHandledException('매뉴얼 파일 데이터를 찾을 수 없습니다.');
            }

            List<FileInfo> files = new List<FileInfo>();

            for (ContentVersion cv : contentVersions) {
                System.debug('처리 중인 파일: ' + cv.Title + ' (' + cv.FileExtension + ')');

                if (cv.ContentSize > 10 * 1024 * 1024) {
                    System.debug('파일이 너무 큼: ' + cv.ContentSize + ' bytes, 건너뜀');
                    continue;
                }

                if (cv.VersionData == null || cv.VersionData.size() == 0) {
                    System.debug('파일 데이터가 비어있음, 건너뜀: ' + cv.Title);
                    continue;
                }

                if (cv.FileExtension != null && cv.FileExtension.toLowerCase() == 'pdf') {
                    if (!validatePdfBlob(cv.VersionData)) {
                        System.debug('WARNING: PDF 헤더가 올바르지 않음: ' + cv.Title);
                    }
                }

                String base64Data;
                try {
                    base64Data = EncodingUtil.base64Encode(cv.VersionData);

                    if (String.isBlank(base64Data) || !isValidBase64(base64Data)) {
                        System.debug('Base64 인코딩 실패: ' + cv.Title);
                        continue;
                    }
                } catch (Exception encodeEx) {
                    System.debug('Base64 인코딩 오류: ' + cv.Title + ' - ' + encodeEx.getMessage());
                    continue;
                }

                FileInfo fileInfo = new FileInfo();
                fileInfo.fileName = cv.Title;
                fileInfo.fileType = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : 'unknown';
                fileInfo.fileSize = cv.ContentSize;
                fileInfo.base64Data = base64Data;
                fileInfo.checksum = cv.Checksum;

                files.add(fileInfo);

                System.debug('파일 추가됨: ' + fileInfo.fileName + ' (' + fileInfo.fileSize + ' bytes)');
            }

            if (files.isEmpty()) {
                throw new AuraHandledException('다운로드 가능한 파일이 없습니다.');
            }

            DocumentDownloadResponse response = new DocumentDownloadResponse();
            response.success = true;
            response.files = files;
            response.message = '문서 데이터를 성공적으로 조회했습니다.';

            Long totalTime = System.currentTimeMillis() - startTime;
            System.debug('=== 전체 프로세스 완료 - 총 소요시간: ' + totalTime + 'ms ===');
            System.debug('반환할 파일 수: ' + files.size());

            return response;

        } catch (Exception e) {
            System.debug('=== 문서 다운로드 데이터 조회 실패 ===');
            System.debug('오류: ' + e.getMessage());
            System.debug('스택 트레이스: ' + e.getStackTraceString());

            DocumentDownloadResponse response = new DocumentDownloadResponse();
            response.success = false;
            response.message = '문서 조회 실패: ' + e.getMessage();
            response.files = new List<FileInfo>();
            return response;
        }
    }

    @AuraEnabled
    public static PdfDownloadResponse getPdfDataForDownloadDebug(Id reportId) {
        System.debug('=== getPdfDataForDownloadDebug 시작 ===');
        System.debug('reportId: ' + reportId);

        try {
            Long startTime = System.currentTimeMillis();

            List<ContentDocumentLink> documentLinks = [
                    SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate, ContentDocument.FileExtension
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :reportId
                    AND (ContentDocument.Title LIKE 'TestManual_%'
                    OR ContentDocument.Title LIKE '자가수리매뉴얼_%'
                    OR ContentDocument.Title LIKE '매뉴얼_%')
                    ORDER BY ContentDocument.CreatedDate DESC
                    LIMIT 5
            ];

            System.debug('찾은 문서 수: ' + documentLinks.size());
            for (ContentDocumentLink link : documentLinks) {
                System.debug('문서: ' + link.ContentDocument.Title + ' (확장자: ' + link.ContentDocument.FileExtension + ')');
            }

            if (documentLinks.isEmpty()) {
                throw new AuraHandledException('파일을 찾을 수 없습니다.');
            }

            Id contentDocumentId = documentLinks[0].ContentDocumentId;
            System.debug('선택된 문서 ID: ' + contentDocumentId);

            List<ContentVersion> contentVersions = [
                    SELECT Id, Title, VersionData, FileExtension, ContentSize, Checksum
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocumentId
                    AND IsLatest = true
                    LIMIT 1
            ];

            if (contentVersions.isEmpty()) {
                throw new AuraHandledException('ContentVersion을 찾을 수 없습니다.');
            }

            ContentVersion cv = contentVersions[0];
            System.debug('ContentVersion 정보:');
            System.debug('- Title: ' + cv.Title);
            System.debug('- FileExtension: ' + cv.FileExtension);
            System.debug('- ContentSize: ' + cv.ContentSize);
            System.debug('- Checksum: ' + cv.Checksum);

            if (cv.ContentSize > 10 * 1024 * 1024) {
                throw new AuraHandledException('파일이 너무 큽니다: ' + cv.ContentSize + ' bytes');
            }

            if (cv.ContentSize == 0) {
                throw new AuraHandledException('파일 크기가 0입니다.');
            }

            if (cv.VersionData == null) {
                throw new AuraHandledException('파일 데이터가 null입니다.');
            }

            System.debug('실제 Blob 크기: ' + cv.VersionData.size());
            if (cv.VersionData.size() != cv.ContentSize) {
                System.debug('WARNING: ContentSize와 실제 Blob 크기 불일치');
            }

            if (cv.FileExtension != null && cv.FileExtension.toLowerCase() == 'pdf') {
                if (!validatePdfBlob(cv.VersionData)) {
                    System.debug('WARNING: PDF 헤더가 올바르지 않음');
                }
            }

            System.debug('Base64 인코딩 시작');
            Long encodeStartTime = System.currentTimeMillis();

            String base64Data;
            try {
                base64Data = EncodingUtil.base64Encode(cv.VersionData);
            } catch (Exception encodeEx) {
                System.debug('Base64 인코딩 실패: ' + encodeEx.getMessage());
                throw new AuraHandledException('파일 인코딩 실패: ' + encodeEx.getMessage());
            }

            Long encodeEndTime = System.currentTimeMillis();
            System.debug('Base64 인코딩 완료 - 소요시간: ' + (encodeEndTime - encodeStartTime) + 'ms');
            System.debug('Base64 데이터 길이: ' + base64Data.length());

            if (String.isBlank(base64Data)) {
                throw new AuraHandledException('Base64 데이터가 비어있습니다.');
            }

            if (!isValidBase64(base64Data)) {
                System.debug('WARNING: Base64 형식이 올바르지 않을 수 있음');
            }

            Integer expectedBase64Length = (Integer) Math.ceil(cv.ContentSize * 4.0 / 3.0);
            Integer actualBase64Length = base64Data.length();
            System.debug('예상 Base64 길이: ' + expectedBase64Length);
            System.debug('실제 Base64 길이: ' + actualBase64Length);

            Integer lengthDiff = Math.abs(actualBase64Length - expectedBase64Length);
            if (lengthDiff > 100) {
                System.debug('WARNING: Base64 길이 차이가 큼: ' + lengthDiff);
            }

            PdfDownloadResponse response = new PdfDownloadResponse();
            response.success = true;
            response.fileName = cv.Title;
            response.base64Data = base64Data;
            response.fileSize = cv.ContentSize;
            response.fileExtension = cv.FileExtension;
            response.checksum = cv.Checksum;
            response.message = '파일 데이터 조회 성공';

            Long totalTime = System.currentTimeMillis() - startTime;
            System.debug('=== 전체 프로세스 완료 - 총 소요시간: ' + totalTime + 'ms ===');

            return response;

        } catch (Exception e) {
            System.debug('=== 파일 다운로드 데이터 조회 실패 ===');
            System.debug('오류 타입: ' + e.getTypeName());
            System.debug('오류 메시지: ' + e.getMessage());
            System.debug('스택 트레이스: ' + e.getStackTraceString());
            System.debug('라인 번호: ' + e.getLineNumber());

            PdfDownloadResponse response = new PdfDownloadResponse();
            response.success = false;
            response.message = '파일 조회 실패: ' + e.getMessage();
            return response;
        }
    }

    private static Boolean validatePdfBlob(Blob pdfBlob) {
        try {
            String pdfString = pdfBlob.toString();

            if (pdfString.length() < 4) {
                System.debug('PDF 파일이 너무 작음');
                return false;
            }

            String header = pdfString.substring(0, 4);
            Boolean isValid = header == '%PDF';

            System.debug('PDF 헤더: ' + header + ' → 유효성: ' + isValid);

            return isValid;
        } catch (Exception e) {
            System.debug('PDF 검증 중 오류: ' + e.getMessage());
            return false;
        }
    }

    private static Boolean isValidBase64(String base64String) {
        try {
            Pattern base64Pattern = Pattern.compile('^[A-Za-z0-9+/]*={0,2}');
            Boolean matches = base64Pattern.matcher(base64String).matches();

            Boolean correctLength = Math.mod(base64String.length(), 4) == 0;

            System.debug('Base64 패턴 매치: ' + matches);
            System.debug('Base64 길이 확인: ' + correctLength + ' (길이: ' + base64String.length() + ')');

            return matches && correctLength;
        } catch (Exception e) {
            System.debug('Base64 검증 중 오류: ' + e.getMessage());
            return false;
        }
    }

    public class FileInfo {
        @AuraEnabled public String fileName;
        @AuraEnabled public String fileType;
        @AuraEnabled public Integer fileSize;
        @AuraEnabled public String base64Data;
        @AuraEnabled public String checksum;
    }

    public class DocumentDownloadResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public List<FileInfo> files;
        @AuraEnabled public String message;
    }

    public class PdfDownloadResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
        @AuraEnabled public Integer fileSize;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public String checksum;
        @AuraEnabled public String message;
    }
}