import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getRefundStatus from '@salesforce/apex/CancellationService.getRefundStatus';

export default class RefundStatusTracker extends LightningElement {
    @api bookingId;
    @track refundStatus = '';
    @track isRejected = false;
    wiredRefund;

    @wire(getRefundStatus, { bookingId: '$bookingId' })
    wiredGetRefundStatus(value) {
        this.wiredRefund = value;
        const { data, error } = value;
        if (data) {
            this.refundStatus = data;
            this.isRejected = (data === 'Rejected');
        } else if (error) {
            console.error('Error loading refund status:', error);
            this.refundStatus = '';
            this.isRejected = false;
        } else {
            this.refundStatus = '';
            this.isRejected = false;
        }
    }

    @api
    refresh() {
        return refreshApex(this.wiredRefund);
    }
}
