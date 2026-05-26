import { LightningElement, track } from 'lwc';
import callRead from '@salesforce/apex/Loop1OrchestratorController.callRead';
import callAct from '@salesforce/apex/Loop1OrchestratorController.callAct';
import callStage from '@salesforce/apex/Loop1OrchestratorController.callStage';
import callObserve from '@salesforce/apex/Loop1OrchestratorController.callObserve';
import callTune from '@salesforce/apex/Loop1OrchestratorController.callTune';
import callRouteRead from '@salesforce/apex/Loop1OrchestratorController.callRouteRead';
import callRouteAct from '@salesforce/apex/Loop1OrchestratorController.callRouteAct';
import callRouteStage from '@salesforce/apex/Loop1OrchestratorController.callRouteStage';
import callRouteObserve from '@salesforce/apex/Loop1OrchestratorController.callRouteObserve';
import callRouteTune from '@salesforce/apex/Loop1OrchestratorController.callRouteTune';
import callRollback from '@salesforce/apex/Loop1OrchestratorController.callRollback';
import callRerunNoSignal from '@salesforce/apex/Loop1OrchestratorController.callRerunNoSignal';

export default class Loop1Orchestrator extends LightningElement {
    @track messages = [];
    @track isRunning = false;
    @track isResetting = false;
    @track isPaused = false;
    @track currentStep = '';
    messageId = 0;
    _resolveResume = null;

    // Main demo leads — run in full chain
    leads = [
        { id: '00QdM00000deeNFUAY', name: 'Marcus Reed', role: 'Aggregator lead' },
        { id: '00QdM00000deeNGUAY', name: 'Jennifer Park', role: 'Carrier .com lead' },
        { id: '00QdM00000dfPlZUAU', name: 'David Kowalski', role: 'EverQuote candidate' }
    ];

    noSignalLeads = [];

    get leadIds() {
        return this.leads.map(l => l.id);
    }

    get allLeadIds() {
        return [...this.leads, ...this.noSignalLeads].map(l => l.id);
    }

    get hasMessages() {
        return this.messages.length > 0;
    }

    get buttonLabel() {
        if (this.isPaused) return 'Waiting for narrator...';
        if (this.isRunning) return 'Running: ' + this.currentStep + '...';
        return '▶ Run Full Loop1 + Loop2 RAOT Chain';
    }

    get runButtonDisabled() { return this.isRunning || this.isResetting; }
    get resetButtonDisabled() { return this.isRunning || this.isResetting; }
    get showContinue() { return this.isPaused; }
    get showRerun() { return !this.isRunning && !this.isPaused && this.messages.length > 0; }

    async handleReset() {
        this.isResetting = true;
        this.messages = [];
        this.addMessage('step', '🔄 Rolling back demo data...');
        try {
            const result = await callRollback({ leadIds: this.allLeadIds });
            if (result.success) {
                this.addMessage('success', result.message);
                this.addMessage('system', '✅ Ready for demo — click Run to start');
            } else {
                this.addMessage('error', '❌ Rollback failed: ' + result.message);
            }
        } catch (e) {
            this.addMessage('error', '❌ Rollback error: ' + e.body.message);
        }
        this.isResetting = false;
    }

    async runFullChain() {
        this.isRunning = true;
        this.isPaused = false;
        this.messages = [];

        const leadIds = this.leadIds;

        this.addMessage('divider', '── LOOP 1: CLASSIFY ──');

        this.currentStep = 'L1 Read';
        this.addMessage('step', '📖 Loop1 Read — capturing lead state...');
        const readResult = await callRead({ leadIds });
        if (!readResult.success) { this.addMessage('error', '❌ L1 Read failed: ' + readResult.message); this.isRunning = false; return; }
        this.addMessage('success', '✓ L1 Read: ' + readResult.message);

        this.currentStep = 'L1 Act';
        this.addMessage('step', '🎯 Loop1 Act — calling LUMEN classifier...');
        const actResult = await callAct({ leadIds, readSnapshotIds: readResult.readSnapshotIds });
        if (!actResult.success) { this.addMessage('error', '❌ L1 Act failed: ' + actResult.message); this.isRunning = false; return; }
        this.addMessage('success', '✓ L1 Act:\n' + actResult.message);

        this.isPaused = true;
        this.currentStep = '';
        this.addMessage('pause', '⏸ Verdicts classified. Narrate the fast-forward, then click Continue.');
        await this._waitForResume();
        this.isPaused = false;

        this.addMessage('divider', '── LOOP 1 (cont.) + LOOP 2 (starting) ──');

        await Promise.all([
            this._runLoop1Remainder(leadIds, actResult),
            this._runLoop2(leadIds)
        ]);

        this.addMessage('divider', '── COMPLETE ──');
        this.addMessage('system', '🎉 Full Loop1 + Loop2 RAOT chain complete');
        this.currentStep = '';
        this.isRunning = false;
    }

