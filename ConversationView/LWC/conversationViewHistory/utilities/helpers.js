/* eslint-disable @lwc/lwc/no-async-operation */
import { handleError } from 'c/utils';
import userId from "@salesforce/user/Id";
import { postData } from 'c/httpMethods';
import getEmailMessageReplyInformation from '@salesforce/apex/EmailModalController.getEmailMessageReplyInformation';

/**
 * A map which tracks the last scroll position for conversationViewHistory. 
 * This is used in the handleScroll method to determine how much the user has scrolled. 
 * The key is the component instance, and the value is the last recorded scroll position 
 * (a number) for that instance. This is helpful as "conversationViewHistory" can be put 
 * on an SF page in more than one place, creating multiple instances.
*/
const scrollPositions = new Map();

/**
 * Handles the scroll event for a component, updating the loading state every 500px scrolled.
 * We use a mock loader to emulate expected behavior until pagination is implemented.
 * @param {Object} cmp - The component instance.
*/
export function handleScroll(cmp) {
    try {
        const scrollThreshold = 500; // Every 500px scrolled
        const loadingTimeout = 300;  // 300 ms timeout

        const mainDiv = cmp.template.querySelector('section');
        if (!mainDiv) {
            throw new Error('Conversation View main scrollable section not found');
        }

        // compare scroll positions to determine if scrolling up or down
        let lastScrollPosition = scrollPositions.get(cmp) || 0;
        const currentScroll = mainDiv.scrollTop + mainDiv.clientHeight;
        const isScrollingDown = currentScroll > lastScrollPosition;

        if (isScrollingDown && currentScroll - lastScrollPosition > scrollThreshold) {
            cmp.isLoading = true;

            setTimeout(() => {
                cmp.isLoading = false;
            }, loadingTimeout);

            scrollPositions.set(cmp, currentScroll);
        } else if (!isScrollingDown) {
            // update position in scrollPositions map
            scrollPositions.set(cmp, currentScroll - mainDiv.clientHeight);
        }

        if (cmp.queryMore && currentScroll >= mainDiv.scrollHeight && cmp.offSet < 2000) {
            cmp.offset += cmp.limitSize;
            cmp.hasScrolled = true;
            // ... (other logic to load more data when pagination is implemented)
        }
    } catch (error) {
        handleError(cmp, error, false);
    }
}


/**
 * Formats the data required for an email reply.
 * @param {Object} eventData - The data associated with the email reply event.
 * @returns {Object} Formatted data for the email reply.
*/
export async function formatEmailData(cmp, eventData, orgId) {
    try {
        const replyInfo = await getEmailMessageReplyInformation({
            msgId: eventData.currentTarget.dataset.conversationId
        });

        return {
            aid: orgId,
            uid: userId,
            email_address: replyInfo.DS_Packages__From_Address__c.replace("(", "").replace(")", ""),
            reply_to_email_id: replyInfo.DS_Packages__External_Conquer_Id__c,
            cadence_member_id: replyInfo.DS_Packages__Conversation__r.DS_Packages__Cadence_Member__c,
            subject: "Re:" + replyInfo.DS_Packages__Subject__c
        };
    } catch (error) {
        handleError(cmp, error, false); // Adjust error handling as needed
        throw error; // Re-throw error to be handled by parent
    }
}

/**
 * Sends an email reply using the formatted data.
 * @param {Object} emailData - Formatted data for the email reply.
 * @returns {Promise} A promise representing the operation's result.
*/
export async function sendEmailReply(cmp, emailData) {
    console.debug('email data: ', JSON.stringify(emailData, null, '\t'))
    console.debug('email data parsed: ', JSON.parse(JSON.stringify({...emailData})))
    try {
        return await postData('https://workspace.dialsource.com/publish', {
            "aid": emailData.aid,
            "uid": emailData.uid,
            "identifier": "all",
            "message": {
                "event": "email-prompt",
                "oid": emailData.recordId,
                "email_address": emailData.email_address,
                "reply_to_email_id": emailData.reply_to_email_id,
                "cadence_member_id": emailData.cadence_member_id,
                "subject": emailData.subject
            }
        });
    } catch (error) {
        handleError(cmp, error, false); // Adjust error handling as needed
        throw error; // Re-throw error to be handled by parent
    }
}

/**
 * Clears the search input and closes the search bar in the component. We utilize
 * the child component's public "clearSearch" method to interact with it directly.
 *
 * @param {Object} cmp - The component instance that contains the search input field.
*/
export const clearAndCloseSearch = (cmp) => {
    try {
        cmp.searchKey = '';
        if (cmp.template.querySelector('c-expandable-search-bar')) {
            const searchBar = cmp.template.querySelector('c-expandable-search-bar');
            if (searchBar.searchIsOpen) {
                searchBar.clearSearch();
            }
        }
    } catch (error) {
        handleError(cmp, error, false);
    }
}

/**
 * Calculates the total count of conversation items across all objects in an array of conversations. 
 * This function iterates over each conversation object in the provided array, accumulating the total 
 * count of items within each conversation.
 *
 * @param {Array} conversations - An array of conversation objects, each containing a 'values' array.
 * @returns {number} The total count of conversation items across all conversation objects in the array.
*/
export const convoArrayItemCount = (conversations) => {
    return conversations.reduce((acc, obj) => acc + obj.values.length, 0);
}

/**
 * Calculates the total count of conversation items within a conversation object. This function iterates 
 * over each key in the conversation object, summing up the length of the arrays associated with each key.
 * It is used for objects structured with date keys and arrays of conversation items.
 *
 * @param {Object} convosObj - An object with keys representing dates and values being arrays of conversations.
 * @returns {number} The total count of conversation items across all keys in the conversation object.
*/
export const convoObjectItemCount = (convosObj) => {
    let totalCount = 0;
    for (const dateKey in convosObj) {
        if (Object.hasOwnProperty.call(convosObj, dateKey)) {
            const conversations = convosObj[dateKey];
            // Count the number of entries in each array and add to the total count
            totalCount += conversations.length;
        }
    }
    return totalCount;
}