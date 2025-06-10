/**
 * Created by Jiae.Tak on 2025-05-29.
 */

import { LightningElement, track } from 'lwc';

export default class LwcSummaryManual extends LightningElement {
    @track manualSummary = {
       checklist: [
           "[센서] 이젝터 근접 센서 위치 및 케이블 상태 점검",
           "[실린더] 윤활 상태 확인 및 오일 누유 여부 확인",
           "[유압] 펌프 작동 온도 및 작동압력 체크",
           "[금형] 개폐 시 마찰음 또는 이탈 여부 확인"
       ],
       safetyNote: "자가 점검 시 위험 요소가 존재하므로, 점검 전 전원 차단 및 안전장비 착용을 권장합니다.",
       recommendations: [
           "유압계통(펌프, 실린더) 이상 진단 필요",
           "반복 발생 시, 전문 서비스팀 점검 권장",
           "설비 사용 주기에 따라 예방 정비 계획 수립 필요"
       ],
       services: [
           "자가 점검 매뉴얼 링크 제공",
           "유지보수 예약 연동 (Salesforce Service Cloud)"
       ]
   };
}