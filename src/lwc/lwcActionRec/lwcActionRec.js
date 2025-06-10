/**
 * Created by Jiae.Tak on 2025-05-29.
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import processActionRecAndProduct from '@salesforce/apex/ActionRecommendController.processActionRecAndProduct';
import updateActionRecommendationItems from '@salesforce/apex/ActionRecommendController.updateActionRecommendationItems';
import getDocumentDataForDownload from '@salesforce/apex/ActionRecommendController.getDocumentDataForDownload';

export default class LwcActionRec extends LightningElement {
    _isLoading = true;
    @api showDownloadButton = false;
    @api reportId = '';

    @track recommendList = [];
    @track errorMessage = '';
    @track analysisSummary = '';
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

    connectedCallback() {
        if (this.reportId) {
            this.getInit();
        }
    }

    async getInit() {
        this.isLoading = true;
        try {
            const result = await processActionRecAndProduct({ reportId: this.reportId });
            if (result.hasPredictions) {
                this.recommendList = result.recommendedActions.map(item => ({
                    id: item.Id,
                    actionIndex: item.actionIndex,
                    type: item.faultType,
                    subType: item.faultDetailType,
                    reason: item.faultReason,
                    location: item.faultLocation,
                    action: item.actionDescription,
                    partsNeeded: item.partsNeeded,
                    isChecked: item.isChecked
                }));
                this.analysisSummary = result.analysisSummary || '';
            } else {
                this.showToast('알림', result.message || '추천 데이터를 로드하지 못했습니다.', 'warning');
            }
        } catch (error) {
            this.showToast('오류', '데이터 로드 중 오류가 발생했습니다.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get recommendItem() {
        return this.recommendList.map(item => ({
            ...item,
            cssClass: item.isChecked ? 'item checked' : 'item',
            formattedPartsNeeded: item.partsNeeded && Array.isArray(item.partsNeeded) ?
                item.partsNeeded.map(part => part.quantity ? `${part.productCode}(${part.quantity})` : part.productCode).join(', ') : ''
        }));
    }

    get checkedCount() {
        return this.recommendList.filter(item => item.isChecked).length;
    }

    handleItemClick(event) {
        const clickedId = event.currentTarget.dataset.id;
        this.recommendList = this.recommendList.map(item => {
            if (String(item.actionIndex) === clickedId) {
                return { ...item, isChecked: !item.isChecked };
            }
            return item;
        });
    }

    // [이름 변경] handleDownloadPDF -> handleDownloadManual
    async handleDownloadManual() {
        if (!this.reportId) {
            this.showToast('오류', '보고서 ID가 없습니다.', 'error');
            return;
        }
        this.isLoading = true;
        try {
            const result = await getDocumentDataForDownload({ reportId: this.reportId });
            if (result && result.success && result.files.length > 0) {
                const fileToDownload = result.files[0];
                this.downloadFile(fileToDownload);
                this.showToast('성공', `${fileToDownload.fileName} 다운로드가 시작됩니다.`, 'success');
            } else {
                this.showToast('오류', result.message || '다운로드할 파일이 없습니다.', 'error');
            }
        } catch (error) {
            this.showToast('오류', '다운로드 중 오류가 발생했습니다: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    downloadFile(fileInfo) {
        const byteCharacters = atob(fileInfo.base64Data);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: 'application/octet-stream' });

        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = `${fileInfo.fileName}.${fileInfo.fileType}`; // .txt 확장자로 다운로드됨
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    // handleSubmit, doSave, showToast 등 나머지 함수들은 기존과 동일하게 유지
    async handleSubmit(event) {
        this.isLoading = true;
        const selectedItemIds = this.recommendList.filter(item => item.isChecked).map(item => item.id);
        try {
            const updateResult = await updateActionRecommendationItems({ itemIds: selectedItemIds });
            if (updateResult.success) {
                this.showToast('성공', '선택한 항목이 저장되었습니다.', 'success');
                // this.dispatchEvent(new CustomEvent('actionreccompleted'));
            } else {
                this.showToast('오류', updateResult.message || '항목 업데이트에 실패했습니다.', 'error');
            }
        } catch (error) {
            this.showToast('오류', '항목 업데이트 중 오류가 발생했습니다.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    @api
    doSave() {
        this.handleSubmit();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}