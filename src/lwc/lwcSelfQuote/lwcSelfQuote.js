// lwcSelfQuote.js
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getServiceQuoteData from '@salesforce/apex/SelfQuoteController.getServiceQuoteData';
import createPDFAndSendEmail from '@salesforce/apex/SelfQuoteController.createPDFAndSendEmail';
import getCurrentUser from '@salesforce/apex/SelfQuoteController.getCurrentUser';
import LSMTRON_LOGO from '@salesforce/resourceUrl/LSMtronLogo';

export default class LwcSelfQuote extends LightningElement {
    // 부모 컴포넌트의 스피너를 제어하기 위한 로딩 상태 관리
    _isLoading = true;
    @api
    get isLoading() {
        return this._isLoading;
    }
    set isLoading(value) {
        this._isLoading = value;
        // 로딩 상태 변경 시 부모에게 이벤트 디스패치
        this.dispatchEvent(new CustomEvent('loadingchange', {
            detail: { isLoading: value },
            bubbles: true, // 버블링하여 부모에서 감지
            composed: true // Shadow DOM 경계를 넘어 이벤트 전파
        }));
    }

    @api accountId; // 고객사 ID
    @api eventData = {}; // Platform Event 데이터

    @track serviceQuote = {}; // Service Quote 데이터
    @track lineItems = []; // Line Item 목록
    @track showSuccessMessage = false;
    @track successMessage = '';
    @track currentUser = {};

    accountName = '';
    contactName = '담당자명';
    totalAmount = 0;
    serviceQuoteId = ''; // 실제 사용할 Service Quote ID

    // 샘플 Service Quote ID
    SAMPLE_SERVICE_QUOTE_ID = 'a07Qy00000T0YzXIAV';

    // 회사 로고 URL
    companyLogoUrl = LSMTRON_LOGO;

    connectedCallback() {
        console.log('SelfQuote - Event data:', this.eventData);
        console.log('SelfQuote - Account ID:', this.accountId);
        console.log('🖼️ Company Logo URL:', this.companyLogoUrl);

        this.isLoading = true; // 초기화 시작
        this.determineServiceQuoteId();
        this.loadCurrentUser();
        this.loadServiceQuoteData();
    }

    // Service Quote ID 결정 (eventData에서 추출 또는 샘플 ID 사용)
    determineServiceQuoteId() {
        let extractedId = null;

        // eventData에서 Service Quote ID 추출 시도
        if (this.eventData && typeof this.eventData === 'object') {
            // 다양한 가능한 필드명에서 Service Quote ID 찾기
            extractedId = this.eventData.ServiceQuoteId__c ||
                         this.eventData.ServiceQuote__c ||
                         this.eventData.serviceQuoteId ||
                         this.eventData.Id; // 일반적인 Id 필드
        }

        // Service Quote ID가 없으면 샘플 ID 사용
        this.serviceQuoteId = extractedId || this.SAMPLE_SERVICE_QUOTE_ID;

        console.log('원본 Service Quote ID:', extractedId);
        console.log('사용할 Service Quote ID:', this.serviceQuoteId);

        if (!extractedId) {
            console.log('⚠️ Service Quote ID가 없어서 샘플 ID를 사용합니다.');
        }
    }

    // 현재 사용자 정보 조회
    async loadCurrentUser() {
        try {
            this.currentUser = await getCurrentUser();
            this.contactName = this.currentUser.Name || '담당자명';
        } catch (error) {
            console.error('사용자 정보 조회 오류:', error);
        }
    }

