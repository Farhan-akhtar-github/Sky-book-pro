import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import CANCELLATION_CHANNEL from '@salesforce/messageChannel/SkyBook_Channel__c';
import cancelBooking from '@salesforce/apex/CancellationService.cancelBooking';
import { formatCurrency } from 'c/skyBookUtils';

import NAME_FIELD from '@salesforce/schema/Booking__c.Name';
import TOTAL_AMOUNT_FIELD from '@salesforce/schema/Booking__c.Total_Amount__c';

export default class CancellationModal extends LightningElement {
    @api bookingId;
    @track reason = '';
    @track processing = false;

    @wire(MessageContext)
    messageContext;

    @wire(getRecord, { recordId: '$bookingId', fields: [NAME_FIELD, TOTAL_AMOUNT_FIELD] })
    bookingRecord;

    get bookingName() {
        return getFieldValue(this.bookingRecord.data, NAME_FIELD) || '';
    }

    get bookingTotalAmount() {
        const amt = getFieldValue(this.bookingRecord.data, TOTAL_AMOUNT_FIELD);
        return formatCurrency(amt || 0, 'USD');
    }

    get isConfirmDisabled() {
        return this.processing || !this.reason.trim();
    }

    handleReasonChange(event) {
        this.reason = event.target.value;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleConfirm() {
        const textarea = this.template.querySelector('lightning-textarea');
        if (!textarea || !this.reason.trim()) {
            if (textarea) {
                textarea.setCustomValidity('Cancellation reason is required.');
                textarea.reportValidity();
            }
            return;
        } else {
            if (textarea) {
                textarea.setCustomValidity('');
                textarea.reportValidity();
            }
        }

        this.processing = true;

        cancelBooking({ bookingId: this.bookingId, reason: this.reason })
            .then(() => {
                // Publish LMS Event
                const payload = {
                    bookingId: this.bookingId,
                    status: 'Cancelled'
                };
                try {
                    publish(this.messageContext, CANCELLATION_CHANNEL, payload);
                } catch (e) {
                    console.error('Failed to publish cancellation message context event:', e);
                }

                // Show Success Toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Booking cancelled successfully.',
                        variant: 'success'
                    })
                );

                // Dispatch Cancelled event
                this.dispatchEvent(new CustomEvent('cancelled'));
            })
            .catch(error => {
                console.error('Cancellation error:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error cancelling booking',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.processing = false;
            });
    }
}
