import { handleError } from 'c/utils';
import { NavigationMixin } from 'lightning/navigation';
import { getDurationString } from 'c/dateTimeUtilities';
import { LightningElement, api, wire, track } from 'lwc';
import getRecordInfo from '@salesforce/apex/conversationViewHistoryController.getRecordInfo';

export default class ConversationViewHistoryDetail extends NavigationMixin(LightningElement) {

    @api recId;
    @api recordId;
    @api type;
    @api formFactor;
    
    @track recordObj = {};
    @track recordItems = [];
    @track wiredConvo = [];

    callObj = {};
    callParentType = 'DS_Denali__DialSource_Action__c';

    isCall = false;
    isEmail = false;
    isSMS = false;
    isCustom = false;
    isZoom = false;

    isEnterprise = true;
    isLoading = true;

    get durationUnit() {
        return this.callObj.callDuration < 60 ? 'seconds' : 'minutes';
    }

    get customStepTitle() {
        return `${this.recordObj?.RecordType?.Name} Details`
    }

    @wire(getRecordInfo, { recId: '$recId', itemType: '$type' })
    wiredGetRecordInfo(value) {
        this.wiredConvo = value;
        const { data, error } = value;
        //console.log('convo view data: ', JSON.stringify(data, null, '\t'));

        if(data && data.record) {
            this.recordObj = data.record;

            if(this.type === 'Call') {
                this.mapCallData(data);
            } else if(this.type === 'Email') {
                // Map convo record items to object and add 'id' prop
                this.recordItems = data.items.map(item => {
                    return {...item, id: this.recordId};
                });
            }
            //console.log('convo view items: ', JSON.stringify(this.recordObj.items, null, '\t'));

            this.setConvoType();
        } else if (error) {
            handleError(this, error, false);
        }

        this.isLoading = false;
    }


    mapCallData(data) {
        this.isEnterprise = data.isEnterprise;

        // common fields
        this.callObj.createdDate = data.record.CreatedDate;
        this.callObj.createdBy = data.record.CreatedBy.Name;
        this.callObj.createdById = data.record.CreatedById;
        this.callObj.lastModifiedBy = data.record.LastModifiedBy.Name;
        this.callObj.lastModifiedById = data.record.LastModifiedById;
        this.callObj.lastModifiedDate = data.record.LastModifiedDate;
        this.callObj.callRecId = data.callRecId;
        this.callObj.callRecName = data.callRecName;
        this.callObj.callRecType = data.callRecType;

        // package-specific fields
        let duration = this.isEnterprise 
                    ? data.record.DS_Denali__Call_Duration__c 
                    : data.record.CallDurationInSeconds;

        this.callObj.callDuration = getDurationString(duration == null ? 0 : duration);

        this.callObj.subject        = this.isEnterprise ? data.record.DS_Denali__Subject__c : data.record.Subject;
        this.callObj.date           = this.isEnterprise ? data.record.DS_Denali__Date__c : data.record.ActivityDate;
        this.callObj.phone          = this.isEnterprise ? data.record.DS_Denali__Phone__c : data.record.Description.slice( 7, data.record.Description.indexOf('\n') ).replace(/\D/g,'');
        this.callObj.ownerName      = this.isEnterprise ? data.record.DS_Denali__Owner__r?.Name : data.record.Owner?.Name;
        this.callObj.ownerId        = this.isEnterprise ? data.record.DS_Denali__Owner__c : data.record.OwnerId;
        this.callObj.status         = this.isEnterprise ? data.record.DS_Denali__Status__c : data.record.Status;
        this.callObj.notes          = this.isEnterprise ? data.record.DS_Denali__Notes__c : data.record.Description;
        this.callObj.recordingId    = this.isEnterprise ? data.record.DS_Denali__Recording_ID__c : data.record.DialSource__Recording_ID_DS__c;
    }

    setConvoType(){
        if (this.type === 'Email') {
            this.isEmail = true;
            return;
        }
        if (this.type === 'Call') {
            this.isCall = true;
            return;
        }
        if (this.type === 'SMS') {
            this.isSMS = true;
            return;
        }
        if (this.type === 'Custom') {
            this.isCustom = true;
            return;
        }
    }

    navigateToOwner(event) {
        const recId = this.callObj?.ownerId ? this.callObj.ownerId : this.recordObj?.OwnerId;
        
        if(recId) {
            this.navigate(recId, 'User');
        } else {
            console.log('No Owner Id found, exiting navigation.');
        }
    }

    navigateToRecord() {
        this.navigate(this.recId, this.callParentType);
    }

    navigateToCadence() {
        this.navigate(
            this.recordObj.DS_Packages__Cadence__c,
            'DS_Packages__Cadence__c'
        );
    }

    navigateToCallObj() {
        if(this.recordId === this.callObj.callRecId) {
            this.closeModal();
        } else {
            this.navigate(
                this.callObj.callRecId,
                this.callObj.callRecType
            );
        }
    }

    navigateToCreatedBy() {
        this.navigate(this.recordObj.CreatedById, 'User');
    }
    
    navigateToLastModifiedBy() {
        this.navigate(this.recordObj.LastModifiedById, 'User');
    }

    //function opens subtab if in lightning console
    //if not navigates to the record detail page
    navigate(targetId, targetType){
        this.invokeWorkspaceAPI('isConsoleNavigation').then(isConsole => {
            if(isConsole){
              this.invokeWorkspaceAPI('getFocusedTabInfo').then(focusedTab => {
                this.invokeWorkspaceAPI('openSubtab', {
                  parentTabId: focusedTab.tabId,
                  recordId: targetId,
                  focus: true
                }).then(tabId => {
                });
              });
            }else{
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: targetId,
                        objectAPIName: targetType,
                        actionName: 'view',
                    },
                });
            }
        });
    }

    openRecording() {
        let url = '/apex/DialSource__PlayRecording?id=' + this.recordObj.Id;
        url = this.isEnterprise ? url.replace('DialSource__', 'DS_Denali__') : url;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: url
            },
        });
    }

    //function dispatches a customevent using Salesforce ootb events
    //work around for getting information from the workspaceapi
    invokeWorkspaceAPI(methodName, methodArgs) {
        return new Promise((resolve, reject) => {
          const apiEvent = new CustomEvent("internalapievent", {
            bubbles: true,
            composed: true,
            cancelable: false,
            detail: {
              category: "workspaceAPI",
              methodName: methodName,
              methodArgs: methodArgs,
              callback: (err, response) => {
                if (err) {
                    return reject(err);
                } else {
                    return resolve(response);
                }
              }
            }
          });
          window.dispatchEvent(apiEvent);
        });
    }

    closeModal(){
        this.dispatchEvent(new CustomEvent('closemodal'));
    }
}