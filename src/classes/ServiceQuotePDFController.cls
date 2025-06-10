/************************************************************************************
 * File Name : SelfQuoteController.cls
 * Author : 최준석
 * Date : 2025-06-05
 * Description :
 * Modification Log
 * ===================================================================================
 * Ver      Date        Author      Modification
 * ===================================================================================
 * 1.0      2025-06-05  최준석         Create
 *************************************************************************************/
public class ServiceQuotePDFController {

    public String htmlContent { get; set; }

    public ServiceQuotePDFController() {
        // URL 파라미터에서 HTML 컨텐츠 받기
        this.htmlContent = ApexPages.currentPage().getParameters().get('htmlContent');

        if (String.isBlank(this.htmlContent)) {
            this.htmlContent = '<p>견적서 PDF 컨텐츠가 없습니다.</p>';
        }
    }
}