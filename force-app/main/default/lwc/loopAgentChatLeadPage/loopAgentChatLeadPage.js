import { LightningElement, api, track } from 'lwc';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import readLeadSingleAsync from '@salesforce/apex/Loop1OrchestratorController.readLeadSingleAsync';
import actLeadSingleAsync from '@salesforce/apex/Loop1OrchestratorController.actLeadSingleAsync';
import loop2AssignSingleAsync from '@salesforce/apex/Loop1OrchestratorController.loop2AssignSingleAsync';
import updateLeadClassificationFields from '@salesforce/apex/Loop1OrchestratorController.updateLeadClassificationFields';
import clearLeadEnrichmentData from '@salesforce/apex/Loop1OrchestratorController.clearLeadEnrichmentData';
import getDemoTiming from '@salesforce/apex/Loop1OrchestratorController.getDemoTiming';

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

  // Timing in seconds — loaded from Demo_Timing__c custom setting
  readSeconds = 20;
  actSeconds = 15;
  loop2Seconds = 15;

  // Progressive reveal counters
  @track readVisibleCount = 0;
  @track actVisibleCount = 0;
  @track loop2VisibleCount = 0;

  async connectedCallback() {
    try {
      const timing = await getDemoTiming();
      this.readSeconds = timing.readSeconds || 20;
      this.actSeconds = timing.actSeconds || 15;
      this.loop2Seconds = timing.loop2Seconds || 15;
    } catch (e) {
      // fall through to defaults
    }
    const savedState = sessionStorage.getItem(`loopState-${this.recordId}`);
    if (savedState) {
      const state = JSON.parse(savedState);
      this.currentPhase = state.phase;
      this.readSnapshot = state.readSnapshot;
      this.verdict = state.verdict;
      this.dataCloudJoins = state.dataCloudJoins || {};
      this.actResult = state.actResult;
      this.loop2Result = state.loop2Result;
      // Restore with all items visible since phase already completed
      this.readVisibleCount = 99;
      this.actVisibleCount = 99;
      this.loop2VisibleCount = 99;
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

  // Reveals `total` items evenly over `durationSeconds`, calling onStep(n) after each
  async revealProgressively(total, durationSeconds, onStep) {
    const intervalMs = (durationSeconds * 1000) / total;
    for (let i = 1; i <= total; i++) {
      await this.delay(intervalMs);
      onStep(i);
    }
  }

  async handleStartRead() {
    this.isLoading = true;
    this.readVisibleCount = 0;
    this.currentPhase = 'readApiProgress';
    try {
      await this.delay(2500);
      this.isLoading = false;
      this.currentPhase = 'dataCloudJoins';
      this.saveState();
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
    try {
      // Fire Apex immediately; items reveal after it returns
      const result = await readLeadSingleAsync({ recordId: this.recordId });
      this.readSnapshot = result.snapshotId;
      this.dataCloudJoins = {
        ...(result.dataCloudJoins || {}),
        emailVerified: 'Verified',
        phoneConfirmed: 'Confirmed-reachable',
        addressValidated: 'USPS-validated',
        identityConfidence: 'Medium',
        costOfPursuit: '$87',
        lifetimeMargin: '$1,240',
        pursuitWeighting: '0.071'
      };
      this.householdSummary = result.dataCloudJoins?.householdInfo || '';
      this.porInfo = result.dataCloudJoins?.producerOfRecord || '';

      // Progressive reveal over readSeconds — 11 enrichment items
      await this.revealProgressively(11, this.readSeconds, (n) => {
        this.readVisibleCount = n;
      });

      this.currentPhase = 'snapshotComplete';
      await this.delay(2000);
      this.currentPhase = 'readComplete';
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.saveState();
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
    }
  }

  async handleStartAct() {
    this.actVisibleCount = 0;
    this.dataCloudJoins = {};
    this.currentPhase = 'actProcessing';
    try {
      // Fire Apex immediately; signals reveal while it runs
      const actPromise = actLeadSingleAsync({
        recordId: this.recordId,
        readSnapshotId: this.readSnapshot
      });

      // Progressive reveal of 3 classifier signals over actSeconds
      await this.revealProgressively(3, this.actSeconds, (n) => {
        this.actVisibleCount = n;
      });

      const result = await actPromise;
      this.verdict = result.outcome;
      this.actResult = result;

      await updateLeadClassificationFields({
        recordId: this.recordId,
        classification: result
      });

      this.currentPhase = 'actVerdictComplete';
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.saveState();
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
    }
  }

  async handleStartLoop2() {
    this.loop2VisibleCount = 0;
    this.actResult = null;
    this.currentPhase = 'loop2Processing';
    try {
      // Fire Apex immediately; signals reveal while it runs
      const loop2Promise = loop2AssignSingleAsync({
        recordId: this.recordId,
        verdict: this.verdict
      });

      // Progressive reveal of 3 routing signals over loop2Seconds
      await this.revealProgressively(3, this.loop2Seconds, (n) => {
        this.loop2VisibleCount = n;
      });

      const result = await loop2Promise;
      this.loop2Result = result;

      this.currentPhase = 'loop2Complete';
      this.saveState();
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

      if (this.verdict === 'Nurture') {
        setTimeout(() => {
          location.reload();
        }, 4000);
      }
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || error.message;
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
      this.readVisibleCount = 0;
      this.actVisibleCount = 0;
      this.loop2VisibleCount = 0;
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

  // Computed arrays for progressive reveal — each item appears as its index is reached
  get visibleReadItems() {
    const all = [
      { key: 'existingCustomer', label: 'Existing customer match',        value: this.dataCloudJoins.existingCustomer, cssClass: 'result-item reveal-item' },
      { key: 'producerOfRecord', label: 'Producer of Record',             value: this.dataCloudJoins.producerOfRecord, cssClass: 'result-item reveal-item' },
      { key: 'suppressionFlag',  label: 'Suppression flag',               value: this.dataCloudJoins.suppressionFlag,  cssClass: 'result-item reveal-item' },
      { key: 'sourceBindRate',   label: 'Source trailing 90-day bind rate', value: this.dataCloudJoins.sourceBindRate, cssClass: 'result-item highlight reveal-item' },
      { key: 'emailVerified',    label: 'Data Quality — Email',           value: this.dataCloudJoins.emailVerified,    cssClass: 'result-item reveal-item' },
      { key: 'phoneConfirmed',   label: 'Data Quality — Phone',           value: this.dataCloudJoins.phoneConfirmed,   cssClass: 'result-item reveal-item' },
      { key: 'addressValidated', label: 'Data Quality — Address',         value: this.dataCloudJoins.addressValidated, cssClass: 'result-item reveal-item' },
      { key: 'identityConf',     label: 'Identity Confidence',            value: this.dataCloudJoins.identityConfidence, cssClass: 'result-item reveal-item' },
      { key: 'costOfPursuit',    label: 'Cost of Pursuit',                value: this.dataCloudJoins.costOfPursuit,    cssClass: 'result-item reveal-item' },
      { key: 'lifetimeMargin',   label: 'Expected Lifetime Margin',       value: this.dataCloudJoins.lifetimeMargin,   cssClass: 'result-item reveal-item' },
      { key: 'pursuitWeight',    label: 'Pursuit Cost Weighting',         value: this.dataCloudJoins.pursuitWeighting, cssClass: 'result-item reveal-item' },
    ];
    return all.slice(0, this.readVisibleCount).filter(i => i.value != null && i.value !== '');
  }

  get visibleActSignals() {
    const all = [
      { key: 'sourceQuality', label: 'Source quality assessment' },
      { key: 'appetite',      label: 'Financial appetite matching' },
      { key: 'propensity',    label: 'Propensity modeling' }
    ];
    return all.slice(0, this.actVisibleCount);
  }

  get visibleLoop2Signals() {
    const pursue = [
      { key: 'por',      label: 'Verifying Producer of Record constraint' },
      { key: 'queue',    label: 'Assigning lead to agent queue' },
      { key: 'complete', label: 'Routing complete' }
    ];
    const nurture = [
      { key: 'campaign', label: 'Creating campaign membership' },
      { key: 'nurture',  label: 'Assigning to nurture workflow' },
      { key: 'complete', label: 'Routing complete' }
    ];
    return (this.isPursueVerdict ? pursue : nurture).slice(0, this.loop2VisibleCount);
  }

  get isInitialPhase()    { return this.currentPhase === 'initial'; }
  get isReadApiProgress() { return this.currentPhase === 'readApiProgress'; }
  get isDataCloudPhase()  { return this.currentPhase === 'dataCloudJoins'; }
  get isReadPhase()       { return this.currentPhase === 'readComplete'; }
  get isSnapshotComplete(){ return this.currentPhase === 'snapshotComplete'; }
  get isActPhase()        { return this.currentPhase === 'actVerdictComplete'; }
  get isActProcessing()   { return this.currentPhase === 'actProcessing'; }
  get isLoop2Phase()      { return this.currentPhase === 'loop2Complete'; }
  get isLoop2Processing() { return this.currentPhase === 'loop2Processing'; }
  get isLoadingState()    { return this.isLoading; }

  get currentLoopStatus() {
    const statuses = {
      'initial':          'LOOP 1: READY',
      'dataCloudJoins':   'LOOP 1: LOOM READ API',
      'readComplete':     'LOOP 1: SNAPSHOT COMPLETE',
      'actVerdictComplete': 'LOOP 1: LOOM CLASSIFIER',
      'loop2Complete':    'LOOP 2: LOOM ROUTE'
    };
    return statuses[this.currentPhase] || 'LOOP 1';
  }

  get verdictOutcome()    { return this.verdict ? this.verdict.toUpperCase() : ''; }
  get verdictConfidence() { return this.actResult?.confidence ? (this.actResult.confidence * 100).toFixed(0) + '%' : ''; }
  get isHardDisqualify()  { return this.verdict === 'Hard Disqualify'; }
  get shouldShowLoop2()   { return !this.isHardDisqualify; }
  get isPursueVerdict()   { return this.verdict === 'Pursue'; }
  get loop2Message()      { return this.verdict === 'Pursue' ? 'routing to Producer of Record' : 'routing to Marketing Cloud campaign'; }
}
