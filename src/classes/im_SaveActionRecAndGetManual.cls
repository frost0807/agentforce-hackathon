/**
 * Created by 최준석 on 2025-06-08.
 */
public class im_SaveActionRecAndGetManual {
    @InvocableMethod(
            Label='추천행동 저장 및 자가수리 매뉴얼 생성'
            Description='추천행동을 저장하고 자가수리 매뉴얼을 생성합니다.'
            Category='추천 행동'
    )
    public static List<Response> saveActionRec(List<Request> listRequest) {
        Request objRequest = listRequest[0];
        Response objResponse;
        MessagingSession objMessagingSession = AgentronAnalysisController.getMessagingSession(objRequest.messagingSessionId);

        PublishMessageController.publishMessage('ACTION_REC_SAVE', '');
        waitForSeconds(5);

        Id contentDocumentId = prpt_FindProperPdf.findProperPdf(objMessagingSession.RiskAnalyzeReportId__c);
        if (contentDocumentId != null) {
            String strResponse = prpt_GenerateManualSummary.generateManualSummary(contentDocumentId, objMessagingSession.RiskAnalyzeReportId__c);
            if (String.isNotBlank(strResponse)) {
                // [핵심 수정] PDF 생성 대신 간단한 텍스트 파일을 생성하는 메서드 호출
                objResponse = generateSimpleTextFile(strResponse, objMessagingSession.RiskAnalyzeReportId__c);

                if (objResponse.message.contains('생성했습니다')) {
                    PublishMessageController.publishMessage('ACTION_REC_ACTIVE_DOWNLOAD', '');
                }
            } else {
                objResponse = new Response('매뉴얼 요약 내용을 생성하지 못했습니다.');
            }
        } else {
            objResponse = new Response('해당하는 원본 PDF파일이 존재하지 않습니다.');
        }
        return new List<im_SaveActionRecAndGetManual.Response>{ objResponse };
    }

    private static void waitForSeconds(Integer seconds) {
        Long startTime = System.currentTimeMillis();
        Long endTime = startTime + (seconds * 1000);
        while (System.currentTimeMillis() < endTime) {}
    }

    /**
     * [단순화된 메서드] 텍스트 콘텐츠로 .txt 파일을 생성하고 저장합니다.
     */
    private static Response generateSimpleTextFile(String content, Id reportId) {
        System.debug('=== 텍스트 파일 생성 시작 ===');
        try {
            // 파일 내용 구성
            String textContent = 'LSMtron 자가수리 매뉴얼\n========================\n\n';
            textContent += '생성일시: ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss') + '\n';
            textContent += '보고서 ID: ' + reportId + '\n';
            textContent += '========================\n\n';
            textContent += content; // AI가 생성한 요약 내용

            // 파일 이름 지정
            String fileName = '자가수리매뉴얼_텍스트_' + Datetime.now().format('yyyyMMdd_HHmmss');

            // ContentVersion으로 파일 생성
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.txt'; // 확장자를 .txt로 지정
            cv.VersionData = Blob.valueOf(textContent); // 텍스트를 Blob으로 변환
            cv.IsMajorVersion = true;
            insert cv;

            // 생성된 파일을 레코드에 연결
            ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = reportId;
            cdl.ContentDocumentId = insertedCV.ContentDocumentId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            return new Response('텍스트 매뉴얼 파일을 생성했습니다.');
        } catch (Exception e) {
            System.debug('텍스트 파일 생성 중 오류 발생: ' + e.getMessage());
            return new Response('파일 생성에 실패했습니다: ' + e.getMessage());
        }
    }

    // Request, Response 내부 클래스는 기존과 동일하게 유지
    public class Request {
        @InvocableVariable public Id loginUserId;
        @InvocableVariable public Id messagingSessionId;
        @InvocableVariable public String currentPageUrl;
    }
    public class Response {
        @InvocableVariable public String message;
        public Response(String message) { this.message = message; }
    }
}