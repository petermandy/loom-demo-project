import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe } from 'c/pubsub';
import getCampaignMembers from '@salesforce/apex/Loop1OrchestratorController.getCampaignMembers';

export default class CampaignMembersPanel extends NavigationMixin(LightningElement) {
  @api recordId;
  campaignMembers = [];
  hasMembers = false;

  connectedCallback() {
    subscribe('refreshCampaignMembers', (payload) => {
      console.log('Received refresh event');
      this.refreshMembers();
    });
  }

  @wire(getCampaignMembers, { leadId: '$recordId' })
  wiredCampaignMembers({ error, data }) {
    if (data) {
      this.campaignMembers = data;
      this.hasMembers = data.length > 0;
    } else if (error) {
      console.error('Error loading campaign members:', error);
    }
  }

  async refreshMembers() {
    console.log('Refreshing campaign members...');
    try {
      const data = await getCampaignMembers({ leadId: this.recordId });
      this.campaignMembers = data;
      this.hasMembers = data.length > 0;
      console.log('Campaign members refreshed. Count:', data.length);
    } catch (error) {
      console.error('Error refreshing members:', error);
    }
  }

  navigateToCampaignHistory() {
    this[NavigationMixin.Navigate]({
      type: 'standard__recordRelationshipPage',
      attributes: {
        recordId: this.recordId,
        relationshipApiName: 'CampaignMembers',
        actionName: 'view'
      }
    });
  }
}
