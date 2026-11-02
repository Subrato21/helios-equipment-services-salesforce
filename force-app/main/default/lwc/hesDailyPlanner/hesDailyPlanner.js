import { LightningElement, api, wire } from 'lwc';
import schedule from '@salesforce/apex/HESDailyCapacityPlanner.schedule';
import getSegments from '@salesforce/apex/HESDailyCapacityPlanner.getSegments';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Segment', fieldName: 'Name' },
    { label: 'Work date', fieldName: 'Work_Date__c', type: 'date-local' },
    { label: 'Hours', fieldName: 'Planned_Hours__c', type: 'number' },
    { label: 'Assigned user', fieldName: 'engineerName' }
];

export default class HesDailyPlanner extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    segments = [];
    firstDay;
    effortHours = 8;
    busy = false;
    loaded = false;
    errorText;
    wiredResult;

    connectedCallback() {
        const now = new Date();
        const localDate = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
        this.firstDay = localDate.toISOString().slice(0, 10);
    }

    @wire(getSegments, { caseId: '$recordId' })
    wiredSegments(result) {
        this.wiredResult = result;
        if (result.data) {
            this.segments = result.data.map(row => ({
                ...row,
                engineerName: row.Engineer__r?.Name || ''
            }));
            this.loaded = true;
            this.errorText = null;
        } else if (result.error) {
            this.errorText = this.messageFrom(result.error);
            this.loaded = true;
        }
    }

    get hasSegments() {
        return this.segments.length > 0;
    }

    get showForm() {
        return this.loaded && !this.hasSegments;
    }

    changeDate(event) {
        this.firstDay = event.target.value;
    }

    changeHours(event) {
        this.effortHours = Number(event.target.value);
    }

    async buildSchedule() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        if (!inputs.every(input => input.reportValidity())) {
            return;
        }
        this.errorText = null;
        this.busy = true;
        try {
            const message = await schedule({
                caseId: this.recordId,
                firstDay: this.firstDay,
                effortHours: this.effortHours
            });
            await refreshApex(this.wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Daily schedule created', message, variant: 'success'
            }));
        } catch (error) {
            this.errorText = this.messageFrom(error);
        } finally {
            this.busy = false;
        }
    }

    messageFrom(error) {
        return error?.body?.message || error?.message || 'Unable to load the schedule.';
    }
}
