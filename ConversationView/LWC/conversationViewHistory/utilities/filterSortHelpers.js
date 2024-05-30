import { handleError } from 'c/utils';
import { clearAndCloseSearch } from './helpers.js';
/**
 * Groups wired convoData by creating an array of conversations.
 * @param {Object} convoData - The conversation data obtained from the wire method.
 * @returns {Object[]} An array of conversations with grouped values.
*/
export const groupWiredConvos = (cmp, convoData={}) => {
    let conversations = [];
    try {
        for (const key in convoData) {
            if (Object.hasOwnProperty.call(convoData, key)) {
                const valuesArray = convoData[key];
                conversations.push({
                    key: key,
                    values: valuesArray
                });
            }
        }
    } catch (error) {
        console.error('Error grouping wired conversations by date');
        handleError(cmp, error, false);
    }
    return conversations;
}

/**
 * Filters conversations based on the provided search query and sorts by createdDate.
 * @param {string} query - The search query used for filtering conversations.
 * @returns {Object[]} An array of conversations with values meeting the search criteria.
*/    
export const searchConversations = (cmp, conversations, query) => {
    let result = [];
    try {
        result = conversations
            .map(convo => {
                // check if item body, subject, phone, or email contains query string
                const values = convo.values.filter(val => 
                    ['body', 'subject', 'phone', 'email'].some(prop =>
                        val[prop]?.toLowerCase()?.includes(query)
                    )
                );
    
                return values.length > 0 ? { ...convo, values } : null;
            })
            .filter(convo => convo !== null)
            .sort((a, b) => (a.createdDate > b.createdDate) ? -1 : 1);
        //cmp.showNoData = convoArrayItemCount(result) === 0;
        
        return result;
    } catch (error) {
        handleError(cmp, error, false);
    }
}

/**
 * Handles changes in the start and end date inputs.
 * @param {Object} cmp - The component instance.
 * @param {Event} event - The event object representing the date input change.
 * @param {string} property - The property to update ('startDate' or 'endDate').
*/
export const handleDateChange = (cmp, event, property) => {
    try {
        const value = event.target.value;
    
        cmp.checkDateValidity();
    
        if (property === 'startDate') {
            if (cmp.endDate !== '' && value <= new Date(cmp.maxStartDate)) {
                cmp.startDate = new Date(value).toISOString();
            } else if (cmp.endDate === '') {
                cmp.startDate = new Date(value).toISOString();
            }
        } else if (property === 'endDate') {
            const endDate = new Date(value);
            if (endDate >= new Date(cmp.minEndDate)) {
                endDate.setUTCHours(23, 59, 59, 999);
                cmp.endDate = endDate.toISOString();
            }
        }
    
        cmp.conversations = [];
        cmp.queryMore = true;
        cmp.hasScrolled = false;
        cmp.offSet = 0;
    } catch (error) {
        handleError(cmp, error, false);
    }
}
/**
 * Toggles filters modal open/closed by changing the CSS class.
 * @param {Object} cmp - The component instance.
*/
export const toggleFiltersModal = (cmp) => {
    try {
        //Filter box is closed
        if (cmp.filterClass.includes('slds-is-closed')) {
            //Open Filter Box and set focus
            cmp.filterClass = cmp.filterClass.replace('slds-is-closed', 'slds-is-open');
        }
        //Filter box is open
        else if (cmp.filterClass.includes('slds-is-open')) {
            cmp.filterClass = cmp.filterClass.replace('slds-is-open', 'slds-is-closed');
        }
    } catch (error) {
        handleError(cmp, error, false);
    }
}

/**
 * Closes the filters modal by changing the CSS class.
 * @param {Object} cmp - The component instance.
*/
export const closeFiltersModal = cmp => {
    try {
        if (cmp.filterClass.includes('slds-is-open')) {
            cmp.filterClass = cmp.filterClass.replace('slds-is-open', 'slds-is-closed');
        }
    } catch (error) {
        handleError(cmp, error, false);
    }
}

/**
 * Select an element in LWC HTML template by its data-id.
 * @param {Object} cmp - The component instance.
 * @param {String} dataId - The element's specified data-id.
 * @returns LWC HTML template element.
*/
const templateSelector = (cmp, dataId) => {
    const elem = cmp.template.querySelector(`[data-id="${dataId}"]`);
    if (elem) {
        return elem;
    }
    return null;
}

/**
 * Clears all applied filters and resets the conversation list.
 * @param {Object} cmp - The component instance.
*/
export const clearAllFilters = cmp => {
    try {
        closeFiltersModal(cmp);
        clearAndCloseSearch(cmp);
        cmp.offset = 0;
        cmp.queryMore = true;
        cmp.hasScrolled = false;
        cmp.startDate = '';
        cmp.endDate = '';
        cmp.filterDate = 'All';
        cmp.filterType = 'All';
        const elementIds = ['endDate', 'startDate', 'date-filters'];
        // check that selected element is not undefined when clearing value
        elementIds.forEach(id => {
            const element = templateSelector(cmp, id);
            if (element) {
                element.value = '';
            }
        });
    } catch (error) {
        handleError(cmp, error, false);
    }
}