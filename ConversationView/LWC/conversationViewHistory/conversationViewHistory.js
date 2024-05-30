import { handleError } from 'c/utils';
import { refreshApex } from '@salesforce/apex';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getOrgId from '@salesforce/apex/EmailModalController.getOrgId';
import { reportDateRangeValidity } from 'c/dateTimeUtilities';
import getVFOrigin from '@salesforce/apex/CadenceWorkspaceController.getVFOrigin';
import getSettings from '@salesforce/apex/CadenceUtilitiesController.getConquerSettings';
import getRecords from '@salesforce/apex/conversationViewHistoryController.getConvoHistory';

import { publishGenMessage } from 'c/lmsUtils';
import { subscribe, MessageContext } from 'lightning/messageService';
import CONQUER_MESSAGE_CHANNEL from '@salesforce/messageChannel/Conquer_Message_Channel__c';

// business logic + state management
import { 
    convoArrayItemCount, 
    clearAndCloseSearch,
    formatEmailData,
    handleScroll,
    sendEmailReply
 } from './utilities/helpers.js';

 // constant vars
import { 
    DATE_FILTERS, 
    DETAIL_MODAL_TITLE,
    DOCKED_COMPOSER_ENABLED,
    FILTER_CLASSES,
    TYPE_FILTERS,
} from './utilities/constants.js';

// sorting + filter methods
import { 
    clearAllFilters,
    groupWiredConvos,
    handleDateChange,
    searchConversations, 
    toggleFiltersModal
} from './utilities/filterSortHelpers.js';


export default class ConversationViewHistory extends LightningElement {
    // public properties 1-3 required for mobile access
    @api prop1;
    @api prop2;
    @api prop3;
    @api recordId;

    // tracked properties - objects + arrays
    @track type;
    @track recId;
    @track convoData = [];
    @track conversations = [];
    @track subscription = null;

    // scroll pagination properties
    offSet = 0;
    limitSize = 10;
    queryMore = true;
    isLoading = true;
    hasScrolled = false;

    // filter properties
    endDate = '';
    startDate = '';
    searchKey = '';
    filterType = 'All';
    filterDate = 'All';

    totalConvoEntries = 0;
    filterClass = FILTER_CLASSES;

    // drill down "detail" modal properties
    detailHeaderTitle;
    openRecordDetail = false;

    @track wiredConvos = [];

    @wire(getOrgId) orgId;
    @wire(getSettings) orgSettings;
    @wire(CurrentPageReference) pageRef;
    @wire(getVFOrigin) siteUrl; //use vf page url as iframe src

    // wire message context so that it destructs on unmount
    @wire(MessageContext) messageContext;

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    renderedCallback() {}

    disconnectedCallback() {}

    get formFactor() {
        return FORM_FACTOR;
    }

    /**
     * Wire method that retrieves conversation records based on provided parameters.
     * @param {Object} value Wire method's response, containing data and error.
    */
    @wire(getRecords, {
        limitSize: '$limitSize',
        offSet: '$offSet',
        recId: '$recordId',
        filterType: '$filterType',
        filterDate: '$filterDate',
        startDate: '$startDate',
        endDate: '$endDate'
    })
    wiredData(value) {
        this.isLoading = true;
        this.wiredConvos = value;
        const { data, error } = value;
        if( data ) {
            this.convoData = data;
            // group conversations by created date
            this.conversations = groupWiredConvos(this, this.convoData);
            // reduce array and count number of items across all convos
            this.totalConvoEntries = convoArrayItemCount(this.conversations);

            if (this.totalConvoEntries === 0){
                this.queryMore = false;
                this.isLoading = false;
                return;
            }

            this.hasScrolled = false;
            this.isLoading = false;
            
        } else if(error) {
            this.isLoading = false;
            handleError(error);
        }
    }

