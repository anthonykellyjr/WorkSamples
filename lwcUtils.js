import { refreshApex } from '@salesforce/apex';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// determine if mobile device
export const IS_MOBILE = FORM_FACTOR.toLowerCase() === 'small';
// simulated pageRef value for use when components have no actual pageRef (e.g. on a list view page)
export const NULL_PAGE_REF = JSON.stringify({"type":"standard__recordPage","attributes":{"recordId":"","actionName":"view","objectApiName":""},"state":{}});

// PRIMARY ERROR HANDLER METHOD FOR ALL LWC
export const handleError = (cmp, errors, isResult=false) => {
    const source = getCmpName(cmp);
    const sourceName = getLabelFromDevName(source);
    const joiner = sourceName != '' ? ' - ' : '';

    if (isResult) { // process Result.cls error and return
        const exceptionMsg = errors.errorMessage?.replace('&amp;', '&');
        const exceptionName = errors.exceptionType?.split('.').slice(-1);
        const event = new ShowToastEvent({
            title: `Conquer Error: ${exceptionName}`,
            message: sourceName + joiner + exceptionMsg,
            variant: 'Error',
            mode: 'sticky'
        });
        cmp.dispatchEvent(event);
        console.error('Conquer', sourceName, 'encountered error:\n', JSON.stringify(errors));
        return;
    }
    const error = reduceErrors(errors);
    console.error(`Conquer Error in ${sourceName}: ${error}`);
    cmp.dispatchEvent(new ShowToastEvent({
        title: `Conquer Encountered an Error`,
        message: sourceName + joiner + error,
        variant: 'warning',
        mode: 'sticky'
    }))
}

export function getLabelFromDevName(devName) {
    // Split dev name (ex: cadenceActions => Cadence Actions)
    devName = devName ?? '';
    const label = devName.charAt(0).toUpperCase() + devName.slice(1);
    return label.split(/(?=[A-Z])/g).join(' ');
}

// get name of calling component for better error isolation
export const getCmpName = (cmp) => {
    return cmp.template.host.localName // c-test-component
        ?.split('-') // ['c', 'test', 'component'] 
        .slice(1) // removes ns prefix => ['test', 'component']
        .reduce((a, b) => a + b.charAt(0).toUpperCase() + b.slice(1)) // converts to camelCase => testComponent
}

/**
 * Reduces one or more LDS errors into a string[] of error messages.
 * @param {FetchResponse|FetchResponse[]} errors
 * @return {String[]} Error messages
 */
 export function reduceErrors(errors) {
    if (!Array.isArray(errors)) {
        errors = [errors];
    }
    return (
        errors
            // Remove null/undefined items
            .filter((error) => !!error)
            // Extract an error message
            .map((error) => {
                // UI API read errors
                if (Array.isArray(error.body)) {
                    return error.body.map((e) => e.message);
                }
                // Page level errors
                else if (
                    error?.body?.pageErrors &&
                    error.body.pageErrors.length > 0
                ) {
                    return error.body.pageErrors.map((e) => e.message);
                }
                // Field level errors
                else if (
                    error?.body?.fieldErrors &&
                    Object.keys(error.body.fieldErrors).length > 0
                ) {
                    const fieldErrors = [];
                    Object.values(error.body.fieldErrors).forEach(
                        (errorArray) => {
                            fieldErrors.push(
                                ...errorArray.map((e) => e.message)
                            );
                        }
                    );
                    return fieldErrors;
                }
                // UI API DML page level errors
                else if (
                    error?.body?.output?.errors &&
                    error.body.output.errors.length > 0
                ) {
                    return error.body.output.errors.map((e) => e.message);
                }
                // UI API DML field level errors
                else if (
                    error?.body?.output?.fieldErrors &&
                    Object.keys(error.body.output.fieldErrors).length > 0
                ) {
                    const fieldErrors = [];
                    Object.values(error.body.output.fieldErrors).forEach(
                        (errorArray) => {
                            fieldErrors.push(
                                ...errorArray.map((e) => e.message)
                            );
                        }
                    );
                    return fieldErrors;
                }
                // UI API DML, Apex and network errors
                else if (error.body && typeof error.body.message === 'string') {
                    return error.body.message;
                }
                // JS errors
                else if (typeof error.message === 'string') {
                    return error.message;
                }
                // Unknown error shape so try HTTP status text
                return error.statusText;
            })
            // Flatten
            .reduce((prev, curr) => prev.concat(curr), [])
            // Remove empty strings
            .filter((message) => !!message)
    );
}


