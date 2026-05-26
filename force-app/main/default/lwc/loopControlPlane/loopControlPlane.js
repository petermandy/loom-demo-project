import { LightningElement, track } from 'lwc';
import getControlPlaneData from '@salesforce/apex/LoopControlPlaneController.getControlPlaneData';
import approveRelease from '@salesforce/apex/LoopControlPlaneController.approveRelease';

const PIPELINE_STAGES = [
    'Validating proposals',
    'Running shadow tests',
    'Promoting candidate',
    'Updating decision policy',
    'Champion live'
];

export default class LoopControlPlane extends LightningElement {
    @track isLoading = true;
    @track isApproving = false;
    @track isPromoted = false;
    @track pipelineStage = -1;
    @track pipelineLabel = '';
    @track l1Proposals = [];
    @track l2Proposals = [];
    @track championVersion = 'v2.7.0';
    @track candidateVersion = 'v2.8.0';
    @track error = null;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        this.error = null;
        try {
            const data = await getControlPlaneData();
            this.l1Proposals = data.loop1Proposals || [];
            this.l2Proposals = data.loop2Proposals || [];
            const versions = data.modelVersions || [];
            for (const v of versions) {
                if (v.status === 'champion') this.championVersion = v.versionId;
                if (v.status === 'shadow') this.candidateVersion = v.versionId;
            }
            if (this.championVersion === 'v2.8.0') this.isPromoted = true;
        } catch (e) {
            this.error = (e.body && e.body.message) ? e.body.message : String(e);
        }
        this.isLoading = false;
    }

    async handleApprove() {
        this.isApproving = true;
        this.pipelineStage = 0;
        for (let i = 0; i < PIPELINE_STAGES.length; i++) {
            this.pipelineStage = i;
            this.pipelineLabel = PIPELINE_STAGES[i] + '...';
            await this._delay(900);
        }
        try {
            const result = await approveRelease();
            if (result.success) {
                this.pipelineStage = PIPELINE_STAGES.length;
                this.pipelineLabel = 'Champion live';
                this.championVersion = 'v2.8.0';
                this.isPromoted = true;
            } else {
                this.error = result.message;
            }
        } catch (e) {
            this.error = (e.body && e.body.message) ? e.body.message : String(e);
        }
        this.isApproving = false;
    }

    _delay(ms) {
        return new Promise(function(resolve) { setTimeout(resolve, ms); });
    }

    get hasProposals() {
        return this.l1Proposals.length > 0 || this.l2Proposals.length > 0;
    }

    get noProposals() {
        return !this.isLoading && !this.hasProposals;
    }

    get approveButtonLabel() {
        if (this.isApproving) return this.pipelineLabel;
        if (this.isPromoted) return 'v2.8.0 is Champion';
        return 'Approve and Release v2.8.0';
    }

    get approveButtonDisabled() {
        return this.isApproving || this.isPromoted;
    }

    get pipelineStages() {
        return PIPELINE_STAGES.map(function(label, i) {
            return {
                id: i,
                label: label,
                stateClass: i < this.pipelineStage ? 'stage done' : i === this.pipelineStage ? 'stage active' : 'stage pending'
            };
        }.bind(this));
    }

    get showPipeline() {
        return this.isApproving || this.isPromoted;
    }

    get l1ProposalsFormatted() {
        return this.l1Proposals.map(function(p) {
            return {
                id: p.id,
                loop: p.loop,
                fromVersion: p.fromVersion,
                toVersion: p.toVersion,
                noSignalRate: p.noSignalRate,
                overrideDelta: p.overrideDelta,
                proposalLines: p.proposals ? p.proposals.split('\n').filter(function(l) { return l.length > 0; }) : []
            };
        });
    }

    get l2ProposalsFormatted() {
        return this.l2Proposals.map(function(p) {
            return {
                id: p.id,
                loop: p.loop,
                modelUpdate: p.modelUpdate,
                confirmRate: p.confirmRate,
                totalObserved: p.totalObserved,
                proposalLines: p.proposals ? p.proposals.split('\n').filter(function(l) { return l.length > 0; }) : []
            };
        });
    }

    get overridePatterns() {
        return [
            { id: 1, pattern: 'Agent override rate', value: '2.1%', trend: 'stable', note: 'Within acceptable threshold' },
            { id: 2, pattern: 'POR constraint overrides', value: '0.3%', trend: 'down', note: 'POR matching improving' },
            { id: 3, pattern: 'Territory reassignments', value: '1.8%', trend: 'stable', note: 'Seasonal pattern' }
        ];
    }

    get supervisoryInsights() {
        return [
            { id: 1, insight: 'Jennifer Park routing to Sarah Chen validated by 3 independent signals: POR match, territory, track record', type: 'confirm', icon: '✓', insightClass: 'insight-row confirm' },
            { id: 2, insight: 'Marcus Reed medium-window nurture consistent with aggregator lead pattern — 847 similar leads in cohort', type: 'info', icon: 'i', insightClass: 'insight-row info' },
            { id: 3, insight: 'Loop2 POR constraint weight proposal (+10%) supported by 23% conversion rate differential vs territory-only matches', type: 'action', icon: '↑', insightClass: 'insight-row action' }
        ];
    }
}
