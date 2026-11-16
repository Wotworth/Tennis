function box = interest(opts)
%INTEREST  Chris's court of interest (TV-ADJ-01): a box in the court frame.
%   opts: behindBaseline (m, default 5), beyondSideline (m beyond the DOUBLES
%   sideline, default 2), maxHeight (m, default 12) - tv.pipeline.defaults' cfg.court.
%   box: x, y, z limits [lo hi]. Chris, 16 Nov: neighbouring courts' balls and
%   players are outside it (their doubles sideline is about 3.66 m from his).
%   RETUNE(real footage): the three distances, per court if a court is unusual.
if nargin < 1 || isempty(opts), opts = struct(); end
d = struct('behindBaseline', 5, 'beyondSideline', 2, 'maxHeight', 12);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
c = tv.court.constants();
xe = c.halfLength + opts.behindBaseline;
ye = c.halfDoubles + opts.beyondSideline;
box = struct('x', [-xe xe], 'y', [-ye ye], 'z', [-0.5 opts.maxHeight], 'opts', opts);
end
