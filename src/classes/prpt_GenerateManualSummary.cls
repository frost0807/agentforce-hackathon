/**
 * Created by 최준석 on 2025-06-08.
 */

public with sharing class prpt_GenerateManualSummary {
    /**
     * ContentDocument ID로 PDF 매뉴얼과 ActionRecommendation 데이터를 기반으로
     * 자가수리 매뉴얼 요약 텍스트를 생성하는 메소드
     * @param contentDocumentId PDF 매뉴얼의 ContentDocument ID
     * @param riskAnalyzeReportId 위험 분석 보고서 ID (ActionRecommendation 조회용)
     * @return String 자가수리 매뉴얼 요약 텍스트
     */
    public static String generateManualSummary(Id contentDocumentId, Id riskAnalyzeReportId) {
        try {
            // 1. PDF 데이터 조회
            Blob pdfData;
            String fileName = '';
            List<ContentVersion> contentVersions = [
                    SELECT Id, VersionData, Title
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocumentId
                    AND IsLatest = true
                    LIMIT 1
            ];

            if (contentVersions.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'ContentDocument를 찾을 수 없습니다: ' + contentDocumentId);
                return null;
            }

            pdfData = contentVersions[0].VersionData;
            fileName = contentVersions[0].Title;

            // 2. ActionRecommendation 데이터 조회 (하위 Item들과 함께)
            List<ActionRecommendation__c> actionRecommendations = [
                    SELECT Id, AnalysisSummary__c,
                    (SELECT Id, Detail__c, faultDetailType__c, faultLocation__c,
                            actionIndex__c, actionDescription__c, faultType__c, faultReason__c
                    FROM ActionRecommendationItem__r
                    WHERE isChecked__c = true)
                    FROM ActionRecommendation__c
                    WHERE RiskAnalyzeReport__c = :riskAnalyzeReportId
            ];

            if (actionRecommendations.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'ActionRecommendation 데이터를 찾을 수 없습니다: ' + riskAnalyzeReportId);
                return null;
            }

            // 3. PDF를 Base64로 인코딩
            String pdfBase64 = EncodingUtil.base64Encode(pdfData);

            // 4. Gemini API 요청 생성
            String systemPrompt = buildSystemPrompt();
            String userPrompt = buildUserPrompt(actionRecommendations, fileName, riskAnalyzeReportId);

            Gemini2_5FlashApiController.Gemini2_5Request geminiRequest =
                    new Gemini2_5FlashApiController.Gemini2_5Request(systemPrompt, userPrompt, null);

            // PDF 데이터를 요청에 추가
            geminiRequest = addPdfToRequest(geminiRequest, pdfBase64);

            // 매뉴얼 생성에 최적화된 설정
            geminiRequest.generationConfig.temperature = 0.2; // 일관성을 위한 낮은 온도
            geminiRequest.generationConfig.maxOutputTokens = 8192; // 충분한 응답 길이
            geminiRequest.generationConfig.responseMimeType = 'text/plain'; // 텍스트 응답

            // 5. Gemini API 호출
            String response = Gemini2_5FlashApiController.askGemini2_5Flash(geminiRequest);

            if (String.isBlank(response)) {
                System.debug(LoggingLevel.WARN, 'Gemini API로부터 응답을 받지 못했습니다.');
                return null;
            }

            return response;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'generateManualSummary 실행 중 오류 발생: ' + e.getMessage());
            return null;
        }
    }

    /**
     * 시스템 프롬프트 생성 - LSMtron 사출성형기 자가수리 전문가
     */
    private static String buildSystemPrompt() {
        return '당신은 LSMtron의 사출성형기 자가수리 전문 가이드입니다. ' +
                '20년 이상의 사출성형기 정비 경험을 바탕으로, 복잡한 기술 매뉴얼을 ' +
                '작업자가 이해하기 쉽고 실행 가능한 단계별 자가수리 가이드로 변환하는 전문가입니다. ' +
                '제공된 PDF 매뉴얼과 분석된 위험 요소 및 세부 액션 아이템을 바탕으로, ' +
                '안전하고 효과적인 자가수리 절차를 명확한 매뉴얼 형식으로 작성해주세요. ' +
                '모든 지시사항은 한국어로 작성하며, 작업자의 안전을 최우선으로 고려해야 합니다.';
    }

    /**
     * 사용자 프롬프트 생성
     */
    private static String buildUserPrompt(List<ActionRecommendation__c> actionRecommendations,
            String fileName,
            Id riskAnalyzeReportId) {
        String prompt = '🔧 **자가수리 매뉴얼 생성 요청** 🔧\n\n';

        // 기본 정보
        prompt += '📋 **[매뉴얼 생성 정보]**\n';
        prompt += '• 위험분석보고서 ID: ' + riskAnalyzeReportId + '\n';
        prompt += '• 참조 매뉴얼 파일: ' + (String.isNotBlank(fileName) ? fileName.escapeXml() : 'N/A') + '\n\n';

        // 수행해야 할 권장 조치사항 (ActionRecommendationItem 포함)
        prompt += '⚠️ **[수행해야 할 권장 조치사항 상세]**\n';
        if (actionRecommendations != null && !actionRecommendations.isEmpty()) {
            Integer actionNum = 1;
            for (ActionRecommendation__c action : actionRecommendations) {
                prompt += '--- 조치사항 #' + actionNum + ' ---\n';
                prompt += '• 분석 요약: ' + (action.AnalysisSummary__c != null ? action.AnalysisSummary__c.escapeXml() : 'N/A') + '\n';

                // ActionRecommendationItem 데이터 추가
                if (action.ActionRecommendationItem__r != null && !action.ActionRecommendationItem__r.isEmpty()) {
                    prompt += '• 체크된 세부 액션 아이템:\n';
                    Integer itemNum = 1;
                    for (ActionRecommendationItem__c item : action.ActionRecommendationItem__r) {
                        prompt += '  ◦ 아이템 #' + itemNum + ':\n';
                        prompt += '    - 세부내용: ' + (item.Detail__c != null ? item.Detail__c.escapeXml() : 'N/A') + '\n';
                        prompt += '    - 액션설명: ' + (item.actionDescription__c != null ? item.actionDescription__c.escapeXml() : 'N/A') + '\n';
                        prompt += '    - 고장유형: ' + (item.faultType__c != null ? item.faultType__c.escapeXml() : 'N/A') + '\n';
                        prompt += '    - 고장위치: ' + (item.faultLocation__c != null ? item.faultLocation__c.escapeXml() : 'N/A') + '\n';
                        prompt += '    - 고장상세: ' + (item.faultDetailType__c != null ? item.faultDetailType__c.escapeXml() : 'N/A') + '\n';
                        prompt += '    - 고장원인: ' + (item.faultReason__c != null ? item.faultReason__c.escapeXml() : 'N/A') + '\n';
                        prompt += '    - 액션인덱스: ' + (item.actionIndex__c != null ? item.actionIndex__c.escapeXml() : 'N/A') + '\n';
                        itemNum++;
                    }
                } else {
                    prompt += '• 체크된 세부 액션 아이템: 없음\n';
                }
                prompt += '-------------------------\n';
                actionNum++;
            }
        } else {
            prompt += '권장 조치사항이 없습니다.\n';
        }
        prompt += '\n';

        // 매뉴얼 생성 요구사항
        prompt += '✅ **[자가수리 매뉴얼 생성 요구사항]**\n\n';
        prompt += '📝 **매뉴얼 구성 형식:**\n';
        prompt += '1. **안전 주의사항** - 작업 전 반드시 확인해야 할 안전 수칙\n';
        prompt += '2. **필요 도구 및 부품** - 작업에 필요한 도구와 교체 부품 목록\n';
        prompt += '3. **사전 준비사항** - 작업 전 준비해야 할 절차\n';
        prompt += '4. **단계별 수리 절차** - 번호가 매겨진 상세한 작업 단계\n';
        prompt += '5. **작업 완료 확인** - 수리 후 점검 및 테스트 방법\n';
        prompt += '6. **문제 해결** - 작업 중 발생할 수 있는 문제와 해결방법\n\n';

        prompt += '🎯 **작성 지침:**\n';
        prompt += '• 첨부된 PDF 매뉴얼의 내용을 기반으로 작성\n';
        prompt += '• 권장 조치사항과 체크된 세부 액션 아이템에 맞는 구체적인 수리 절차 포함\n';
        prompt += '• 고장 유형, 위치, 원인 정보를 활용하여 정확한 진단과 수리 방법 제시\n';
        prompt += '• 작업자가 직접 수행 가능한 범위 내에서 안전한 작업만 포함\n';
        prompt += '• 전문 기술자 호출이 필요한 경우 명확히 표시\n';
        prompt += '• 각 단계마다 구체적인 수치와 기준 제시\n';
        prompt += '• 위험한 작업에 대해서는 ⚠️ 경고 표시 사용\n';
        prompt += '• 번호가 매겨진 단계별 절차로 명확하게 구성\n\n';

        prompt += '📋 **응답 형식:**\n';
        prompt += '매뉴얼 형식의 텍스트로 응답해주세요. JSON이나 다른 구조화된 형식이 아닌 ' +
                '작업자가 바로 읽고 따라할 수 있는 일반 텍스트 매뉴얼로 작성해주세요.\n\n';

        prompt += '🚨 **중요사항:**\n';
        prompt += '• 모든 내용은 한국어로 작성\n';
        prompt += '• 안전을 최우선으로 고려한 절차 제시\n';
        prompt += '• 실제 작업 현장에서 바로 활용 가능한 실용적인 내용\n';
        prompt += '• LSMtron 사출성형기의 특성을 고려한 맞춤형 가이드\n';
        prompt += '• 제공된 고장 정보(유형, 위치, 원인)를 반드시 매뉴얼에 반영\n';

        return prompt;
    }

    /**
     * Gemini 요청에 PDF 데이터를 추가하는 헬퍼 메소드
     */
    private static Gemini2_5FlashApiController.Gemini2_5Request addPdfToRequest(
            Gemini2_5FlashApiController.Gemini2_5Request request,
            String pdfBase64) {

        // 마지막 사용자 메시지에 PDF 추가
        if (request.contents != null && !request.contents.isEmpty()) {
            for (Integer i = request.contents.size() - 1; i >= 0; i--) {
                if (request.contents[i].role == 'user') {
                    if (request.contents[i].parts == null) {
                        request.contents[i].parts = new List<Gemini2_5FlashApiController.Gemini2_5RequestPart>();
                    }
                    // PDF를 첫 번째로 추가
                    request.contents[i].parts.add(0,
                            new Gemini2_5FlashApiController.Gemini2_5RequestPart(pdfBase64, 'application/pdf'));
                    break;
                }
            }
        }

        return request;
    }
}