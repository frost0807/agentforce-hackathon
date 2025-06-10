/**
 * 수정된 TextPdfGeneratorController
 * - Custom Object ID를 받아 해당 레코드에서 텍스트 콘텐츠를 조회하도록 변경
 */
public without sharing class TextPdfGeneratorController {

    public String geminiResponseText { get; private set; }

    public TextPdfGeneratorController() {
        // 현재 페이지의 URL에서 contentRecordId 파라미터를 가져옵니다.
        String contentId = ApexPages.currentPage().getParameters().get('contentRecordId');

        if (String.isNotBlank(contentId)) {
            try {
                // ID를 이용해 PdfGenerationContent__c 레코드를 조회합니다.
                List<PdfGenerationContent__c> contentRecords = [
                        SELECT Content__c FROM PdfGenerationContent__c WHERE Id = :contentId LIMIT 1
                ];

                if (!contentRecords.isEmpty()) {
                    // 조회한 텍스트를 속성에 할당하고, 줄바꿈을 HTML 태그로 변경합니다.
                    this.geminiResponseText = contentRecords[0].Content__c.replace('\n', '<br/>');
                } else {
                    this.geminiResponseText = '오류: 유효하지 않은 콘텐츠 ID입니다.';
                }
            } catch (Exception e) {
                this.geminiResponseText = '오류: 콘텐츠를 조회하는 중 예외가 발생했습니다. ' + e.getMessage();
            }
        } else {
            this.geminiResponseText = '오류: 콘텐츠 ID가 전달되지 않았습니다.';
        }
    }
}