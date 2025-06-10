/************************************************************************************
* File Name : RiskAnalysisProcessor.cls
* Author : 최준석
* Date : 2025-06-03
* Description :
* Modification Log
* ===================================================================================
* Ver Date Author Modification
* ===================================================================================
1.0 2025-06-03 최준석 Create
*************************************************************************************/

public class RiskAnalysisProcessor {

    public static void processRiskAnalysis(Account account,
            List<Asset> assets,
            Map<Id, List<Case>> mapAssetIdToCases,
            Map<Id, List<Alarm_history__c>> mapAssetIdToAlarmHistories) {

        String generatedUUID = generateUUID();
        String strSystemPrompt = buildSystemPrompt();
        String strUserPrompt = buildUserPrompt(account, assets, mapAssetIdToCases, mapAssetIdToAlarmHistories, generatedUUID);

        System.debug(LoggingLevel.DEBUG, '=== SYSTEM PROMPT START ===');
        System.debug(LoggingLevel.DEBUG, strSystemPrompt);
        System.debug(LoggingLevel.DEBUG, '=== SYSTEM PROMPT END ===');
        System.debug(LoggingLevel.DEBUG, '=== USER PROMPT START ===');
        System.debug(LoggingLevel.DEBUG, strUserPrompt);
        System.debug(LoggingLevel.DEBUG, '=== USER PROMPT END ===');
        System.debug(LoggingLevel.DEBUG, 'Generated UUID: ' + generatedUUID);
        System.debug(LoggingLevel.DEBUG, 'Total System Prompt Length: ' + strSystemPrompt.length() + ' characters');
        System.debug(LoggingLevel.DEBUG, 'Total User Prompt Length: ' + strUserPrompt.length() + ' characters');

        try {
            Gemini2_5FlashApiController.Gemini2_5Request geminiRequest = new Gemini2_5FlashApiController.Gemini2_5Request(strSystemPrompt, strUserPrompt, null);
            geminiRequest.generationConfig.temperature = 0.0;
            geminiRequest.generationConfig.maxOutputTokens = 8192;
            geminiRequest.generationConfig.responseMimeType = 'application/json';
            geminiRequest.generationConfig.responseSchema = getRiskAnalyzeResponseSchema();

            String strResponse = Gemini2_5FlashApiController.askGemini2_5Flash(geminiRequest);

            if (String.isNotBlank(strResponse)) {
                System.debug(LoggingLevel.DEBUG, 'Gemini API 응답 수신 (Account ID: ' + account.Id + '): ' + strResponse.left(Math.min(strResponse.length(), 500)) + '...');
                processGeminiResponse(strResponse, account.Id, generatedUUID);
            } else {
                System.debug(LoggingLevel.WARN, 'Gemini API로부터 유효한 응답을 받지 못했습니다 (Account ID: ' + account.Id + ').');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Gemini API 호출 또는 응답 처리 중 오류 발생 (Account ID: ' + account.Id + '): ' + e.getMessage() + '\nStackTrace: ' + e.getStackTraceString());
        }
    }

    private static String buildSystemPrompt() {
        return '당신은 산업용 사출성형기의 고장 및 위험 예측 전문가입니다. ' +
                '사출성형기의 구조, 작동 원리, 일반적인 고장 패턴에 대한 깊은 지식을 보유하고 있으며, ' +
                'Alarm History 데이터와 Case 데이터를 분석하여 향후 1-2개월 내 발생할 수 있는 ' +
                '기계적 고장, 성능 저하, 부품 마모 등의 위험을 정확히 예측할 수 있습니다. ' +
                '데이터 패턴을 기반으로 근본 원인을 파악하고, 예방 정비 방안을 제시하며, ' +
                '비용 효과적인 해결책을 도출하는 것이 당신의 전문 분야입니다. ' +
                '고객에게는 LSMtron의 위험 분석 전문 Agent라는 브랜드 이미지로 소개되지만, ' +
                '실제로는 사출성형기 분야의 깊은 기술적 전문성을 바탕으로 분석을 수행합니다. ' +
                '응답은 반드시 지정된 JSON 스키마 형식을 정확히 따라야 합니다.';
    }

    private static String buildUserPrompt(Account account,
            List<Asset> assets,
            Map<Id, List<Case>> mapAssetIdToCases,
            Map<Id, List<Alarm_history__c>> mapAssetIdToAlarmHistories,
            String uuid) {
        String prompt = '🔍 **사출성형기 위험 분석 요청** 🔍\n\n';
        prompt += '📋 **[ACCOUNT 정보]**\n';
        prompt += '• 계정 ID: ' + account.Id + '\n';
        prompt += '• 계정명: ' + (account.Name != null ? account.Name.escapeXml() : 'N/A') + '\n'; // 인스턴스 메서드로 수정
        prompt += '• 분석 UUID: ' + uuid + '\n\n';
        prompt += '==========================================\n\n';
        prompt += buildAssetDataSection(assets, mapAssetIdToCases, mapAssetIdToAlarmHistories);
        prompt += buildAnalysisRequirements(account.Id, uuid);
        return prompt;
    }

    private static String buildAssetDataSection(List<Asset> assets,
            Map<Id, List<Case>> mapAssetIdToCases,
            Map<Id, List<Alarm_history__c>> mapAssetIdToAlarmHistories) {
        String prompt = '';
        for (Asset asset : assets) {
            prompt += '🏭 **[ASSET 정보: ' + asset.Id + ']**\n';
            prompt += '• Asset명: ' + (asset.Name != null ? asset.Name.escapeXml() : 'N/A') + '\n'; // 인스턴스 메서드로 수정
            prompt += '• 시리얼번호: ' + (asset.SerialNumber != null ? asset.SerialNumber.escapeXml() : 'N/A') + '\n\n'; // 인스턴스 메서드로 수정
            prompt += buildCaseDataSection(asset.Id, mapAssetIdToCases);
            prompt += buildAlarmHistoryDataSection(asset.Id, mapAssetIdToAlarmHistories);
            prompt += '🔚 **[ASSET ' + asset.Id + ' 데이터 완료]**\n';
            prompt += '==========================================\n\n';
        }
        return prompt;
    }

    private static String buildCaseDataSection(Id assetId, Map<Id, List<Case>> mapAssetIdToCases) {
        String prompt = '';
        List<Case> assetCases = mapAssetIdToCases.get(assetId);
        if (assetCases != null && !assetCases.isEmpty()) {
            prompt += '🚨 **[CASE 데이터 시작]**\n';
            Integer caseNum = 1;
            for (Case c : assetCases) {
                prompt += '--- Case #' + caseNum + ' ---\n';
                prompt += '• 제목: ' + (c.Subject != null ? c.Subject.escapeXml() : 'N/A') + '\n';
                prompt += '• 설명: ' + (c.Description != null ? c.Description.escapeXml() : 'N/A') + '\n';
                prompt += '• 고장유형: ' + (c.malfuction_type__c != null ? c.malfuction_type__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 고장상세: ' + (c.Malfunction_Type_Detail__c != null ? c.Malfunction_Type_Detail__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 부품코드: ' + (c.Part_Code__c != null ? c.Part_Code__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 부품명: ' + (c.Part_Name__c != null ? c.Part_Name__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 생성일: ' + c.CreatedDate + '\n';
                prompt += '-------------------------\n';
                caseNum++;
            }
            prompt += '🚨 **[CASE 데이터 종료]**\n\n';
        }
        return prompt;
    }

    private static String buildAlarmHistoryDataSection(Id assetId, Map<Id, List<Alarm_history__c>> mapAssetIdToAlarmHistories) {
        String prompt = '';
        List<Alarm_history__c> assetAlarmHistories = mapAssetIdToAlarmHistories.get(assetId);
        if (assetAlarmHistories != null && !assetAlarmHistories.isEmpty()) {
            prompt += '⚠️ **[ALARM HISTORY 데이터 시작]**\n';
            Integer alarmNum = 1;
            for (Alarm_history__c alarm : assetAlarmHistories) {
                prompt += '--- Alarm History #' + alarmNum + ' ---\n';
                prompt += '• ID: ' + alarm.Id + '\n';
                prompt += '• 이름: ' + (alarm.Name != null ? alarm.Name.escapeXml() : 'N/A') + '\n';
                prompt += '• 대분류 코드: ' + (alarm.Code_L__c != null ? alarm.Code_L__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 중분류 코드: ' + (alarm.Code_M__c != null ? alarm.Code_M__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 대분류명: ' + (alarm.Code_Name_L__c != null ? alarm.Code_Name_L__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 중분류명: ' + (alarm.Code_Name_M__c != null ? alarm.Code_Name_M__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 알람 설명: ' + (alarm.Alarm_Ex__c != null ? alarm.Alarm_Ex__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 시리얼번호: ' + (alarm.SerialNumber__c != null ? alarm.SerialNumber__c.escapeXml() : 'N/A') + '\n';
                prompt += '• 제품정보: ' + (alarm.Product__c != null ? alarm.Product__c.escapeXml() : 'N/A') + '\n';
                if (alarm.InstallDate__c != null) prompt += '• 설치일: ' + alarm.InstallDate__c + '\n';
                if (alarm.ManufactureDate__c != null) prompt += '• 제조일: ' + alarm.ManufactureDate__c + '\n';
                if (alarm.Customer_Warranty_Start_Date__c != null && alarm.Customer_Warranty_End_Date__c != null) {
                    prompt += '• 보증기간: ' + alarm.Customer_Warranty_Start_Date__c + ' ~ ' + alarm.Customer_Warranty_End_Date__c + '\n';
                }
                prompt += '• 생성일: ' + alarm.CreatedDate + '\n';
                prompt += '-------------------------\n';
                alarmNum++;
            }
            prompt += '⚠️ **[ALARM HISTORY 데이터 종료]**\n\n';
        }
        return prompt;
    }

    // 1. buildAnalysisRequirements 메서드에서 riskTrendData 관련 부분 제거
    private static String buildAnalysisRequirements(String accountId, String uuid) {
        String prompt = '✅ **[분석 요구사항 - 매우 중요!]**\n\n';
        prompt += '🚨 **반드시 JSON 형식으로만 응답하세요!** 🚨\n\n';
        prompt += '📧 **1. MailContent__c 요구사항:**\n';
        prompt += '• mailSubject: 간결하고 긴급성이 느껴지는 메일 제목\n';
        prompt += '• greeting: LSMtron Agent 소개를 포함한 정중한 인사말\n';
        prompt += '• riskSummary: 발견된 핵심 위험 요소 2-3개를 명확하게 요약\n';
        prompt += '• riskLevel: 위험도 (낮음/보통/높음/매우높음)\n';
        prompt += '• expectedTimeframe: 구체적인 예상 발생 시기\n';
        prompt += '• urgencyMessage: 즉시 조치가 필요한 이유를 강조\n';
        // riskTrendData 라인 제거됨
        prompt += '• callToAction: 상세 보고서 확인 유도 문구\n';
        prompt += '• closingMessage: 전문적인 마무리 인사\n\n';

        prompt += '📊 **2. Detail__c 요구사항 (핵심 내용만 포함):**\n';
        prompt += '• detailTitle: 상세 분석 보고서 제목\n';
        prompt += '• riskOverview: 전체 위험 상황 개요 (1-2문단)\n';
        prompt += '• technicalFindings: 구체적인 기술적 문제점과 데이터\n';
        prompt += '• rootCauseAnalysis: 문제의 근본 원인\n';
        prompt += '• impactAssessment: 생산성과 비용에 미치는 영향\n';
        prompt += '• riskTrendData: 위험도 추이 데이터 (현재, 1개월후, 2개월후 위험도 점수 0-100)\n';
        prompt += '• componentStatusData: 부품별 상태 데이터 [{"name":"유압시스템","status":85},{"name":"클램핑유닛","status":60}...]\n';
        prompt += '• failureCostData: 고장 유형별 비용 데이터 [{"type":"유압계통","cost":3500,"percentage":35}...]\n';
        prompt += '• maintenanceCostData: 수리 방식별 비용 데이터 [{"type":"유압","selfRepair":1200,"outsideRepair":2800}...]\n';
        prompt += '• costAnalysis: 기회비용 및 예방 정비 vs 고장 수리 비용 비교\n';
        prompt += '• emergencyActions: 즉시 취해야 할 조치사항\n\n';

        prompt += '📝 **3. SelfCheckItem__c 요구사항:**\n';
        prompt += '• 작업자가 현장에서 YES/NO로 확인 가능한 관찰 항목\n';
        prompt += '• Alarm History와 Case 데이터 기반 실제 증상 체크리스트\n';
        prompt += '• 5-8개 항목으로 구성\n\n';
        prompt += '🆔 **4. UUID 사용:** 제공된 UUID (' + uuid + ')를 그대로 사용\n\n';
        prompt += buildSvgChartGuide();
        prompt += buildGeneralGuidelines();

        prompt += '⭐ **응답 형식 (이 형식을 정확히 따르세요!):**\n';
        prompt += '```json\n';
        prompt += '{\n';
        prompt += '  "riskAnalysisResults": [\n';
        prompt += '    {\n';
        prompt += '      "accountId": "' + accountId + '",\n';
        prompt += '      "assetId": "실제_Asset_ID",\n';
        prompt += '      "uuid": "' + uuid + '",\n';
        prompt += '      "mailComponents": {\n';
        prompt += '        "mailSubject": "메일 제목",\n';
        prompt += '        "greeting": "인사말",\n';
        prompt += '        "riskSummary": "위험 요소 요약",\n';
        prompt += '        "riskLevel": "높음",\n';
        prompt += '        "expectedTimeframe": "2-3주 내",\n';
        prompt += '        "urgencyMessage": "긴급 메시지",\n';
        // riskTrendData 라인 제거됨
        prompt += '        "callToAction": "행동 유도",\n';
        prompt += '        "closingMessage": "마무리 인사"\n';
        prompt += '      },\n';
        prompt += '      "detailComponents": {\n';
        prompt += '        "detailTitle": "상세 제목",\n';
        prompt += '        "riskOverview": "위험 개요",\n';
        prompt += '        "technicalFindings": "기술적 발견사항",\n';
        prompt += '        "rootCauseAnalysis": "근본 원인",\n';
        prompt += '        "impactAssessment": "영향도 평가",\n';
        prompt += '        "riskTrendData": {"current": 85, "month1": 75, "month2": 60},\n';
        prompt += '        "componentStatusData": [{"name": "유압시스템", "status": 85}, {"name": "클램핑유닛", "status": 60}],\n';
        prompt += '        "failureCostData": [{"type": "유압계통", "cost": 3500, "percentage": 35}],\n';
        prompt += '        "maintenanceCostData": [{"type": "유압", "selfRepair": 1200, "outsideRepair": 2800}],\n';
        prompt += '        "costAnalysis": "비용 분석",\n';
        prompt += '        "emergencyActions": "즉시 조치사항"\n';
        prompt += '      },\n';
        prompt += '      "SelfCheckItem__c": [\n';
        prompt += '        "체크 항목 1",\n';
        prompt += '        "체크 항목 2",\n';
        prompt += '        "체크 항목 3"\n';
        prompt += '      ]\n';
        prompt += '    }\n';
        prompt += '  ]\n';
        prompt += '}\n';
        prompt += '```\n\n';
        prompt += '🚨 **중요 지침:**\n';
        prompt += '• 반드시 위의 JSON 형식으로만 응답\n';
        prompt += '• 모든 차트 데이터는 위에서 제시한 형식으로 제공\n';
        prompt += '• 실제 데이터를 기반으로 한 구체적인 분석 내용 작성\n';
        prompt += '• 일반적인 텍스트 응답 금지 - 오직 JSON만 응답\n\n';
        return prompt;
    }

    private static String buildSvgChartGuide() {
        // (이전과 동일)
        String prompt = '📈 **[차트 데이터 요구사항 - SVG는 Apex에서 생성]**\n';
        prompt += '🚨 **SVG 차트 대신 차트 생성용 데이터만 제공하세요!** 🚨\n\n';
        prompt += '**데이터 형식 예시:**\n\n';
        prompt += '• **riskTrendData**: 위험도 추이 (0-100 점수)\n';
        prompt += '  형식: {"current": 85, "month1": 75, "month2": 60}\n\n';
        prompt += '• **componentStatusData**: 부품별 상태 (0-100 점수)\n';
        prompt += '  형식: [{"name": "유압시스템", "status": 85}, {"name": "클램핑유닛", "status": 60}, {"name": "가열시스템", "status": 90}, {"name": "제어시스템", "status": 45}]\n\n';
        prompt += '• **failureCostData**: 고장 유형별 예상 비용\n';
        prompt += '  형식: [{"type": "유압계통", "cost": 3500, "percentage": 35}, {"type": "클램핑계통", "cost": 2500, "percentage": 25}, {"type": "가열계통", "cost": 2000, "percentage": 20}, {"type": "제어계통", "cost": 1500, "percentage": 15}, {"type": "기타", "cost": 500, "percentage": 5}]\n\n';
        prompt += '• **maintenanceCostData**: 수리 방식별 비용 비교 (만원 단위)\n';
        prompt += '  형식: [{"type": "유압", "selfRepair": 1200, "outsideRepair": 2800}, {"type": "클램핑", "selfRepair": 800, "outsideRepair": 2200}, {"type": "가열", "selfRepair": 600, "outsideRepair": 1800}, {"type": "제어", "selfRepair": 400, "outsideRepair": 1600}]\n\n';
        prompt += '🚨 **중요:** SVG 태그나 HTML은 생성하지 말고, 오직 위의 JSON 데이터만 제공하세요!\n';
        prompt += 'Apex에서 이 데이터를 받아 완전한 SVG 차트를 생성할 예정입니다.\n\n';
        return prompt;
    }

    private static String buildGeneralGuidelines() {
        // (이전과 동일)
        String prompt = '🎯 **[주요 지침]**\n';
        prompt += '• 메일은 간결하면서도 전문성과 긴급성을 강조\n';
        prompt += '• 상세 보고서는 현재 상황 분석과 기회비용 분석까지 포함\n';
        prompt += '• 자가 점검 이후 나올 내용(정비 권장사항, 다음 단계)은 제외\n';
        prompt += '• 실질적인 기계 고장 예방에 도움이 되는 내용 위주\n';
        prompt += '• 모든 내용은 한국어로 작성\n\n';
        return prompt;
    }

    private static Map<String, Object> getRiskAnalyzeResponseSchema() {
        // (이전 답변에서 제공된 전체 스키마 내용과 동일)
        return new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                        'riskAnalysisResults' => new Map<String, Object>{
                                'type' => 'array',
                                'description' => '위험 분석 결과의 배열입니다. 각 항목은 단일 Asset에 대한 분석 결과를 나타냅니다.',
                                'items' => new Map<String, Object>{
                                        'type' => 'object',
                                        'properties' => new Map<String, Object>{
                                                'accountId' => new Map<String, Object>{'type' => 'string', 'description' => '분석 대상 Account의 Salesforce ID'},
                                                'assetId' => new Map<String, Object>{'type' => 'string', 'description' => '분석 대상 Asset의 Salesforce ID'},
                                                'uuid' => new Map<String, Object>{'type' => 'string', 'description' => '이 분석 요청에 대한 고유 식별자 UUID (v4 형식)'},
                                                'mailComponents' => new Map<String, Object>{
                                                        'type' => 'object',
                                                        'description' => '이메일 알림 생성에 필요한 구성 요소',
                                                        'properties' => new Map<String, Object>{
                                                                'mailSubject' => new Map<String, Object>{'type' => 'string', 'description' => '이메일 제목.'},
                                                                'greeting' => new Map<String, Object>{'type' => 'string', 'description' => '인사말.'},
                                                                'riskSummary' => new Map<String, Object>{'type' => 'string', 'description' => '위험 요약.'},
                                                                'riskLevel' => new Map<String, Object>{'type' => 'string', 'description' => '위험 수준.'},
                                                                'expectedTimeframe' => new Map<String, Object>{'type' => 'string', 'description' => '예상 시기.'},
                                                                'urgencyMessage' => new Map<String, Object>{'type' => 'string', 'description' => '긴급 메시지.'},
                                                                'riskTrendData' => new Map<String, Object>{
                                                                        'type' => 'object',
                                                                        'description' => '시간 경과에 따른 위험도 추이 데이터 (점수: 0-100).',
                                                                        'properties' => new Map<String, Object>{
                                                                                'current' => new Map<String, Object>{'type' => 'integer', 'description' => '현재 위험도 점수'},
                                                                                'month1' => new Map<String, Object>{'type' => 'integer', 'description' => '1개월 후 예상 위험도 점수'},
                                                                                'month2' => new Map<String, Object>{'type' => 'integer', 'description' => '2개월 후 예상 위험도 점수'}
                                                                        },
                                                                        'required' => new List<String>{'current', 'month1', 'month2'}
                                                                },
                                                                'callToAction' => new Map<String, Object>{'type' => 'string', 'description' => '행동 유도 문구.'},
                                                                'closingMessage' => new Map<String, Object>{'type' => 'string', 'description' => '마무리 인사.'}
                                                        },
                                                        'required' => new List<String>{'mailSubject', 'greeting', 'riskSummary', 'riskLevel', 'expectedTimeframe', 'urgencyMessage', 'riskTrendData', 'callToAction', 'closingMessage'}
                                                },
                                                'detailComponents' => new Map<String, Object>{
                                                        'type' => 'object',
                                                        'description' => '상세 분석 보고서 콘텐츠 생성에 필요한 구성 요소.',
                                                        'properties' => new Map<String, Object>{
                                                                'detailTitle' => new Map<String, Object>{'type' => 'string', 'description' => '상세 보고서 제목.'},
                                                                'riskOverview' => new Map<String, Object>{'type' => 'string', 'description' => '위험 개요.'},
                                                                'technicalFindings' => new Map<String, Object>{'type' => 'string', 'description' => '기술적 발견사항.'},
                                                                'rootCauseAnalysis' => new Map<String, Object>{'type' => 'string', 'description' => '근본 원인 분석.'},
                                                                'impactAssessment' => new Map<String, Object>{'type' => 'string', 'description' => '영향 평가.'},
                                                                'riskTrendData' => new Map<String, Object>{
                                                                        'type' => 'object', 'description' => '위험도 추이 데이터 (상세용).',
                                                                        'properties' => new Map<String, Object>{
                                                                                'current' => new Map<String, Object>{'type' => 'integer'},
                                                                                'month1' => new Map<String, Object>{'type' => 'integer'},
                                                                                'month2' => new Map<String, Object>{'type' => 'integer'}
                                                                        }, 'required' => new List<String>{'current', 'month1', 'month2'}
                                                                },
                                                                'componentStatusData' => new Map<String, Object>{
                                                                        'type' => 'array', 'description' => '부품별 상태 데이터. 차트 생성용.',
                                                                        'items' => new Map<String, Object>{
                                                                                'type' => 'object', 'properties' => new Map<String, Object>{
                                                                                        'name' => new Map<String, Object>{'type' => 'string', 'description' => '부품명'},
                                                                                        'status' => new Map<String, Object>{'type' => 'integer', 'description' => '상태 점수 (0-100)'}
                                                                                }, 'required' => new List<String>{'name', 'status'}
                                                                        }
                                                                },
                                                                'failureCostData' => new Map<String, Object>{
                                                                        'type' => 'array', 'description' => '고장 유형별 예상 비용 데이터. 차트 생성용.',
                                                                        'items' => new Map<String, Object>{
                                                                                'type' => 'object', 'properties' => new Map<String, Object>{
                                                                                        'type' => new Map<String, Object>{'type' => 'string', 'description' => '고장 유형'},
                                                                                        'cost' => new Map<String, Object>{'type' => 'number', 'description' => '예상 비용'},
                                                                                        'percentage' => new Map<String, Object>{'type' => 'number', 'description' => '비용 비율'}
                                                                                }, 'required' => new List<String>{'type', 'cost', 'percentage'}
                                                                        }
                                                                },
                                                                'maintenanceCostData' => new Map<String, Object>{
                                                                        'type' => 'array', 'description' => '수리 방식별 비용 비교 데이터. 차트 생성용.',
                                                                        'items' => new Map<String, Object>{
                                                                                'type' => 'object', 'properties' => new Map<String, Object>{
                                                                                        'type' => new Map<String, Object>{'type' => 'string', 'description' => '수리 대상'},
                                                                                        'selfRepair' => new Map<String, Object>{'type' => 'number', 'description' => '자가 수리 비용'},
                                                                                        'outsideRepair' => new Map<String, Object>{'type' => 'number', 'description' => '외부 수리 비용'}
                                                                                }, 'required' => new List<String>{'type', 'selfRepair', 'outsideRepair'}
                                                                        }
                                                                },
                                                                'costAnalysis' => new Map<String, Object>{'type' => 'string', 'description' => '비용 분석.'},
                                                                'emergencyActions' => new Map<String, Object>{'type' => 'string', 'description' => '긴급 조치사항.'}
                                                        },
                                                        'required' => new List<String>{'detailTitle', 'riskOverview', 'technicalFindings', 'rootCauseAnalysis', 'impactAssessment', 'riskTrendData', 'componentStatusData', 'failureCostData', 'maintenanceCostData', 'costAnalysis', 'emergencyActions'}
                                                },
                                                'SelfCheckItem__c' => new Map<String, Object>{
                                                        'type' => 'array', 'description' => '자가 점검 항목 목록.',
                                                        'items' => new Map<String, Object>{'type' => 'string', 'description' => '개별 자가 점검 항목'}
                                                }
                                        },
                                        'required' => new List<String>{'accountId', 'assetId', 'uuid', 'mailComponents', 'detailComponents', 'SelfCheckItem__c'}
                                }
                        }
                },
                'required' => new List<String>{'riskAnalysisResults'}
        };
    }

    private static void processGeminiResponse(String jsonResponse, Id accountId, String expectedUUID) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            List<Object> resultsArray = (List<Object>) responseMap.get('riskAnalysisResults');

            if (resultsArray == null || resultsArray.isEmpty()) {
                System.debug(LoggingLevel.WARN,'No riskAnalysisResults found in response for Account: ' + accountId);
                return;
            }

            List<RiskAnalyzeReport__c> reportsToInsert = new List<RiskAnalyzeReport__c>();
            Map<String, List<String>> reportUUIDToCheckItemsMap = new Map<String, List<String>>();

            for (Object resultObj : resultsArray) {
                Map<String, Object> result = (Map<String, Object>) resultObj;
                String responseAccountId = (String) result.get('accountId');
                String assetId = (String) result.get('assetId');
                String responseUUID = (String) result.get('uuid');

                if (String.valueOf(accountId) != responseAccountId) {
                    System.debug(LoggingLevel.WARN, 'Account ID mismatch in response. Expected: ' + accountId + ', Received: ' + responseAccountId + '. Skipping this result.');
                    continue;
                }
                if (expectedUUID != responseUUID) {
                    System.debug(LoggingLevel.WARN, 'UUID mismatch - Expected: ' + expectedUUID + ', Received: ' + responseUUID + '. Using expected UUID for consistency.');
                    responseUUID = expectedUUID;
                }

                Map<String, Object> mailComponents = (Map<String, Object>) result.get('mailComponents');
                Map<String, Object> detailComponents = (Map<String, Object>) result.get('detailComponents');

                if (mailComponents == null || detailComponents == null) {
                    System.debug(LoggingLevel.ERROR, 'mailComponents or detailComponents is null for Account: ' + accountId + ', Asset: ' + assetId + ', UUID: ' + responseUUID);
                    continue;
                }

                RiskAnalyzeReport__c report = new RiskAnalyzeReport__c();
                report.Account__c = accountId;
                report.Asset__c = assetId;
                report.UUID__c = responseUUID;
                report.MailSubject__c = (String) mailComponents.get('mailSubject');
                report.MailContent__c = assembleMailContent(mailComponents, responseUUID);
                report.Detail__c = assembleDetailContent(detailComponents, responseUUID);

                reportsToInsert.add(report);

                List<Object> checkItemsObj = (List<Object>) result.get('SelfCheckItem__c');
                if (checkItemsObj != null && !checkItemsObj.isEmpty()) {
                    List<String> checkItemStrings = new List<String>();
                    for (Object item : checkItemsObj) {
                        if(item != null) checkItemStrings.add(String.valueOf(item));
                    }
                    if(!checkItemStrings.isEmpty()) reportUUIDToCheckItemsMap.put(responseUUID, checkItemStrings);
                }
            }

            if (!reportsToInsert.isEmpty()) {
                Database.SaveResult[] srs = Database.insert(reportsToInsert, false);
                Integer successCount = 0;
                List<RiskAnalyzeReport__c> successfullyInsertedReports = new List<RiskAnalyzeReport__c>();
                for(Integer i=0; i < reportsToInsert.size(); i++){
                    Database.SaveResult sr = srs[i];
                    if(sr.isSuccess()){
                        successCount++;
                        reportsToInsert[i].Id = sr.getId();
                        successfullyInsertedReports.add(reportsToInsert[i]);
                        System.debug(LoggingLevel.DEBUG,'Inserted Report ID: ' + reportsToInsert[i].Id + ', UUID: ' + reportsToInsert[i].UUID__c);
                    } else {
                        for(Database.Error err : sr.getErrors()){
                            System.debug(LoggingLevel.ERROR, 'Error inserting RiskAnalyzeReport: ' + err.getStatusCode() + ': ' + err.getMessage() + ' Fields: ' + String.valueOf(err.getFields()));
                        }
                    }
                }
                System.debug(LoggingLevel.INFO,'Successfully inserted ' + successCount + '/' + reportsToInsert.size() + ' RiskAnalyzeReport records for Account: ' + accountId);

                if(!successfullyInsertedReports.isEmpty()){
                    createSelfCheckItems(successfullyInsertedReports, reportUUIDToCheckItemsMap);
                    sendRiskAnalysisEmails(successfullyInsertedReports, accountId);
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing Gemini response for Account ' + accountId + ': ' + e.getMessage() + '\nStackTrace: ' + e.getStackTraceString());
            System.debug(LoggingLevel.ERROR, 'Problematic JSON Response (first 1000 chars): ' + (jsonResponse != null ? jsonResponse.left(1000) : 'null'));
        }
    }

    private static void sendRiskAnalysisEmails(List<RiskAnalyzeReport__c> reports, Id accountId) {
        if (reports == null || reports.isEmpty()) return;
        try {
            Integer mailingCount = 0;
            for (RiskAnalyzeReport__c report : reports) {
                if (System.isBatch() && mailingCount >= 1) {
                    System.debug(LoggingLevel.INFO, 'Demo email limit reached in batch context.');
                    break;
                }
                if (report.Id != null && String.isNotBlank(report.MailContent__c)) {
                    RiskAnalysisEmailSender.sendRiskAnalysisEmail(
                            accountId,
                            report.MailContent__c,
                            report.MailSubject__c
                    );
                    mailingCount++;
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending risk analysis emails: ' + e.getMessage() + e.getStackTraceString());
        }
    }

    private static void createSelfCheckItems(List<RiskAnalyzeReport__c> reports, Map<String, List<String>> reportUUIDToCheckItemsMap) {
        if (reports == null || reports.isEmpty() || reportUUIDToCheckItemsMap == null || reportUUIDToCheckItemsMap.isEmpty()) {
            return;
        }
        List<SelfCheckItem__c> checkItemsToInsert = new List<SelfCheckItem__c>();
        for (RiskAnalyzeReport__c report : reports) {
            if (report.Id == null || String.isBlank(report.UUID__c)) continue;

            List<String> checkItems = reportUUIDToCheckItemsMap.get(report.UUID__c);
            if (checkItems != null && !checkItems.isEmpty()) {
                Integer itemSequence = 1;
                for (String checkItemDesc : checkItems) {
                    if(String.isBlank(checkItemDesc)) continue;
                    SelfCheckItem__c checkItem = new SelfCheckItem__c();
                    checkItem.RiskAnalyzeReport__c = report.Id;
                    checkItem.Description__c = checkItemDesc.left(255);
                    checkItem.Sequence__c = itemSequence++;
                    checkItemsToInsert.add(checkItem);
                }
            }
        }
        if (!checkItemsToInsert.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(checkItemsToInsert, false);
            Integer successCount = 0;
            for(Database.SaveResult sr : srs){
                if(sr.isSuccess()){
                    successCount++;
                } else {
                    for(Database.Error err : sr.getErrors()){
                        System.debug(LoggingLevel.ERROR, 'Error inserting SelfCheckItem: ' + err.getStatusCode() + ': ' + err.getMessage() + ' Fields: ' + String.valueOf(err.getFields()));
                    }
                }
            }
            System.debug(LoggingLevel.INFO,'Successfully inserted ' + successCount + '/' + checkItemsToInsert.size() + ' SelfCheckItem records');
        }
    }

    public static String generateUUID() {
        String hexChars = '0123456789abcdef';
        String uuid = '';
        for (Integer i = 0; i < 36; i++) {
            if (i == 8 || i == 13 || i == 18 || i == 23) {
                uuid += '-';
            } else if (i == 14) {
                uuid += '4'; // Version 4
            } else if (i == 19) {
                Integer randomIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), 4);
                uuid += hexChars.substring(8 + randomIndex, 8 + randomIndex + 1);
            } else {
                Integer randomIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), 16);
                uuid += hexChars.substring(randomIndex, randomIndex + 1);
            }
        }
        return uuid;
    }

    private static Map<String, Object> getTypedMapFromComponents(Map<String, Object> components, String key) {
        Object rawObject = components.get(key);
        if (rawObject == null) {
            System.debug(LoggingLevel.WARN, 'getTypedMapFromComponents: Raw object for key "' + key + '" is null.');
            return null;
        }

        String initialSerialized = JSON.serialize(rawObject);
        // 이 로그는 초기 rawObject의 상태를 기록합니다. instanceof 검사는 제거되었습니다.
        System.debug(LoggingLevel.DEBUG, 'getTypedMapFromComponents - Key: ' + key +
                ', Initial rawObject (Serialized): ' + initialSerialized);

        try {
            // rawObject를 다시 직렬화 후 JSON.deserializeUntyped로 역직렬화합니다.
            // JSON.deserializeUntyped는 JSON 객체 문자열에 대해 Map<String, Object>를 반환하는 것으로 문서화되어 있습니다.
            Object deserializedObject = JSON.deserializeUntyped(initialSerialized);

            // instanceof 검사 대신 직접적인 타입 캐스팅을 시도합니다.
            try {
                Map<String, Object> typedMap = (Map<String, Object>) deserializedObject;
                System.debug(LoggingLevel.INFO, 'Successfully CAST key "' + key + '" to Map<String, Object> after deserializeUntyped. Content (first 200 chars): ' + (typedMap != null ? JSON.serialize(typedMap).left(200) : 'null'));
                return typedMap;
            } catch (TypeException te) {
                // 이 예외가 발생하면 JSON.deserializeUntyped가 Map<String, Object>와 호환되지 않는 타입을 반환한 것입니다.
                // 이는 JSON 문자열이 실제로는 JSON 객체가 아니었거나, 매우 예외적인 Apex 내부 타입 문제일 수 있습니다.
                System.debug(LoggingLevel.ERROR, 'CRITICAL: TypeException on casting to Map<String, Object> for key "' + key +
                        '". This means deserializeUntyped did not return a compatible Map. Exception: ' + te.getMessage() +
                        '. Deserialized object (toString): ' + String.valueOf(deserializedObject) +
                        '. Initial serialized from rawObject (first 200 chars): ' + initialSerialized.left(200));
                return null;
            }
        } catch (Exception e) { // JSON.serialize 또는 JSON.deserializeUntyped 자체의 예외 처리
            System.debug(LoggingLevel.ERROR, 'Exception during JSON processing (serialize/deserializeUntyped) for key "' + key +
                    '": ' + e.getMessage() + '. Initial Serialized Object was: ' + initialSerialized.left(200) + // 로그 길이 제한
                    '. Stack: ' + e.getStackTraceString());
            return null;
        }
    }

    // 2. assembleMailContent 메서드에서 위험도 추이 차트 관련 부분 제거
    private static String assembleMailContent(Map<String, Object> mailComponents, String uuid) {
        if (mailComponents == null) {
            System.debug(LoggingLevel.WARN, 'assembleMailContent: mailComponents is null. UUID: ' + uuid);
            return '';
        }

        String mailSubject = (String) mailComponents.get('mailSubject');
        String greeting = (String) mailComponents.get('greeting');
        String riskSummary = (String) mailComponents.get('riskSummary');
        String riskLevel = (String) mailComponents.get('riskLevel');
        String expectedTimeframe = (String) mailComponents.get('expectedTimeframe');
        String urgencyMessage = (String) mailComponents.get('urgencyMessage');
        String callToAction = (String) mailComponents.get('callToAction');
        String closingMessage = (String) mailComponents.get('closingMessage');

        // 위험도 추이 차트 관련 코드 전체 제거됨

        String htmlContent = '<div style="max-width: 600px; margin: 0 auto; padding: 20px; font-family: Arial, sans-serif; line-height: 1.6; color: #333;">';
        if (String.isNotBlank(mailSubject)) htmlContent += '<h1 style="color: #dc3545; font-size: 20px; margin-bottom: 20px; text-align: center;">' + mailSubject.escapeHtml4() + '</h1>';
        if (String.isNotBlank(greeting)) htmlContent += '<p style="margin-bottom: 20px;">' + greeting.escapeHtml4() + '</p>';
        if (String.isNotBlank(riskSummary)) {
            htmlContent += '<div style="background-color: #fff5f5; border-left: 4px solid #dc3545; padding: 15px; margin-bottom: 20px;">';
            htmlContent += '<h3 style="color: #dc3545; margin-top: 0;">🚨 발견된 위험 요소</h3>';
            htmlContent += '<p>' + riskSummary.escapeHtml4() + '</p>';
            if (String.isNotBlank(riskLevel)) htmlContent += '<p><strong>위험도:</strong> <span style="color: #dc3545; font-weight: bold;">' + riskLevel.escapeHtml4() + '</span></p>';
            if (String.isNotBlank(expectedTimeframe)) htmlContent += '<p><strong>예상 발생 시기:</strong> ' + expectedTimeframe.escapeHtml4() + '</p>';
            htmlContent += '</div>';
        }
        if (String.isNotBlank(urgencyMessage)) {
            htmlContent += '<div style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; margin-bottom: 20px; border-radius: 5px;">';
            htmlContent += '<p style="margin: 0; color: #856404; font-weight: bold;">⚠️ ' + urgencyMessage.escapeHtml4() + '</p>';
            htmlContent += '</div>';
        }

        // 위험도 변화 추이 차트 박스 전체 제거됨

        String baseAnalysisUrl = 'https://orgfarm-2bd4fdfcf2.my.site.com/support/s/agentron-analysis';
        String detailUrlString = '#';

        if (String.isNotBlank(uuid)) {
            try {
                detailUrlString = baseAnalysisUrl + '?c__channelName=ERROR_REPORT&c__jsonString=' + EncodingUtil.urlEncode('{"uuid":"' + uuid + '"}', 'UTF-8');
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error encoding detail URL for UUID: ' + uuid + '. Error: ' + e.getMessage());
                detailUrlString = baseAnalysisUrl + '?error=uuid-encoding-failed';
            }
        } else {
            System.debug(LoggingLevel.ERROR, 'RiskAnalysisProcessor: UUID is blank, cannot generate detail URL.');
        }

        htmlContent += '<div style="text-align: center; margin: 30px 0;">';
        htmlContent += '<a href="' + detailUrlString.escapeHtml4() + '" style="background-color: #0176d3; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-weight: bold;">📊 상세 분석 보고서 확인</a>';
        htmlContent += '</div>';

        if (String.isNotBlank(callToAction)) htmlContent += '<p style="color: #0176d3; font-weight: bold; text-align: center; margin-bottom: 20px;">' + callToAction.escapeHtml4() + '</p>';
        if (String.isNotBlank(closingMessage)) {
            htmlContent += '<div style="border-top: 1px solid #dee2e6; padding-top: 20px; margin-top: 30px; color: #6c757d;">';
            htmlContent += '<p>' + closingMessage.escapeHtml4() + '</p>';
            htmlContent += '</div>';
        }
        htmlContent += '</div>';
        return htmlContent;
    }

    private static String assembleDetailContent(Map<String, Object> detailComponents, String uuid) {
        if (detailComponents == null) {
            System.debug(LoggingLevel.WARN, 'assembleDetailContent: detailComponents is null. UUID: ' + uuid);
            return '';
        }

        String detailTitle = detailComponents.get('detailTitle') != null ? ((String)detailComponents.get('detailTitle')).escapeHtml4() : '';
        String riskOverview = detailComponents.get('riskOverview') != null ? ((String)detailComponents.get('riskOverview')).escapeHtml4() : '';
        String technicalFindings = detailComponents.get('technicalFindings') != null ? ((String)detailComponents.get('technicalFindings')).escapeHtml4() : '';
        String rootCauseAnalysis = detailComponents.get('rootCauseAnalysis') != null ? ((String)detailComponents.get('rootCauseAnalysis')).escapeHtml4() : '';
        String impactAssessment = detailComponents.get('impactAssessment') != null ? ((String)detailComponents.get('impactAssessment')).escapeHtml4() : '';
        String costAnalysis = detailComponents.get('costAnalysis') != null ? ((String)detailComponents.get('costAnalysis')).escapeHtml4() : '';
        String emergencyActions = detailComponents.get('emergencyActions') != null ? ((String)detailComponents.get('emergencyActions')).escapeHtml4() : '';

        String riskTrendChartHtml = '';
        Map<String, Object> riskTrendDataMap = getTypedMapFromComponents(detailComponents, 'riskTrendData');
        if (riskTrendDataMap != null) {
            try {
                riskTrendChartHtml = SvgChartGenerator.generateRiskTrendChart(riskTrendDataMap);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error generating riskTrendChart for detail (UUID: ' + uuid + '): ' + e.getMessage() + e.getStackTraceString());
                riskTrendChartHtml = '';
            }
        } else {
            System.debug(LoggingLevel.WARN, 'assembleDetailContent: riskTrendDataMap is null for UUID: ' + uuid);
        }

        String componentStatusChartHtml = '';
        Object rawComponentStatusData = detailComponents.get('componentStatusData');
        if (rawComponentStatusData instanceof List<Object>) {
            try {
                componentStatusChartHtml = SvgChartGenerator.generateComponentStatusChart((List<Object>)rawComponentStatusData);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error generating componentStatusChart for detail (UUID: ' + uuid + '): ' + e.getMessage() + e.getStackTraceString());
                componentStatusChartHtml = '';
            }
        }  else {
            System.debug(LoggingLevel.WARN, 'assembleDetailContent: rawComponentStatusData is not a List for UUID: ' + uuid + '. Actual: ' + (rawComponentStatusData != null ? JSON.serialize(rawComponentStatusData) : 'null'));
        }

        String failureCostChartHtml = '';
        Object rawFailureCostData = detailComponents.get('failureCostData');
        if (rawFailureCostData instanceof List<Object>) {
            try {
                failureCostChartHtml = SvgChartGenerator.generateFailureCostChart((List<Object>)rawFailureCostData);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error generating failureCostChart for detail (UUID: ' + uuid + '): ' + e.getMessage() + e.getStackTraceString());
                failureCostChartHtml = '';
            }
        } else {
            System.debug(LoggingLevel.WARN, 'assembleDetailContent: rawFailureCostData is not a List for UUID: ' + uuid + '. Actual: ' + (rawFailureCostData != null ? JSON.serialize(rawFailureCostData) : 'null'));
        }

        String maintenanceCostChartHtml = '';
        Object rawMaintenanceCostData = detailComponents.get('maintenanceCostData');
        if (rawMaintenanceCostData instanceof List<Object>) {
            try {
                maintenanceCostChartHtml = SvgChartGenerator.generateMaintenanceCostChart((List<Object>)rawMaintenanceCostData);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error generating maintenanceCostChart for detail (UUID: ' + uuid + '): ' + e.getMessage() + e.getStackTraceString());
                maintenanceCostChartHtml = '';
            }
        } else {
            System.debug(LoggingLevel.WARN, 'assembleDetailContent: rawMaintenanceCostData is not a List for UUID: ' + uuid + '. Actual: ' + (rawMaintenanceCostData != null ? JSON.serialize(rawMaintenanceCostData) : 'null'));
        }

        String htmlContent = '<div style="max-width: 900px; margin: 0 auto; padding: 20px; font-family: Arial, sans-serif; line-height: 1.6; color: #333;">';
        if (String.isNotBlank(detailTitle)) htmlContent += '<header style="text-align:center;margin-bottom:30px;border-bottom:2px solid #0176d3;padding-bottom:20px;"><h1 style="color:#0176d3;font-size:24px;margin:0;">' + detailTitle + '</h1><p style="color: #6c757d; margin-top: 10px;">LSMtron 위험 분석 전문가 보고서</p></header>';
        if (String.isNotBlank(riskOverview)) htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#dc3545;font-size:18px;border-bottom:1px solid #dc3545;padding-bottom:5px;">🚨 위험 개요</h2><div style="background-color:#fff5f5;padding:15px;border-radius:5px;">' + riskOverview + '</div></section>';
        if (String.isNotBlank(technicalFindings)) htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#0176d3;font-size:18px;border-bottom:1px solid #0176d3;padding-bottom:5px;">🔧 기술적 발견사항</h2><div style="background-color:#f8f9fa;padding:15px;border-radius:5px;">' + technicalFindings + '</div></section>';
        if (String.isNotBlank(rootCauseAnalysis)) htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#6f42c1;font-size:18px;border-bottom:1px solid #6f42c1;padding-bottom:5px;">🔍 근본 원인</h2><div style="background-color:#f8f7ff;padding:15px;border-radius:5px;">' + rootCauseAnalysis + '</div></section>';
        if (String.isNotBlank(impactAssessment)) htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#fd7e14;font-size:18px;border-bottom:1px solid #fd7e14;padding-bottom:5px;">📈 영향도 평가</h2><div style="background-color:#fff8f0;padding:15px;border-radius:5px;">' + impactAssessment + '</div></section>';

        htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#6610f2;font-size:18px;border-bottom:1px solid #6610f2;padding-bottom:5px;">📊 위험도 변화 추이</h2><div style="text-align:center;background-color:#f8f6ff;padding:20px;border-radius:5px;">' + riskTrendChartHtml + '</div></section>';
        htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#20c997;font-size:18px;border-bottom:1px solid #20c997;padding-bottom:5px;">🔧 주요 부품 상태</h2><div style="text-align:center;background-color:#f0fff4;padding:20px;border-radius:5px;">' + componentStatusChartHtml + '</div></section>';
        htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#e83e8c;font-size:18px;border-bottom:1px solid #e83e8c;padding-bottom:5px;">💰 고장 유형별 예상 비용</h2><div style="text-align:center;background-color:#fff0f5;padding:20px;border-radius:5px;">' + failureCostChartHtml + '</div></section>';
        htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#17a2b8;font-size:18px;border-bottom:1px solid #17a2b8;padding-bottom:5px;">🔨 수리 방식별 비용 비교</h2><div style="text-align:center;background-color:#d1ecf1;padding:20px;border-radius:5px;">' + maintenanceCostChartHtml + '</div></section>';

        if (String.isNotBlank(costAnalysis)) htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#6f42c1;font-size:18px;border-bottom:1px solid #6f42c1;padding-bottom:5px;">💰 기회비용 분석</h2><div style="background-color:#f8f7ff;padding:15px;border-radius:5px;">' + costAnalysis + '</div></section>';
        if (String.isNotBlank(emergencyActions)) htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#dc3545;font-size:18px;border-bottom:1px solid #dc3545;padding-bottom:5px;">⚡ 즉시 조치사항</h2><div style="background-color:#f8d7da;padding:15px;border-radius:5px;border:1px solid #dc3545;"><strong style="color:#721c24;">긴급:</strong> ' + emergencyActions + '</div></section>';

        htmlContent += '<section style="margin-bottom:25px;"><h2 style="color:#0176d3;font-size:18px;border-bottom:1px solid #0176d3;padding-bottom:5px;">📋 다음 단계</h2><div style="background-color:#cce7ff;padding:20px;border-radius:5px;text-align:center;"><p style="margin:0 0 15px 0;font-size:16px;font-weight:bold;">상세 분석 결과를 확인하셨다면, 이제 자가 점검을 진행해주세요.</p><p style="margin:0;color:#495057;">자가 점검 결과를 바탕으로 맞춤형 정비 권장사항과 비용 분석을 제공해드립니다.</p></div></section>';
        htmlContent += '<footer style="text-align:center;margin-top:40px;padding-top:20px;border-top:1px solid #dee2e6;"><p style="color:#6c757d;font-size:14px;">LSMtron 위험 분석 전문가 | 고객지원: support@lsmtron.com</p></footer>';
        htmlContent += '</div>';
        return htmlContent;
    }
}