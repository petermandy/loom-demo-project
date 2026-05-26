import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import callRead from '@salesforce/apex/Loop1OrchestratorController.callRead';
import callAct from '@salesforce/apex/Loop1OrchestratorController.callAct';
import callStage from '@salesforce/apex/Loop1OrchestratorController.callStage';
import callObserve from '@salesforce/apex/Loop1OrchestratorController.callObserve';
import callTune from '@salesforce/apex/Loop1OrchestratorController.callTune';
import approveRelease from '@salesforce/apex/LoopControlPlaneController.approveRelease';

const LEAD_FIELDS = ['Lead.Name', 'Lead.Id'];

export default class LoopAgentChat extends LightningElement {
  @api recordId;
  
  @track messages = [];
  @track isRunning = false;
  @track errorMessage = '';
  @track leadName = '';
  @track showApproveButton = false;
  @track showContinueButton = false;
  @track hasStarted = false;
  @track messageCounter = 0;
  
  @wire(getRecord, { recordId: '$recordId', fields: LEAD_FIELDS })
  wiredLead({ error, data }) {
    if (data) {
      this.leadName = getFieldValue(data, 'Lead.Name');
    } else if (error) {
      this.errorMessage = 'Could not load lead';
    }
  }

  connectedCallback() {
    this.addAgentMessage('Ready to analyze this lead. Click Start Analysis to begin.');
  }

  handleStartAnalysis() {
    this.hasStarted = true;
    this.runFullLoop();
  }

  handleContinue() {
    this.showContinueButton = false;
    this.continueLoopAfterPause();
  }

  handleApprove() {
    this.showApproveButton = false;
    this.approveAndRelease();
  }

  handleReject() {
    this.addAgentMessage('v2.8.0 release rejected. Staying with v2.7.0 champion.');
    this.showApproveButton = false;
  }

  async runFullLoop() {
    this.isRunning = true;
    this.errorMessage = '';
    this.messages = [];
    this.addAgentMessage('Starting Loop1 workflow. Running v2.7.0 champion model...');

    try {
      this.addAgentMessage('Reading lead features into snapshot...');
      const readResult = await callRead({ leadIds: [this.recordId] });
      if (!readResult.success) throw new Error('Read failed');

      await this.sleep(800);
      const actResult = await callAct({ leadIds: [this.recordId], readSnapshotIds: readResult.readSnapshotIds });
      if (!actResult.success) throw new Error('Act failed');

      const pred = actResult.predictions && actResult.predictions[0];
      if (pred) {
        this.addAgentMessage('', {
          verdict: pred.verdict,
          confidence: (pred.confidence * 100).toFixed(2) + '%',
          isAgent: true
        });
      }

      this.addAgentMessage('Verdict is marginal. Pausing for review before TUNE.');
      this.showContinueButton = true;
      this.isRunning = false;

    } catch (error) {
      this.errorMessage = error.message;
      this.isRunning = false;
    }
  }

  async continueLoopAfterPause() {
    this.isRunning = true;
    this.errorMessage = '';

    try {
      this.addAgentMessage('Running STAGE: Creating activities...');
      await this.sleep(600);

      this.addAgentMessage('Running OBSERVE: Evaluating decision...');
      await this.sleep(600);

      this.addAgentMessage('Running TUNE: Generating proposals...');
      await this.sleep(1000);
      const tuneResult = await callTune({ observeSummary: 'Marginal predictions' });

      this.addAgentMessage('', {
        proposal: 'v2.8.0: De-weight aggregator. Re-weight intent signals.',
        isAgent: true
      });

      this.addAgentMessage('v2.8.0 ready. Approve to promote?');
      this.showApproveButton = true;
      this.isRunning = false;

    } catch (error) {
      this.errorMessage = error.message;
      this.isRunning = false;
    }
  }

  async approveAndRelease() {
    this.isRunning = true;

    try {
      this.addAgentMessage('Promoting v2.8.0 to champion...');
      await this.sleep(800);

      const releaseResult = await approveRelease();
      if (!releaseResult.success) throw new Error('Approval failed');

      this.addAgentMessage('Re-evaluating with v2.8.0...');
      await this.sleep(800);

      const rerunResult = await callAct({ leadIds: [this.recordId], readSnapshotIds: [] });
      const pred = rerunResult.predictions && rerunResult.predictions[0];

      if (pred) {
        this.addAgentMessage('', {
          verdict: pred.verdict,
          confidence: (pred.confidence * 100).toFixed(2) + '%',
          isAgent: true
        });
      }

      this.addAgentMessage('Success! ' + this.leadName + ' reclassified with v2.8.0.');
      this.isRunning = false;

    } catch (error) {
      this.errorMessage = error.message;
      this.isRunning = false;
    }
  }

  addAgentMessage(text, options = {}) {
    const msg = {
      id: '' + this.messageCounter++,
      text: text,
      isAgent: true,
      cssClass: 'agent-message',
      messageClass: 'message-bubble',
      ...options
    };

    if (msg.verdict) {
      msg.verdictClass = 'verdict-' + (msg.verdict || '').toLowerCase().replace(/_/g, '-');
    }

    this.messages = [...this.messages, msg];
    this.scrollToBottom();
  }

  scrollToBottom() {
    setTimeout(() => {
      const container = this.template.querySelector('#chatContainer');
      if (container) {
        container.scrollTop = container.scrollHeight;
      }
    }, 50);
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
