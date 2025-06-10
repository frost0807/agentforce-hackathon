/**
 * Created by Jiae.Tak on 2025-05-28.
 */

import { LightningElement, track, api } from 'lwc';
import getInit from '@salesforce/apex/SelfCheckController.getInit';
import updateSelfCheckItems from '@salesforce/apex/SelfCheckController.updateSelfCheckItems';
export default class LwcSelfCheckList extends LightningElement {
    uuid;
    @api eventData = {};
    @track checklist = [];
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
            bubbles: true,
            composed: true
        }));
    }

    connectedCallback() {
        this.getUUIDToSFId();
        if(this.uuid){
            this.isLoading = true;
            this.getInit();
        }else{
            this.isLoading = false;
        }
    }

    getUUIDToSFId() {
        const urlParams = new URLSearchParams(window.location.search);
        const jsonString = urlParams.get('c__jsonString');
        if (jsonString) {
            try {
                const parsed = JSON.parse(decodeURIComponent(jsonString));
                this.uuid = parsed.uuid;
                console.log('Extracted UUID:', this.uuid);
            } catch (e) {
                console.error('Error parsing jsonString:', e);
            }
        }
    }

    async getInit(){
        console.log('LwcSelfCheckList getInit !! ');
        this.isLoading = true;
        try {
            const result = await getInit({ uuid: this.uuid });
            console.log('result : ' + JSON.stringify(result));
            if(result){
                if (result.selfCheckItems) {
                    this.checklist = result.selfCheckItems.map(item => ({
                        id: item.Id,
                        detail: item.Description__c,
                        isCheck: false
                    }));
                }

                if(result.objReport){
                    this.objReport = result.objReport;
                }
            }
            console.log('getInit this.checklist: ' + JSON.stringify(this.checklist));
        } catch (error) {
            console.error('Error retrieving self check items:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleCheckboxChange(event) {
        const index = event.target.dataset.index;
        const isChecked = event.target.checked;

        const updatedChecklist = [...this.checklist];
        if (updatedChecklist[index]) {
            updatedChecklist[index] = {
                ...updatedChecklist[index],
                isCheck: isChecked
            };
            this.checklist = updatedChecklist;
            console.log('handleCheckboxChange this.checklist : ' + JSON.stringify(this.checklist));
        } else {
            console.warn(`Attempted to update item at invalid index: ${index}`);
        }
    }

    async handleSubmit (event) {
        const checkedItemIds = this.checklist
              .filter(item => item.isCheck)
              .map(item => item.id);
        console.log('checkedItemIds 1: ' + JSON.stringify(checkedItemIds));
        if (checkedItemIds.length > 0) {
            try {
                console.log('checkedItemIds : ' + JSON.stringify(checkedItemIds));
                const result = await updateSelfCheckItems({ itemIds: checkedItemIds });
                if(result.status == 'SUCCESS'){
                    /* 부모 lwc event 전달 */
                    const selfCheckCompletedEvent = new CustomEvent('selfcheckcompleted');
                    this.dispatchEvent(selfCheckCompletedEvent);
                }
            } catch (error) {
                console.error('Error updating self check items:', error);
            }
        } else {
            console.error('Info', '업데이트할 체크된 항목이 없습니다.', error);
        }
    }

   get isSubmitDisabled() {
        return !this.checklist.some(item => item.isCheck);
    }
}