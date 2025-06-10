import { LightningElement } from 'lwc';
import Id from '@salesforce/user/Id';

export default class LwcEmbedded extends LightningElement {
    userId = Id;

    connectedCallback() {
        window.addEventListener("onEmbeddedMessagingReady", () => {
            if (
                typeof embeddedservice_bootstrap !== 'undefined' &&
                embeddedservice_bootstrap.prechatAPI
            ) {
                embeddedservice_bootstrap.prechatAPI.setHiddenPrechatFields({
                    "SalesforceUserID_Prechat": this.userId,
                    "SourcePage": "Main"
                });
                console.log("사전 채팅 API로 SalesforceUserID 전달됨:", this.userId);
            } else {
                console.error("embeddedservice_bootstrap.prechatAPI를 사용할 수 없습니다.");
            }
        });
    }
}