    async _runLoop1Remainder(leadIds, actResult) {
        this.currentStep = 'L1 Stage';
        this.addMessage('step', '📋 Loop1 Stage — staging activities...');
        const stageResult = await callStage({ leadIds, actSnapshotIds: actResult.actSnapshotIds });
        this.addMessage(stageResult.success ? 'success' : 'error',
            (stageResult.success ? '✓' : '❌') + ' L1 Stage: ' + stageResult.message);

        this.currentStep = 'L1 Observe';
        this.addMessage('step', '👁️ Loop1 Observe — observing outcomes...');
        const observeResult = await callObserve({ leadIds, actSnapshotIds: actResult.actSnapshotIds });
        if (!observeResult.success) { this.addMessage('error', '❌ L1 Observe failed: ' + observeResult.message); return; }
        this.addMessage('success', '✓ L1 Observe: ' + observeResult.message);

        this.currentStep = 'L1 Tune';
        this.addMessage('step', '🔧 Loop1 Tune — updating classifier model...');
        const tuneResult = await callTune({ observeSummary: observeResult.message });
        if (!tuneResult.success) { this.addMessage('error', '❌ L1 Tune failed: ' + tuneResult.message); return; }
        this.addMessage('success', '✓ L1 Tune: ' + tuneResult.message);
    }

    async _runLoop2(leadIds) {
        this.addMessage('divider', '── LOOP 2: ROUTE ──');

        this.addMessage('step', '📖 Loop2 Read — capturing routing state...');
        const routeReadResult = await callRouteRead({ leadIds });
        if (!routeReadResult.success) { this.addMessage('error', '❌ L2 Read failed: ' + routeReadResult.message); return; }
        this.addMessage('success', '✓ L2 Read: ' + routeReadResult.message);

        this.addMessage('step', '🎯 Loop2 Act — calling LUMEN router...');
        const routeActResult = await callRouteAct({ leadIds, routeReadSnapshotIds: routeReadResult.routeReadSnapshotIds });
        if (!routeActResult.success) { this.addMessage('error', '❌ L2 Act failed: ' + routeActResult.message); return; }
        this.addMessage('success', '✓ L2 Act:\n' + routeActResult.message);

        this.addMessage('step', '📋 Loop2 Stage — fast-forwarding observation window...');
        const routeStageResult = await callRouteStage({ leadIds });
        if (!routeStageResult.success) { this.addMessage('error', '❌ L2 Stage failed: ' + routeStageResult.message); return; }
        this.addMessage('success', '✓ L2 Stage: ' + routeStageResult.message);

        this.addMessage('step', '👁️ Loop2 Observe — observing routing outcomes...');
        const routeObserveResult = await callRouteObserve({ leadIds, routeActSnapshotIds: routeActResult.routeActSnapshotIds });
        if (!routeObserveResult.success) { this.addMessage('error', '❌ L2 Observe failed: ' + routeObserveResult.message); return; }
        this.addMessage('success', '✓ L2 Observe:\n' + routeObserveResult.message);

        this.addMessage('step', '🔧 Loop2 Tune — updating routing model...');
        const routeTuneResult = await callRouteTune({ observeSummary: routeObserveResult.observeSummary });
        if (!routeTuneResult.success) { this.addMessage('error', '❌ L2 Tune failed: ' + routeTuneResult.message); return; }
        this.addMessage('success', '✓ L2 Tune: ' + routeTuneResult.message);
    }

    _waitForResume() {
        return new Promise(resolve => { this._resolveResume = resolve; });
    }

    async handleRerun() {
        this.isRunning = true;
        this.addMessage('divider', '── RE-RUN: HARD DISQUALIFY LEADS ──');
        this.addMessage('step', '🔄 Querying Hard_Disqualify leads...');
        try {
            // Step 1: get Hard_Disqualify lead IDs
            const noSigResult = await callRerunNoSignal();
            if (!noSigResult.success) {
                this.addMessage('error', '❌ ' + noSigResult.message);
                this.isRunning = false;
                return;
            }
            const rerunIds = noSigResult.leadIds;
            this.addMessage('step', '🎯 Re-classifying ' + rerunIds.length + ' lead(s) with champion v2.8.0...');

            // Step 2: Read
            const readResult = await callRead({ leadIds: rerunIds });
            if (!readResult.success) {
                this.addMessage('error', '❌ Read failed: ' + readResult.message);
                this.isRunning = false;
                return;
            }

            // Step 3: Act
            const actResult = await callAct({ leadIds: rerunIds, readSnapshotIds: readResult.readSnapshotIds });
            if (actResult.success) {
                this.addMessage('success', '✓ Re-run complete: ' + actResult.message);
            } else {
                this.addMessage('error', '❌ Act failed: ' + actResult.message);
            }
        } catch (e) {
            this.addMessage('error', '❌ Re-run error: ' + (e.body ? e.body.message : e.message));
        }
        this.isRunning = false;
        // Scroll to bottom so new messages are visible
        setTimeout(() => {
            const container = this.template.querySelector('.messages-container');
            if (container) container.scrollTop = container.scrollHeight;
        }, 100);
    }

    handleContinue() {
        if (this._resolveResume) {
            this._resolveResume();
            this._resolveResume = null;
        }
    }

    addMessage(type, text) {
        this.messages = [...this.messages, {
            id: this.messageId++,
            type,
            text,
            messageClass: 'message ' + type
        }];
    }
}
