function [call, margin] = lineCall(b, sd, isServe, serverSide, towardSign, cfg)
%LINECALL  In, out or too close to call, from the bounce and its uncertainty (TV-EVT-04).
%   b: bounce [x y]; sd: its 1-sigma error (m). Serves are judged against
%   the diagonal service box: serverSide is the sign of the server's y
%   (the box is on the other side of the centre line), towardSign the sign
%   of x for the receiving half. Other shots: the singles court
%   (cfg.lines = 'singles', default) or doubles. margin > 0: inside, by
%   that many metres from the nearest relevant line. Within 2 sigma of the
%   line: 'too close'.
c = tv.court.constants();
if nargin < 6 || ~isfield(cfg, 'lines'), cfg.lines = 'singles'; end
hw = c.halfSingles;  if strcmp(cfg.lines, 'doubles'), hw = c.halfDoubles; end
if isServe
    xin = [min(0, towardSign * c.serviceLine), max(0, towardSign * c.serviceLine)];
    yin = sort([0, -serverSide * c.halfSingles]);
else
    xin = [-c.halfLength, c.halfLength];
    if towardSign > 0, xin(1) = 0; else, xin(2) = 0; end
    yin = [-hw, hw];
end
margin = min([b(1) - xin(1), xin(2) - b(1), b(2) - yin(1), yin(2) - b(2)]);
if abs(margin) < 2 * sd, call = 'too close';
elseif margin > 0, call = 'in';
else, call = 'out'; end
end
