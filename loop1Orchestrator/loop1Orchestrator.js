import { LightningElement, track } from 'lwc';

export default class Loop1Orchestrator extends LightningElement {
  @track messages = [
    { type: 'system', text: 'Loop1 Lead Classification Orchestrator' }
  ];
  @track isRunning = false;
  @track currentStep = 0;

  leads = [
    { id: '00QdM00000deeNFUAY', name: 'Marcus Reed', role: 'Aggregator lead' },
    { id: '00QdM00000deeNGUAY', name: 'Jennifer Park', role: 'Carrier .com lead' }
  ];

  orgUrl = 'https://orgfarm-8277e0e47d-dev-ed.develop.my.salesforce.com';

  async runFullChain() {
    this.isRunning = true;
    this.messages = [{ type: 'system', text: 'Loop1 Lead Classification Orchestrator' }];
    this.currentStep = 0;

    for (const lead of this.leads) {
      this.addMessage('user', `Process ${lead.name} (${lead.role})`);

      // Step 1: Read
      this.currentStep = 1;
      this.addMessage('system', `📖 Reading ${lead.name}...`);
      const readResult = await this.callEndpoint('read', { leadIds: [lead.id] });

      if (!readResult.success) {
        this.addMessage('error', `❌ Read failed: ${readResult.message}`);
        continue;
      }

      this.addMessage('assistant', `✓ Read: ${readResult.message}\nSnapshot: ${readResult.readSnapshotIds[0]}`);
      const readSnapshotIds = readResult.readSnapshotIds;

      // Step 2: Act
      this.currentStep = 2;
      this.addMessage('system', `🎯 Acting on ${lead.name}...`);
      const actResult = await this.callEndpoint('act', {
        leadIds: [lead.id],
        readSnapshotIds: readSnapshotIds
      });

      if (!actResult.success) {
        this.addMessage('error', `❌ Act failed: ${actResult.message}`);
        continue;
      }

      this.addMessage('assistant', `✓ Act: ${actResult.message}`);
      const actSnapshotIds = actResult.actSnapshotIds;

      // Step 3: Stage
      this.currentStep = 3;
      this.addMessage('system', `📋 Staging activities for ${lead.name}...`);
      const stageResult = await this.callEndpoint('stage', {
        leadIds: [lead.id],
        actSnapshotIds: actSnapshotIds
      });

      if (!stageResult.success) {
        this.addMessage('error', `❌ Stage failed: ${stageResult.message}`);
        continue;
      }

      this.addMessage('assistant', `✓ Stage: ${stageResult.message}`);

      // Step 4: Observe
      this.currentStep = 4;
      this.addMessage('system', `👁️ Observing ${lead.name}...`);
      const observeResult = await this.callEndpoint('observe', {
        leadIds: [lead.id],
        actSnapshotIds: actSnapshotIds
      });

      if (!observeResult.success) {
        this.addMessage('error', `❌ Observe failed: ${observeResult.message}`);
        continue;
      }

      this.addMessage('assistant', `✓ Observe: ${observeResult.message}`);

      // Step 5: Tune
      this.currentStep = 5;
      this.addMessage('system', `🔧 Tuning model based on ${lead.name}...`);
      const tuneResult = await this.callEndpoint('tune', {
        observeSummary: observeResult.message
      });

      if (!tuneResult.success) {
        this.addMessage('error', `❌ Tune failed: ${tuneResult.message}`);
        continue;
      }

      this.addMessage('assistant', `✓ Tune: ${tuneResult.message}`);
      this.addMessage('system', `✅ Complete for ${lead.name}`);
    }

    this.currentStep = 0;
    this.isRunning = false;
    this.addMessage('system', '🎉 Full orchestration complete');
  }

  async callEndpoint(endpoint, payload) {
    try {
      const response = await fetch(`${this.orgUrl}/services/apexrest/loop/${endpoint}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      if (response.ok) {
        return await response.json();
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (error) {
      return { success: false, message: `Error: ${error.message}` };
    }
  }

  addMessage(type, text) {
    const newMessages = [...this.messages];
    newMessages.push({ type, text });
    this.messages = newMessages;
  }

  get buttonLabel() {
    if (this.isRunning) {
      return `Running Step ${this.currentStep}/5...`;
    }
    return 'Run Full Loop1 Chain';
  }

  get buttonDisabled() {
    return this.isRunning;
  }
}
