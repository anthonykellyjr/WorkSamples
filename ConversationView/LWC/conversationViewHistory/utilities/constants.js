/**
 * Filter type options for Conversation View items.
 * Corresponds to "type" prop of conversationViewHistoryWrapper class.
 */
export const TYPE_FILTERS = [
    { label: 'All', value: 'All' }, 
    { label: 'Call', value: 'Call' },
    { label: 'Email', value: 'Email' },
    { label: 'SMS', value: 'SMS' },
    { label: 'Custom', value: 'Custom' },
];

/**
 * Date options for filtering conversation view hitems by Created Date
*/
export const DATE_FILTERS = [
    { label: 'All', value: 'All' },
    { label: 'Today', value: 'Today' },
    { label: 'This Week', value: 'This Week' },
    { label: 'This Month', value: 'This Month' },
    { label: 'Custom', value: 'Custom' },
];

/**
 * SLDS classes for the parent div wrapping the type filter dropdown UI item.
*/
export const FILTER_CLASSES = 'slds-dropdown-trigger slds-dropdown-trigger_click slds-is-closed';


/**
 * Compares two objects based on their `createdDate` properties in descending order.
 * 
 * @param {Object} a - The first object to compare.
 * @param {Object} b - The second object to compare.
 * @return {number} - Returns -1 if `a` is newer, 1 if `b` is newer, or 0 if they are equal.
 */
export const COMPARE_DATES_DESC = (a,b) => {
    if (a.createdDate > b.createdDate) {
        return -1;
    } else if (a.createdDate < b.createdDate) {
        return 1;
    }
    return 0;
}

/**
 * Determines whether the Docked Composer is enabled based on the org's settings.
 * @param {Object} orgSettings - The org's custom settings document.
 * @return {boolean} - Returns true if Docked Email Composer is enabled, false otherwise.
*/
export const DOCKED_COMPOSER_ENABLED = (orgSettings) => {
    return orgSettings?.DS_Packages__Disable_Docked_Email_Composer__c === false;
}

/**
 * Generates title for drill down detail modal based on the convo item type and device.
 * @param {string} type - The type of conversation view item (e.g., Email, SMS, Call).
 * @param {boolean} isMobile - return true if component FORM_FACTOR is `small`
 * @return {string} - Title for detail modal.
*/
export const DETAIL_MODAL_TITLE = (type, isMobile) => {
    const titles = {
        'Email': isMobile ? 'Email' : 'Email Conversation',
        'SMS': isMobile ? 'SMS' : 'SMS History',
        'Call': isMobile ? 'Call' : 'Call Details'
    };

    return titles[type] || 'Conversation Details';
};