    /**
     * Returns an array of conversations whose body, subject, phone, or email include 
     * the search query, sorted by created date, newest to oldest (descending).
     * If no search query is provided, returns all conversations sorted by created date.
     * @returns {Object[]} An array of conversations with values meeting the search criteria.
    */
    get conversationThreads() {
        const query = this.searchKey ? this.searchKey.toLowerCase() : null;
        if (this.totalConvoEntries === 0 || !query) {
            return this.conversations;
        }
        return searchConversations(this, this.conversations, query);
    }

    /**
     * Returns true if record has no conversation items, either by filter or fact.
     * @returns {Boolean} An indicator of whether or not this record has no conversations.
    */
    get showNoData() {
        return convoArrayItemCount(this.conversationThreads) === 0;
    }

    /**
     * Handles scroll event in conversationView div with `container` class. We delegate
     * the behavioral logic to the `handleScroll` utility method in `helpers.js`.
     * @param {Event} event - Browser event triggered by the user's scrolling.
    */
    onScrollEvent(event) {
        handleScroll(this);
    }

    /**
     * Handles the search input event when the user enters a search query.
     * @param {CustomEvent} event - The custom event whose detail contains search input.
    */
    handleSearchInput(event) {
        const { input, inputKey } = event.detail;
        this.searchKey = input;
        const keyPressed = inputKey; // indicates key pressed on keyboard
        //console.log(`key pressed: ${inputKey} search input: ${input}`);
    }

    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            CONQUER_MESSAGE_CHANNEL,
            (message) => this.handleLmsMessage(message)
        );
    }

    /**
     * Subscribes to the Conquer Message Channel and handles incoming LMS messages.
     * @param {object} message - The incoming Lightning Message Service message.
    */
    handleLmsMessage(message) {
        console.debug('Conquer Conversation View received LMS message:', JSON.stringify(message));
    
        switch(message?.event) {
            case 'cadenceActionsRefreshed':
            case 'cadenceUtilitiesRefreshed':
            case 'salesEngagementsRefreshed':
                this.handleRefresh(false);
                break;
            default:
                console.debug('received message with no matching handler method');
        }
    }
    
    
    /**
     * Handles clicks on conversation items, opening detailed views or initiating email replies.
     * @param {Event} event - The event object representing the click action.
    */
    handleItemClicked(event) {
        // console.log('div click target dataset: ', JSON.stringify(event.currentTarget.dataset, null, '\t'))
        if(event.target.classList.contains('reply')) {
            this.handleEmailReply(event.target.dataset.convo);
        } else {
            try {
                this.recId = event.currentTarget.dataset.id;
                this.type = event.currentTarget.dataset.type;
                this.detailHeaderTitle = DETAIL_MODAL_TITLE(this.type, this.isMobile);
                this.openRecordDetail = true;
            } catch (error) {
                handleError(this, error, false);
            }
        }
    }
    
    /**
     * Closes the detailed view modal.
    */
    closeModal() {
        this.openRecordDetail = false;
    }

    /**
     * Checks if the required variables `recId` and `type` are set.
     * @returns {boolean} True if both variables are set, otherwise false.
    */

    variablesAreSet() {
        return this.recId && this.type;
    }

    /**
     * Toggle filters modal open or close adding or removing classes.
    */
    handleFilterClick() {
        toggleFiltersModal(this);
    }

    /**
     * @returns {Boolean} determines whether or not user is on mobile device.
     */
    get isMobile() {
        return this.formFactor?.toLowerCase() === 'small';
    }
    /**
     * Handles email replies by retrieving reply data via wire and initiating the reply process.
     * @param {Event} event - The event object representing the email reply action.
    */
    async handleEmailReply(event) {
        this.isLoading = true;
        try {
            const formattedData = await formatEmailData(this, event, this.orgId.data);
            await sendEmailReply(this, formattedData);

            if(!this.useDockedComposer) {
                this.isLoading = false;
                return;
            }
            // open cad utilities + docked composer to handle reply
            publishGenMessage(
                this.messageContext, 'popCadenceUtilities', 
                { detail: 'conversationViewHistory' }
            );

        } catch (error) {
            handleError(this, error, false);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Checks whether the Docked Composer feature is enabled based on org settings.
     * @returns {boolean} True if Docked Composer is enabled, otherwise false.
    */
    get useDockedComposer() {
        return DOCKED_COMPOSER_ENABLED(this.orgSettings.data);
    }

    get dateFilterOptions() {
        return DATE_FILTERS;
    }
    get typeFilterOptions() {
        return TYPE_FILTERS;
    }

    /**
     * Clears all applied filters and triggers a refresh of conversation data 
     * using the Apex wire method. Optionally sends a message to notify other components 
     * if `publishRefreshMsg` is true. Set `false` when triggered from sibling component
     * to eliminate the risk of infinite, recursive loading.
     *
     * @param {boolean} publishRefreshMsg - A flag to determine if a refresh notification message should be published.
    */
    async handleRefresh(publishRefreshMsg) {
        this.isLoading = true;
        // clearAllFilters(this);

        await refreshApex(this.wiredConvos);
        
        if (publishRefreshMsg) {
            // notify other components of refresh event
            publishGenMessage(
                this.messageContext, 'conversationViewRefreshed', {}
            )
        }
        this.isLoading = false;
    }

    /**
     * Applies filters based on the user's selection and updates the conversation list accordingly.
     * This method resets the conversation list and prepares the component to filter existing data based on
     * the selected filter type ('type' or 'date') and its value. State is then updated accordingly.
     * 
     * @param {string} filterType - The type of filter being applied, either 'type' or 'date'.
     * @param {Event} event - The event object containing the value of the selected filter.
    */
    applyFilters(filterType, event) {
        try {
            this.conversations = [];
            this.hasScrolled = false;
            this.queryMore = true;
            this.isLoading = true;
    
            const selectedValue = event.target.value;
            if (filterType === 'type') {
                this.filterType = selectedValue;
            } else if (filterType === 'date') {
                this.filterDate = selectedValue;
            }
    
            this.offSet = 0;
        } catch (error) {
            handleError(this, error, false);
        }
    }

    /**
     * Handles the conversation item type filter change event.
     * @param {Event} event - The event object representing the type filter change.
    */
    handleTypeFilter(event) {
        this.applyFilters('type', event);
    }

    /**
     * Handles the date filter change event.
     * @param {Event} event - The event object representing the date filter change.
    */
    handleDateFilter(event) {
        this.applyFilters('date', event);
    }

    /**
     * Checks if the custom date filter is selected.
     * @returns {boolean} True if the custom date filter is selected, otherwise false.
    */
    get customDate() {
        return this.filterDate.toLowerCase() === 'custom';
    }

    /**
     * Reports the validity of the custom date range filter.
    */
    checkDateValidity() {
        reportDateRangeValidity(this, 'startDate', 'endDate', false);
    }

    /**
     * Handles the custom start date input change event.
     * @param {Event} event - The event object representing the start date input change.
    */
    handleStartDate(event) {
        handleDateChange(this, event, 'startDate');
    }

    /**
     * Handles the custom end date input change event.
     * @param {Event} event - The event object representing the end date input change.
    */
    handleEndDate(event) {
        handleDateChange(this, event, 'endDate');
    }

    /**
     * Clears all applied filters and resets the conversation list.
    */
    clearFilters() {
        clearAllFilters(this);
    }

    /**
     * Clears the search input field and close it using child public method.
     */
    clearSearch() {
        clearAndCloseSearch(this);
    }

    /**
     * Check whether type, date, or search filters are applied.
     */
    get isFiltered() {
        return  this.filterType !== 'All' || 
                this.filterDate !== 'All' || 
                this.searchKey?.length > 0;
    }

    /**
     * Minimum allowable value for custom end date. 
    */
    get minEndDate(){
        return this.startDate !== '' ? new Date(this.startDate).toISOString().slice(0,10) : null;
    }

    /**
     * Maximum allowable value for custom end date. 
    */
    get maxStartDate(){
        return this.endDate !== '' ? new Date(this.endDate).toISOString().slice(0,10) : null;
    }

}
