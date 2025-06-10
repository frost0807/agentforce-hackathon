/**
 * 디버깅을 위해 로그를 추가한 prpt_FindProperPdf 클래스
 */
public class prpt_FindProperPdf {

    public static Id findProperPdf(Id riskAnalyzeReportId) {
        System.debug('=== findProperPdf 시작 ===');
        System.debug('riskAnalyzeReportId: ' + riskAnalyzeReportId);

        try {
            // 1. Manual__c 레코드 조회
            Map<Id, Manual__c> mapManual = new Map<Id, Manual__c>([SELECT Id FROM Manual__c]);
            System.debug('Manual__c 레코드 수: ' + mapManual.size());
            System.debug('Manual__c IDs: ' + mapManual.keySet());

            if (mapManual.isEmpty()) {
                System.debug('ERROR: Manual__c 레코드가 존재하지 않습니다.');
                return null;
            }

            // 2. ContentDocumentLink 조회
            List<ContentDocumentLink> contentLinks = [
                    SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.FileType
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :mapManual.keySet()
            ];
            System.debug('전체 ContentDocumentLink 수: ' + contentLinks.size());

            List<ContentDocumentInfo> availablePdfs = new List<ContentDocumentInfo>();
            for (ContentDocumentLink obj : contentLinks) {
                System.debug('파일: ' + obj.ContentDocument.Title + ', 타입: ' + obj.ContentDocument.FileType);

                if (obj.ContentDocument.FileType.equalsIgnoreCase('pdf')) {
                    ContentDocumentInfo pdfInfo = new ContentDocumentInfo();
                    pdfInfo.contentDocumentId = obj.ContentDocumentId;
                    pdfInfo.title = obj.ContentDocument.Title;
                    availablePdfs.add(pdfInfo);
                    System.debug('PDF 파일 추가: ' + obj.ContentDocument.Title);
                }
            }

            System.debug('사용 가능한 PDF 수: ' + availablePdfs.size());
            if (availablePdfs.isEmpty()) {
                System.debug('ERROR: Manual__c에서 PDF 파일을 찾을 수 없습니다.');
                return null;
            }

            // 3. 제품코드 조회
            List<RiskAnalyzeReport__c> riskReports = [
                    SELECT Asset__r.Product2.ProductCode, Asset__r.Name, Asset__r.SerialNumber
                    FROM RiskAnalyzeReport__c
                    WHERE Id = :riskAnalyzeReportId
                    LIMIT 1
            ];

            System.debug('RiskAnalyzeReport 조회 결과 수: ' + riskReports.size());
            String strProductCode = '';
            if (!riskReports.isEmpty()) {
                strProductCode = riskReports[0].Asset__r.Product2.ProductCode;
                System.debug('제품 코드: ' + strProductCode);
            } else {
                System.debug('WARNING: RiskAnalyzeReport를 찾을 수 없습니다.');
            }

            // 4. ActionRecommendation 데이터 조회
            List<ActionRecommendation__c> listActionRec = [
                    SELECT Id, AnalysisSummary__c,
                    (SELECT Id, Detail__c, faultDetailType__c, faultLocation__c,
                            actionIndex__c, actionDescription__c, faultType__c, faultReason__c
                    FROM ActionRecommendationItem__r
                    WHERE isChecked__c = true)
                    FROM ActionRecommendation__c
                    WHERE RiskAnalyzeReport__c = :riskAnalyzeReportId
            ];

            System.debug('ActionRecommendation 조회 결과 수: ' + listActionRec.size());
            if (listActionRec.isEmpty()) {
                System.debug('WARNING: ActionRecommendation을 찾을 수 없습니다.');
            }

            // 5. Gemini API 요청 생성 및 호출
            String systemPrompt = buildSystemPrompt();
            String userPrompt = buildUserPrompt(strProductCode, listActionRec, availablePdfs, riskAnalyzeReportId);

            System.debug('System Prompt 길이: ' + systemPrompt.length());
            System.debug('User Prompt 길이: ' + userPrompt.length());

            Gemini2_5FlashApiController.Gemini2_5Request geminiRequest =
                    new Gemini2_5FlashApiController.Gemini2_5Request(systemPrompt, userPrompt, null);

            geminiRequest.generationConfig.temperature = 0.0;
            geminiRequest.generationConfig.maxOutputTokens = 4096;
            geminiRequest.generationConfig.responseMimeType = 'application/json';
            geminiRequest.generationConfig.responseSchema = getPdfSelectionResponseSchema();

            System.debug('Gemini API 호출 시작');
            String strResponse = Gemini2_5FlashApiController.askGemini2_5Flash(geminiRequest);
//            System.debug('Gemini API 응답: ' + strResponse);

            if (String.isBlank(strResponse)) {
                System.debug('ERROR: Gemini API 응답이 비어있습니다.');
                return null;
            }

            // 6. 응답 처리
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(strResponse);
            String selectedContentDocumentId = (String) responseMap.get('selectedContentDocumentId');

            System.debug('선택된 ContentDocument ID: ' + selectedContentDocumentId);

            if (String.isBlank(selectedContentDocumentId)) {
                System.debug('ERROR: 선택된 ContentDocument ID가 비어있습니다.');
                return null;
            }

            // 7. 검증
            for (ContentDocumentInfo pdfInfo : availablePdfs) {
                if (pdfInfo.contentDocumentId == selectedContentDocumentId) {
                    System.debug('SUCCESS: 유효한 PDF 선택됨 - ' + pdfInfo.title);
                    return Id.valueOf(selectedContentDocumentId);
                }
            }

            System.debug('ERROR: 선택된 PDF가 사용 가능한 목록에 없습니다.');
            return null;

        } catch (Exception e) {
            System.debug('ERROR: findProperPdf 실행 중 오류 발생: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            return null;
        }
    }

    /**
     * 시스템 프롬프트 생성
     */
    private static String buildSystemPrompt() {
        return '당신은 LSMtron의 사출성형기 전문 기술 지원 AI입니다. ' +
                '사출성형기의 구조, 작동 원리, 고장 패턴, 수리 방법에 대한 깊은 전문 지식을 보유하고 있습니다. ' +
                '제공된 위험 분석 결과와 권장 조치사항을 바탕으로, ' +
                'Manual__c에 있는 자가수리 매뉴얼 PDF 파일들 중에서 ' +
                '현재 상황에 가장 적합한 매뉴얼을 정확히 선택할 수 있습니다. ' +
                '제품 코드, 고장 유형, 수리 난이도, 안전성 등을 종합적으로 고려하여 ' +
                '최적의 매뉴얼을 추천해주세요. ' +
                '응답은 반드시 지정된 JSON 스키마 형식을 정확히 따라야 합니다.';
    }

    /**
     * 사용자 프롬프트 생성
     */
    private static String buildUserPrompt(String productCode,
            List<ActionRecommendation__c> actionRecommendations,
            List<ContentDocumentInfo> availablePdfs,
            Id riskAnalyzeReportId) {
        String prompt = '🔧 **자가수리 매뉴얼 선택 요청** 🔧\n\n';

        // 기본 정보
        prompt += '📋 **[기본 정보]**\n';
        prompt += '• 위험분석보고서 ID: ' + riskAnalyzeReportId + '\n';
        prompt += '• 제품 코드: ' + (String.isNotBlank(productCode) ? productCode.escapeXml() : 'N/A') + '\n\n';

        // 권장 조치사항
        prompt += '⚠️ **[권장 조치사항 데이터]**\n';
        if (actionRecommendations != null && !actionRecommendations.isEmpty()) {
            Integer actionNum = 1;
            for (ActionRecommendation__c action : actionRecommendations) {
                prompt += '--- 권장조치 #' + actionNum + ' ---\n';
                prompt += '• 분석 요약: ' + (action.AnalysisSummary__c != null ? action.AnalysisSummary__c.escapeXml() : 'N/A') + '\n';
                prompt += '-------------------------\n';
                actionNum++;
            }
        } else {
            prompt += '권장 조치사항 데이터가 없습니다.\n';
        }
        prompt += '\n';

        // 사용 가능한 PDF 매뉴얼 목록
        prompt += '📚 **[사용 가능한 자가수리 매뉴얼 PDF 목록]**\n';
        if (availablePdfs != null && !availablePdfs.isEmpty()) {
            Integer pdfNum = 1;
            for (ContentDocumentInfo pdfInfo : availablePdfs) {
                prompt += '--- PDF #' + pdfNum + ' ---\n';
                prompt += '• ContentDocument ID: ' + pdfInfo.contentDocumentId + '\n';
                prompt += '• 파일명: ' + (pdfInfo.title != null ? pdfInfo.title.escapeXml() : 'N/A') + '\n';
                prompt += '-------------------------\n';
                pdfNum++;
            }
        } else {
            prompt += '사용 가능한 PDF 매뉴얼이 없습니다.\n';
        }
        prompt += '\n';

        // 분석 요구사항
        prompt += '✅ **[분석 요구사항]**\n\n';
        prompt += '🚨 **반드시 JSON 형식으로만 응답하세요!** 🚨\n\n';
        prompt += '📋 **선택 기준:**\n';
        prompt += '1. 제품 코드와의 호환성\n';
        prompt += '2. 권장 조치사항과의 관련성\n';
        prompt += '3. 매뉴얼 제목에서 유추되는 적용 범위\n';
        prompt += '4. 사출성형기의 해당 시스템/부품과의 일치도\n';
        prompt += '5. 자가수리 가능성 및 안전성\n\n';

        prompt += '📊 **응답 형식:**\n';
        prompt += '```json\n';
        prompt += '{\n';
        prompt += '  "selectedContentDocumentId": "실제_ContentDocument_ID",\n';
        prompt += '  "reason": "선택 이유 간단 설명"\n';
        prompt += '}\n';
        prompt += '```\n\n';

        prompt += '🔍 **분석 지침:**\n';
        prompt += '• 제품 코드와 매뉴얼 파일명의 일치도 확인\n';
        prompt += '• 권장 조치사항과 매뉴얼 제목의 관련성 분석\n';
        prompt += '• 사출성형기 시스템별(유압, 전기, 기계 등) 매칭도 평가\n';
        prompt += '• 가장 적합한 하나의 ContentDocument ID만 선택하여 반환\n\n';

        return prompt;
    }

    /**
     * PDF 선택 응답을 위한 JSON 스키마 생성 (단순화)
     */
    private static Map<String, Object> getPdfSelectionResponseSchema() {
        return new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                        'selectedContentDocumentId' => new Map<String, Object>{
                                'type' => 'string',
                                'description' => '선택된 PDF의 ContentDocument ID'
                        },
                        'reason' => new Map<String, Object>{
                                'type' => 'string',
                                'description' => '선택 이유 (간단한 설명)'
                        }
                },
                'required' => new List<String>{'selectedContentDocumentId'}
        };
    }

    /**
     * ContentDocument 정보를 담는 내부 클래스
     */
    private class ContentDocumentInfo {
        public Id contentDocumentId;
        public String title;
    }
}