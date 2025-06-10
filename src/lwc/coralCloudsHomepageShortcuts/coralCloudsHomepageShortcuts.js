import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import workshopDetails from "@salesforce/resourceUrl/workshopDetails";
import { loadScript } from "lightning/platformResourceLoader";
import USER_ID from "@salesforce/user/Id";
import USER_NAME from "@salesforce/schema/User.Username";

const navigationItemsWithoutChapters = [{ label: "Home", value: "home" }];

export default class CoralCloudsHomepageShortcuts extends NavigationMixin(LightningElement) {
  userId = USER_ID;
  navigationItems = navigationItemsWithoutChapters;
  selectedItem = "home";
  libInitialized = false;
  workshopData = [];
  selectedWorkshop;

  async renderedCallback() {
    if (this.libInitialized) {
      return;
    }
    this.libInitialized = true;
    try {
      await loadScript(this, workshopDetails);
      // eslint-disable-next-line no-undef
      this.workshopData = workshopData.getData();
    } catch (e) {
      throw new Error("Failed to load workshop data: " + e, e);
    }
  }

  @wire(getRecord, { recordId: "$userId", fields: [USER_NAME] })
  user;

  handleNavSelect(event) {
    const name = event.detail;
    this.selectedItem = name;
    if (name !== "home") {
      this.selectedWorkshop = this.workshopData.find((workshop) => workshop.name === this.selectedItem);
    }
  }

  view(event) {
    const viewType = event.currentTarget.dataset.type;
    let url;
    if (viewType === "url") {
      url = event.currentTarget.dataset.url;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url
      }
    });
  }

  handleCopy(event) {
    const text = event.currentTarget.dataset.content;
    navigator.clipboard
      .writeText(text)
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Text copied to clipboard",
            variant: "success"
          })
        );
      })
      .catch((error) => {
        console.error("Failed to copy text: ", error);
      });
  }


  get userName() {
    return getFieldValue(this.user.data, USER_NAME);
  }

  get showHome() {
    return this.selectedItem === "home";
  }
}