import { LightningElement, track } from 'lwc';
import getTuneData from '@salesforce/apex/ObserveTuneController.getTuneData';
import approveTuneAndPromote from '@salesforce/apex/ObserveTuneController.approveTuneAndPromote';
import resetChampionModel from '@salesforce/apex/ObserveTuneController.resetChampionModel';

export default class ObserveTuneDashboard extends LightningElement {
  @track tuneData = null;
  @track cohortLeads = [];
  @track tuneProposal = null;
  @track isLoading = false;
  @track hasError = false;
  @track errorMessage = '';
  @track tuneApproved = false;
  @track releaseStatus = null;
  @track currentChampion = 'v2.7.0';
  @track actionButtonLabel = 'Promote v2.8.0';
  @track observeTriggered = true;
  @track selectedTab = 'loop1';

  connectedCallback() {
    this.observeTriggered = true;
    this.loadTuneData();
  }

  async loadTuneData() {
    this.isLoading = true;
    try {
      const result = await getTuneData();
      if (result.success) {
        this.cohortLeads = result.cohortLeads;
        this.tuneProposal = result.tuneProposal;
        this.tuneData = result;
        this.currentChampion = result.currentChampion || 'v2.7.0';
        this.actionButtonLabel = this.currentChampion === 'v2.8.0' ? 'Rollback to v2.7.0' : 'Promote v2.8.0';
        console.log('Champion:', this.currentChampion, 'Label:', this.actionButtonLabel);
      } else {
        this.hasError = true;
        this.errorMessage = result.error || 'Failed to load tune data';
      }
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
    } finally {
      this.isLoading = false;
    }
  }

  async handleApproveTune() {
    this.isLoading = true;
    try {
      const result = await approveTuneAndPromote();
      if (result.success) {
        this.tuneApproved = true;
        this.currentChampion = result.newModel;
        this.actionButtonLabel = this.currentChampion === 'v2.8.0' ? 'Rollback to v2.7.0' : 'Promote v2.8.0';
        this.releaseStatus = {
          newModel: result.newModel,
          previousModel: result.previousModel,
          action: result.action,
          message: result.message
        };
      } else {
        this.hasError = true;
        this.errorMessage = result.message;
      }
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
    } finally {
      this.isLoading = false;
    }
  }

  get proposalList() {
    return this.tuneProposal?.proposals || [];
  }

  get controlPlaneVisible() {
    return this.tuneApproved;
  }

  get isLoop1Tab() {
    return this.selectedTab === 'loop1';
  }

  get isLoop2Tab() {
    return this.selectedTab === 'loop2';
  }

  get releaseStages() {
    return [
      { name: 'Challenger Qualification', status: 'Completed' },
      { name: 'Shadow Deployment', status: 'In Progress' },
      { name: 'Canary (5%)', status: 'Pending' },
      { name: 'A/B Test (50%)', status: 'Pending' },
      { name: 'Promotion', status: 'Pending' }
    ];
  }

  handleTabClick(event) {
    this.selectedTab = event.currentTarget.dataset.tab;
  }

  async handleStartObserve() {
    this.observeTriggered = true;
    await this.loadTuneData();
  }

  async handleRunObserve() {
    this.isLoading = true;
    this.tuneApproved = false;
    this.releaseStatus = null;
    await this.loadTuneData();
  }

  async handleResetModel() {
    this.isLoading = true;
    try {
      const result = await resetChampionModel();
      if (result.success) {
        this.tuneApproved = false;
        this.releaseStatus = null;
        this.currentChampion = result.modelVersion;
        this.actionButtonLabel = 'Promote v2.8.0';
        alert('Champion model reset to v2.7.0');
      } else {
        this.hasError = true;
        this.errorMessage = result.message;
      }
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
    } finally {
      this.isLoading = false;
    }
  }
}
