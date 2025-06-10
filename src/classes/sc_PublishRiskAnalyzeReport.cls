/************************************************************************************
 * File Name        : sc_PublishRiskAnalyzeReport.cls
 * Author           : 최준석
 * Date             : 2025-05-31
 * Description      : Account 데이터를 청크별로 Gemini API에 직접 요청하여 분석하는 Batch Apex(`ba_PublishRiskAnalyzeReport`)를 호출합니다.
 * Cron             : String CRON_EXPRESSION = '0 0 0 ? * SUN *'; // 매주 일요일 00:00
 * // System.schedule('주간 위험 분석 보고서 발행 (Gemini 직접 호출)', CRON_EXPRESSION, new sc_PublishRiskAnalyzeReport());
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-05-31      최준석           Create
*************************************************************************************/
public class sc_PublishRiskAnalyzeReport implements Schedulable {
    public void execute(SchedulableContext sc) {
        System.debug('sc_PublishRiskAnalyzeReport: Account 청크별 Gemini API 직접 호출 작업 시작.');
        Integer accountsPerChunk = 100;

        ba_PublishRiskAnalyzeReport batchJob = new ba_PublishRiskAnalyzeReport(); // 생성자 파라미터 제거 (필요시 추가)
        Database.executeBatch(batchJob, accountsPerChunk);

        System.debug('ba_PublishRiskAnalyzeReport 작업이 시작되었습니다. 청크당 Account 수: ' + accountsPerChunk);
    }
}