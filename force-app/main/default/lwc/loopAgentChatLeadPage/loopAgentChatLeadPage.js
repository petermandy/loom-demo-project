import { LightningElement, api, track } from 'lwc';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { publish } from 'c/pubsub';
import readLeadSingleAsync from '@salesforce/apex/Loop1OrchestratorController.readLeadSingleAsync';
import actLeadSingleAsync from '@salesforce/apex/Loop1OrchestratorController.actLeadSingleAsync';
import loop2AssignSingleAsync from '@salesforce/apex/Loop1OrchestratorController.loop2AssignSingleAsync';
import updateLeadClassificationFields from '@salesforce/apex/Loop1OrchestratorController.updateLeadClassificationFields';
import clearLeadEnrichmentData from '@salesforce/apex/Loop1OrchestratorController.clearLeadEnrichmentData';

export default class LoopAgentChatLeadPage extends LightningElement {
  @api recordId;
  @track currentPhase = 'initial';
  @track isLoading = false;
  @track hasError = false;
  @track errorMessage = '';
  @track readSnapshot = null;
  @track verdict = null;
  @track dataCloudJoins = {};
  @track actResult = null;
  @track loop2Result = null;
  @track householdSummary = null;
  @track porInfo = null;

  connectedCallback() {
    const savedState = sessionStorage.getItem(`loopState-${this.recordId}`);
    if (savedState) {
      const state = JSON.parse(savedState);
      this.currentPhase = state.phase;
      this.readSnapshot = state.readSnapshot;
      this.verdict = state.verdict;
      this.dataCloudJoins = state.dataCloudJoins || {};
      this.actResult = state.actResult;
      this.loop2Result = state.loop2Result;
    }
  }

  saveState() {
    sessionStorage.setItem(`loopState-${this.recordId}`, JSON.stringify({
      phase: this.currentPhase,
      readSnapshot: this.readSnapshot,
      verdict: this.verdict,
      dataCloudJoins: this.dataCloudJoins,
      actResult: this.actResult,
      loop2Result: this.loop2Result
    }));
  }

  async handleStartRead() {
    this.isLoading = true;
    this.currentPhase = 'readApiProgress';
    try {
      await this.delay(2500);
      this.isLoading = false;
      this.currentPhase = 'dataCloudJoins';
      this.saveState();
      await this.delay(1000);
      await this.handleReadSnapshot();
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.message;
      this.isLoading = false;
    }
  }

  async handleStartAnalysis() {
    this.isLoading = true;
    try {
      await this.delay(2500);
      this.currentPhase = 'dataCloudJoins';
      this.saveState();
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.message;
    } finally {
      this.isLoading = false;
    }
  }

  async handleReadSnapshot() {
    this.isLoading = true;
    try {
      const result = await readLeadSingleAsync({ recordId: this.recordId });
      this.readSnapshot = result.snapshotId;
      this.dataCloudJoins = result.dataCloudJoins || {};
      this.householdSummary = result.dataCloudJoins?.householdInfo || '';
      this.porInfo = result.dataCloudJoins?.producerOfRecord || '';
      this.isLoading = false;
      await this.delay(1500);
      
      this.currentPhase = 'snapshotComplete';
      await this.delay(2000);
      
      this.currentPhase = 'readComplete';
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.saveState();
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
      this.isLoading = false;
    }
  }

  async handleStartAct() {
    this.isLoading = true;
    this.dataCloudJoins = {};
    try {
      this.currentPhase = 'actProcessing';
      await this.delay(2500);
      
      const result = await actLeadSingleAsync({ 
        recordId: this.recordId, 
        readSnapshotId: this.readSnapshot 
      });
      
      this.verdict = result.outcome;
      this.actResult = result;
      
      await updateLeadClassificationFields({
        recordId: this.recordId,
        classification: result
      });
      
      await this.delay(1500);
      this.currentPhase = 'actVerdictComplete';
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.saveState();
      this.isLoading = false;
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
      this.isLoading = false;
    }
  }

  async handleStartLoop2() {
    this.isLoading = true;
    this.actResult = null;
    try {
      this.currentPhase = 'loop2Processing';
      console.log('Loop2Processing - verdict:', this.verdict);
      console.log('isPursueVerdict:', this.isPursueVerdict);
      console.log('verdict === Pursue:', this.verdict === 'Pursue');
      console.log('verdict length:', this.verdict?.length);
      console.log('verdict charCodes:', this.verdict?.split('').map(c => c.charCodeAt(0)));
      await this.delay(2500);
      
      const result = await loop2AssignSingleAsync({
        recordId: this.recordId,
        verdict: this.verdict
      });
      
      this.loop2Result = result;
      await this.delay(1500);
      
      this.currentPhase = 'loop2Complete';
      this.saveState();
      this.isLoading = false;
      
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      
      // Only full reload for Nurture (campaign history needs refresh); Pursue just updates record
      if (this.verdict === 'Nurture') {
        setTimeout(() => {
          console.log('Reloading page to refresh campaign history');
          location.reload();
        }, 4000);
      }
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
      this.isLoading = false;
    }
  }

  async handleReset() {
    try {
      this.isLoading = true;
      await clearLeadEnrichmentData({ recordId: this.recordId });
      
      await this.delay(1000);
      
      this.currentPhase = 'initial';
      this.readSnapshot = null;
      this.verdict = null;
      this.dataCloudJoins = {};
      this.actResult = null;
      this.loop2Result = null;
      this.hasError = false;
      sessionStorage.removeItem(`loopState-${this.recordId}`);
      
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      await this.delay(500);
      window.location.reload();
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
      this.isLoading = false;
    }
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  get isInitialPhase() {
    return this.currentPhase === 'initial';
  }

  get isReadApiProgress() {
    return this.currentPhase === 'readApiProgress';
  }

  get isDataCloudPhase() {
    return this.currentPhase === 'dataCloudJoins';
  }

  get isReadPhase() {
    return this.currentPhase === 'readComplete';
  }

  get isSnapshotComplete() {
    return this.currentPhase === 'snapshotComplete';
  }

  get isActPhase() {
    return this.currentPhase === 'actVerdictComplete';
  }

  get isActProcessing() {
    return this.currentPhase === 'actProcessing';
  }

  get isLoop2Phase() {
    return this.currentPhase === 'loop2Complete';
  }

  get isLoop2Processing() {
    return this.currentPhase === 'loop2Processing';
  }

  get isLoadingState() {
    return this.isLoading;
  }

  get currentLoopStatus() {
    const statuses = {
      'initial': 'LOOP 1: READY',
      'dataCloudJoins': 'LOOP 1: LOOM READ API',
      'readComplete': 'LOOP 1: SNAPSHOT COMPLETE',
      'actVerdictComplete': 'LOOP 1: LOOM CLASSIFIER',
      'loop2Complete': 'LOOP 2: LOOM ROUTE'
    };
    return statuses[this.currentPhase] || 'LOOP 1';
  }

  get verdictOutcome() {
    return this.verdict ? this.verdict.toUpperCase() : '';
  }

  get verdictConfidence() {
    return this.actResult?.confidence ? (this.actResult.confidence * 100).toFixed(0) + '%' : '';
  }

  get isHardDisqualify() {
    return this.verdict === 'Hard Disqualify';
  }

  get shouldShowLoop2() {
    return !this.isHardDisqualify;
  }

  get isPursueVerdict() {
    return this.verdict === 'Pursue';
  }
}
