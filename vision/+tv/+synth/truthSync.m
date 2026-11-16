function sync = truthSync(cams, sync0)
%TRUTHSYNC  The pipeline's timing parameters that match the synthetic cameras exactly.
%   The pipeline maps camera 2's file time p onto session time (camera 1's) as
%     s = startOffset + p + Delta + eps * (startOffset + p - tref)   (plus the row delay),
%   and the synthetic clock is truth = c + clockOffset + clockDrift * c with c = recordStart + p
%   (camera 1: offset 0, drift 0, start 0, as in tv.synth.defaultScenario). Matching the two:
%     eps = clockDrift(2);  Delta = rs2 + off2 + dr2*rs2 - startOffset - dr2*(startOffset - tref).
%   Readout and shutter are the cameras' own. Used to set every timing error to zero, then
%   add exactly the error under study (tools/errorBudget.m).
sync = sync0;
rs2 = cams(2).recordStart;  off2 = cams(2).clockOffset;  dr2 = cams(2).clockDrift;
so = sync0.startOffset(2);
sync.drift = dr2;
sync.delta = rs2 + off2 + dr2 * rs2 - so - dr2 * (so - sync0.tref);
sync.readout = [cams.readout];
end