    // Service Quote 데이터 조회 (수정된 메서드)
    async loadServiceQuoteData() {
        if (!this.serviceQuoteId) {
            this.showToast('Warning', 'Service Quote 정보가 필요합니다.', 'warning');
            this.isLoading = false;
            return;
        }

        try {
            // serviceQuoteId를 직접 전달
            const data = await getServiceQuoteData({
                serviceQuoteId: this.serviceQuoteId,
                accountId: this.accountId // accountId는 선택적 파라미터로 유지
            });

            this.serviceQuote = data.serviceQuote || {};
            this.lineItems = this.formatLineItems(data.lineItems || []);
            this.accountName = data.accountName || '고객사명';
            this.calculateTotalAmount();

        } catch (error) {
            console.error('견적서 데이터 조회 오류:', error);
            this.showToast('Error', '견적서 데이터를 불러올 수 없습니다.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Line Item 데이터 포맷팅
    formatLineItems(items) {
        return items.map((item, index) => ({
            ...item,
            displayIndex: index + 1,
            ProductName: item.ProductId__r?.Name || '제품명',
            ProductClassification: item.ProductId__r?.ProductClassification__c || '분류',
            formattedUnitPrice: this.formatCurrency(item.UnitPrice__c),
            formattedTotalPrice: this.formatCurrency((item.UnitPrice__c || 0) * (item.Quantity__c || 0))
        }));
    }

    // 총 금액 계산
    calculateTotalAmount() {
        this.totalAmount = this.lineItems.reduce((total, item) =>
            total + ((item.UnitPrice__c || 0) * (item.Quantity__c || 0)), 0);
    }

    // 총 수량 계산
    get totalQuantity() {
        if (this.hasLineItems) {
            return this.lineItems.reduce((total, item) =>
                total + (item.Quantity__c || 0), 0);
        }
        // 샘플 데이터의 총 수량
        return 14;
    }

    // 라인 아이템이 있는지 확인
    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    // 견적 날짜 포맷팅
    get formattedQuoteDate() {
        if (!this.serviceQuote.QuoteDate__c) return '';
        const date = new Date(this.serviceQuote.QuoteDate__c);
        return date.toLocaleDateString('ko-KR', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        });
    }

    // 총 금액 포맷팅
    get formattedTotalAmount() {
        if (this.hasLineItems) {
            return this.formatCurrency(this.totalAmount);
        }
        // 샘플 데이터의 총 금액 (42,080,000원)
        return this.formatCurrency(42080000);
    }

    // 통화 포맷팅
    formatCurrency(amount) {
        if (amount == null || amount === '') return '0';
        return new Intl.NumberFormat('ko-KR').format(amount);
    }

    // PDF 다운로드 (브라우저 인쇄)
    handleDownloadPDF() {
        try {
            window.print();
        } catch (error) {
            console.error('PDF 다운로드 오류:', error);
            this.showToast('Error', 'PDF 다운로드 중 오류가 발생했습니다.', 'error');
        }
    }

    // 부품 주문 처리 (PDF 생성 + 메일 발송 + 파일 저장)
    async handleCreateOrder() {
        if (!this.serviceQuoteId) {
            this.showToast('Warning', '견적서 정보가 없습니다.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            // PDF 생성, 메일 발송, 파일 저장 처리
            const result = await createPDFAndSendEmail({
                serviceQuoteId: this.serviceQuoteId, // serviceQuote.Id 대신 serviceQuoteId 사용
                recipientEmail: this.currentUser.Email
            });

            if (result.success) {
                this.successMessage = `주문이 완료되었습니다. ${this.currentUser.Email}로 견적서가 발송되었습니다.`;
                this.showSuccessMessage = true;
                this.showToast('Success', this.successMessage, 'success');

                // 5초 후 성공 메시지 숨김
                setTimeout(() => {
                    this.showSuccessMessage = false;
                }, 5000);
            } else {
                this.showToast('Error', result.message || '주문 처리 중 오류가 발생했습니다.', 'error');
            }

        } catch (error) {
            console.error('주문 처리 오류:', error);
            this.showToast('Error', '주문 처리 중 오류가 발생했습니다.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // 돌아가기 (Platform Event로 부품 선택 화면으로)
    handleGoBack() {
        // TODO: Platform Event 발송하여 LwcPartSelect로 화면 전환
        console.log('돌아가기 - Platform Event 발송 필요');
        this.showToast('Info', '부품 선택 화면으로 돌아갑니다.', 'info');
    }

    // 이미지 로드 관련 핸들러들
    handleImageLoad(event) {
        console.log('✅ 이미지 로드 성공:', event.target.src);
    }

    handleImageError(event) {
        console.error('❌ 이미지 로드 실패:', event.target.src);
        console.error('Error details:', event);
        // 이미지 로드 실패 시 URL을 null로 설정하여 텍스트 로고 표시
        this.companyLogoUrl = null;
    }

    // Toast 메시지 표시
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}