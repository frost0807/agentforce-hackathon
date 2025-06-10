/**
 * Created by 최준석 on 2025-05-27.
 */

import {LightningElement} from 'lwc';
import {ShowToastEvent} from "lightning/platformShowToastEvent";
import saveLoginUserId from '@salesforce/apex/PlatformCacheController.saveLoginUserId';
import getLoginUserId from '@salesforce/apex/PlatformCacheController.getLoginUserId';

export default class LwcCreateCache extends LightningElement {
    connectedCallback() {
        console.log('connectedCallback ::: IN');
        //현재 로그인한 사용자의 userId 저장
        saveLoginUserId().then(() =>
            getLoginUserId().then(data => console.log('getLoginUserId ::: ' + data)).catch(error => this.showToast('error', JSON.stringify(error)))
        ).catch(error => this.showToast('error', JSON.stringify(error)))
        console.log('connectedCallback ::: OUT');
    }

    showToast(variant, message) {
        const event = new ShowToastEvent({
            variant: variant,
            message: message,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}