// pass in an array of wired data values from an LWC and await refresh
export const refreshWires = (wires=[]) => {
    const refreshPromises = wires.map(
        data => refreshApex(data)
    );
    return Promise.allSettled(refreshPromises);
}

export const mockLoading = (cmp, value, ms = 500) => {
    setTimeout(function() {
        try {
            if(cmp.isLoading != value) {
                cmp.isLoading = value;
            }
        } catch(error) {
            if(!cmp) {
                handleError(cmp, error, false);
            } else {
                handleError(cmp, error, false);
            }
        }
    }.bind(cmp), ms);
}


export const formatAMPM = date => {
    let hours = date.getHours();
    let minutes = date.getMinutes();
    let ampm = hours >= 12 ? 'PM' : 'AM';
    let strTime;
    hours = hours % 12;
    hours = hours ? hours : 12; // the hour '0' should be '12'
    minutes = minutes < 10 ? '0' + minutes : minutes;
    strTime = hours + ':' + minutes + ' ' + ampm;
    return strTime;
}

export const localIsoDatetime = date => {
    var tzo = -date.getTimezoneOffset(),
        dif = tzo >= 0 ? '+' : '-',
        pad = function(num) {
            var norm = Math.floor(Math.abs(num));
            return (norm < 10 ? '0' : '') + norm;
        };

    return date.getFullYear() +
        '-' + pad(date.getMonth() + 1) +
        '-' + pad(date.getDate()) +
        'T' + pad(date.getHours()) +
        ':' + pad(date.getMinutes()) +
        ':' + pad(date.getSeconds()) +
        dif + pad(tzo / 60) +
        ':' + pad(tzo % 60);
} // example output '2021-12-07T12:51:27-08:00'

export const timeWithoutSeconds = date => {
    let d = date;
    return d.toLocaleTimeString(navigator.language, {
        hour: '2-digit',
        minute: '2-digit'
    });
} // example output '12:51 PM'

/**
 * Create an interval timer which can be 
 * broken out of when  a condition is met
 * @param {bool} condition 
 * @param {function} callback 
 * @param {integer} maxAttmempts 
 */
export const createTimer = (condition, callback, maxAttempts) => {
    let counter = 0;
    let timer = setInterval(function() {
        console.log("turn no. " + counter);

        if (condition) {
            clearInterval(timer);
            callback();
        }

        if (counter >= maxAttempts || condition) {
            clearInterval(timer);
            callback();
        }
        counter++;

    }, 100);
}
/**
 * Set storage item with a TTL 'expiry' setting
 * @param {*} key name of the storage item
 * @param {*} value value of storage item accessed by key
 * @param {integer} ttl expiry of storage item, in hours
 */
export const setStorageItem = (key, value, ttl) => {
    let expiry = ttl * 3600000; // return hours as milliseconds
    const now = new Date()

    // `item` is an object which contains the original value
    // as well as the time when it's supposed to expire
    const item = {
        value: value,
        expiry: now.getTime() + expiry,
    }
    localStorage.setItem(key, JSON.stringify(item));
}

export const getStorageItem = key => {
    const itemStr = localStorage.getItem(key)
    // if the item doesn't exist, return null
    if (!itemStr) {
        return null
    }
    const item = JSON.parse(itemStr)
    const now = new Date()
    // compare the expiry time of the item with the current time
    if (now.getTime() > item.expiry) {
        // If the item is expired, delete the item from storage
        // and return null
        localStorage.removeItem(key)
        return null
    }
    return item.value
}

// replace underscores in text string with white space
export const unformatSnakeCase = str => {
    try {
        return str.replace(/_/g, ' ');
    } catch(error) {
        console.error(`error formatting snake case string ${str}:  ${JSON.stringify(error)}`);
    }
}

// search array of object's values for text keyword
export const textSearch = ( objArray, query ) => {
    return objArray.filter((obj) =>
        JSON.stringify(Object.values(obj)) // exclude object keys from query
        .toLowerCase().includes(query.toLowerCase())
    )
}

// returns a promise that resolves after the specified number of ms
export const delay = ms => {
    return new Promise(resolve => {
        setTimeout(resolve, ms);
    });
}