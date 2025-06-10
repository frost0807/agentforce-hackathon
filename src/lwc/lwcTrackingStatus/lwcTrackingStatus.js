import { LightningElement, track, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getTrackingInfo from '@salesforce/apex/TrackingStatusController.getTrackingInfo';

export default class LwcTrackingStatus extends LightningElement {
    @track _trackingId;
    isLoading = false;
    trackingData;
    errorMessage;
    wiredResult; // wire 결과를 저장할 변수

    // trackingId getter/setter로 변경 감지
    @api
    get trackingId() {
        return this._trackingId;
    }

    set trackingId(value) {
        console.log('trackingId setter called with value:', value);
        const oldValue = this._trackingId;
        this._trackingId = value;

        // 값이 변경되었을 때만 로딩 처리
        if (oldValue !== value && value) {
            console.log('trackingId changed from', oldValue, 'to', value);
            this.handleTrackingIdChange();
        }
    }

    // 컴포넌트 연결시 실행
    connectedCallback() {
        console.log('OrderDetail connected with recordId:', this._trackingId);
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            // c__ prefix 사용
            const newTrackingId = currentPageReference.state?.c__trackingId;
            if (newTrackingId && newTrackingId !== this._trackingId) {
                console.log('URL parameter changed to:', newTrackingId);
                this.trackingId = newTrackingId; // setter를 통해 변경 감지
            }
        }
    }

    // trackingId 변경 시 호출되는 핸들러
    handleTrackingIdChange() {
        console.log('handleTrackingIdChange called for trackingId:', this._trackingId);
        this.isLoading = true;
        this.errorMessage = null;
        this.trackingData = null;

        // 기존 wire 결과가 있다면 새로고침
        if (this.wiredResult) {
            console.log('Refreshing existing wire data');
            refreshApex(this.wiredResult)
                .then(() => {
                    console.log('Wire data refreshed successfully');
                })
                .catch(error => {
                    console.error('Error refreshing wire data:', error);
                    this.handleError(error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    // Wire로 배송정보 조회
    @wire(getTrackingInfo, { recordId: '$_trackingId' })
    wiredTrackingInfo(result) {
        console.log('wiredTrackingInfo called with trackingId:', this._trackingId);
        this.wiredResult = result;

        if (result.data) {
            console.log('Wire data received:', JSON.stringify(result.data));
            if (result.data.success) {
                this.trackingData = result.data;
                console.log('this.trackingData ::: ' + JSON.stringify(this.trackingData));
                console.log('Provider Events:', JSON.stringify(this.trackingData.listProviderEvent));
                this.errorMessage = null;
            } else {
                this.errorMessage = result.data.errorMessage;
                this.trackingData = null;
            }
        } else if (result.error) {
            this.errorMessage = '배송정보 조회 중 오류가 발생했습니다.';
            this.trackingData = null;
            console.error('Wire error:', result.error);
        }

        this.isLoading = false;
        console.log('wiredTrackingInfo completed');
    }

    //마일스톤 정보 - 수정됨
    get progressSteps() {
        console.log('get progressSteps ::: IN');

        if (!this.trackingData || !this.trackingData.listMileStone) {
            return [];
        }

        const steps = this.trackingData.listMileStone.map(
            obj => ({
                id: obj.Sequence__c,
                label: obj.Key_Stage_Kor__c || obj.Key_Stage__c,
                Sequence__c: obj.Sequence__c
            })
        );
        console.log('steps ::: ' + JSON.stringify(steps));

        const totalSteps = steps.length;
        const currentStep = this.trackingData.currentStep || 1;

        console.log('currentStep from backend:', currentStep);
        console.log('totalSteps:', totalSteps);

        return steps.map((step, index) => {
            // 원의 중심점 위치 계산
            let centerPosition;
            if (totalSteps === 1) {
                centerPosition = 50;
            } else if (index === 0) {
                centerPosition = 1.5;
            } else if (index === totalSteps - 1) {
                centerPosition = 98.5;
            } else {
                centerPosition = 1.5 + (index / (totalSteps - 1)) * 97;
            }

            // 마일스톤 완료 여부를 실제 데이터로 확인
            let isActive = false;
            if (this.trackingData.listMileStone) {
                const milestone = this.trackingData.listMileStone.find(
                    m => m.Sequence__c === step.Sequence__c
                );
                isActive = milestone && milestone.Time_ISO__c != null;
            }

            return {
                ...step,
                stepClass: isActive ? 'progress-step active' : 'progress-step',
                stepStyle: `position: absolute; left: ${centerPosition}%; transform: translateX(-50%);`,
                centerPosition: centerPosition,
                isActive: isActive
            };
        });
    }

    // 날짜시간 포맷팅 - yyyy-mm-dd hh:mm 형식
    formatEventDateTime(dateTimeString) {
        if (!dateTimeString) return '';

        try {
            const date = new Date(dateTimeString);
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');

            return `${year}-${month}-${day} ${hours}:${minutes}`;
        } catch (error) {
            console.error('Date formatting error:', error);
            return dateTimeString;
        }
    }

    // 운송사 기록에 표시할 이벤트 리스트 (날짜 포맷팅 및 한글 설명 적용)
    get formattedProviderEvents() {
        if (!this.trackingData || !this.trackingData.listProviderEvent) {
            return [];
        }

        return this.trackingData.listProviderEvent.map(event => {
            console.log('Event data:', JSON.stringify(event));

            // 여러 방식으로 한글 설명 접근 시도
            let korDescription = null;

            // 방법 1: 직접 접근
            korDescription = event.Description_Kor__c;

            // 방법 2: 대괄호 접근
            if (!korDescription) {
                korDescription = event['Description_Kor__c'];
            }

            // 방법 3: 속성 이름 변형 확인
            if (!korDescription) {
                const keys = Object.keys(event);
                const korKey = keys.find(key => key.toLowerCase().includes('description_kor'));
                if (korKey) {
                    korDescription = event[korKey];
                    console.log('Found Korean description with key:', korKey, 'value:', korDescription);
                }
            }

            console.log('Final Korean description:', korDescription);

            return {
                ...event,
                formattedDateTime: this.formatEventDateTime(event.Event_Time__c),
                displayDescription: korDescription || event.Description__c || '',
                displayText: `${korDescription || event.Description__c} ${this.formatEventDateTime(event.Event_Time__c)}`
            };
        });
    }

    // 현재 단계 라벨 - 수정됨
    get currentStepLabel() {
        if (!this.trackingData || !this.trackingData.listMileStone) {
            return '배송준비중';
        }

        const currentStep = this.trackingData.currentStep || 1;
        const currentMilestone = this.trackingData.listMileStone.find(
            milestone => milestone.Sequence__c === currentStep
        );

        return currentMilestone?.Key_Stage_Kor__c ||
               currentMilestone?.Key_Stage__c ||
               '배송준비중';
    }

    // 프로그레스 바 스타일 - 완료된 마일스톤까지만 진행도 표시
    get progressLineStyle() {
        if (!this.trackingData || !this.progressSteps || this.progressSteps.length === 0) {
            return 'width: 0%;';
        }

        const steps = this.progressSteps;
        const currentStep = this.trackingData.currentStep || 0;
        const totalSteps = steps.length;

        console.log('Progress calculation - currentStep:', currentStep, 'totalSteps:', totalSteps);

        if (currentStep <= 0) {
            return 'width: 0%;';
        }

        // 완료된 마일스톤 중 가장 높은 단계까지만 진행도 표시
        let maxCompletedPosition = 0;

        if (this.trackingData.listMileStone) {
            for (let milestone of this.trackingData.listMileStone) {
                if (milestone.Time_ISO__c) {
                    const completedStep = steps.find(step => step.id === milestone.Sequence__c);
                    if (completedStep && completedStep.centerPosition > maxCompletedPosition) {
                        maxCompletedPosition = completedStep.centerPosition;
                    }
                }
            }
        }

        // 완료된 단계가 없으면 첫 번째 단계까지만
        if (maxCompletedPosition === 0 && steps.length > 0) {
            maxCompletedPosition = steps[0].centerPosition;
        }

        console.log('Progress width:', maxCompletedPosition + '%');
        return `width: ${maxCompletedPosition}%;`;
    }

    // 에러 상태 확인
    get hasError() {
        return !!this.errorMessage;
    }

    // 로딩 상태 확인
    get isDataLoaded() {
        return !!this.trackingData && !this.isLoading;
    }

    // 수동 새로고침 메서드 (필요시 외부에서 호출 가능)
    @api
    refreshTrackingData() {
        console.log('Manual refresh requested');
        if (this._trackingId) {
            this.handleTrackingIdChange();
        }
    }

    // 토스트 메시지 표시
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    // 에러 처리
    handleError(error) {
        console.error('Error in OrderDetail component:', error);
        this.errorMessage = '컴포넌트 처리 중 오류가 발생했습니다.';
        this.isLoading = false;
    }
}