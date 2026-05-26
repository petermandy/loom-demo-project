declare module "@salesforce/apex/Loop1OrchestratorController.readLeadSingleAsync" {
  export default function readLeadSingleAsync(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Loop1OrchestratorController.actLeadSingleAsync" {
  export default function actLeadSingleAsync(param: {recordId: any, readSnapshotId: any}): Promise<any>;
}
declare module "@salesforce/apex/Loop1OrchestratorController.loop2AssignSingleAsync" {
  export default function loop2AssignSingleAsync(param: {recordId: any, verdict: any}): Promise<any>;
}
declare module "@salesforce/apex/Loop1OrchestratorController.updateLeadClassificationFields" {
  export default function updateLeadClassificationFields(param: {recordId: any, classification: any}): Promise<any>;
}
declare module "@salesforce/apex/Loop1OrchestratorController.clearLeadEnrichmentData" {
  export default function clearLeadEnrichmentData(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Loop1OrchestratorController.getCampaignMembers" {
  export default function getCampaignMembers(param: {leadId: any}): Promise<any>;
}
