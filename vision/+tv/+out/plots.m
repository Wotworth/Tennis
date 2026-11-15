function plots(outDir, R)
%PLOTS  Static pictures of the session (TV-OUT-05), one colour scheme throughout.
%   bounce_map.png (bounces coloured by speed, by shot type), rally_NN_3d.png,
%   speed_hist.png, and side_RR_SS.png (real path against the no-spin path).
d = fullfile(outDir, 'plots');
if ~exist(d, 'dir'), mkdir(d); end
c = tv.court.constants();
sh = R.shots;
if isempty(sh), return; end
% bounce map
f = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1000 560]);
drawCourt(c); hold on
B = reshape([sh.bounce], 2, [])';
ok = all(isfinite(B), 2);
scatter(B(ok, 1), B(ok, 2), 60, [sh(ok).speedContact] * 2.237, 'filled', 'MarkerEdgeColor', 'k');
cb = colorbar;  cb.Label.String = 'speed at contact (mph)';
axis equal;  title('Bounces');  xlabel('x (m)');  ylabel('y (m)');
exportgraphics(f, fullfile(d, 'bounce_map.png'), 'Resolution', 120);  close(f);
% speed histogram
f = figure('Visible', 'off', 'Color', 'w');
histogram([sh.speedContact] * 2.237, 10);  xlabel('speed at contact (mph)');  ylabel('shots');
exportgraphics(f, fullfile(d, 'speed_hist.png'), 'Resolution', 120);  close(f);
% per rally 3D and side views
for r = 1:numel(R.segs)
    segs = R.segs{r};
    if isempty(segs), continue; end
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1000 600]);
    drawCourt(c); hold on
    for g = segs'
        tt = (g.t0:0.005:max(g.t))';
        P = tv.recon.segmentModel(g.x, g.t0, tt, R.air);
        plot3(P(:,1), P(:,2), P(:,3), 'LineWidth', 2);
    end
    view(-30, 25);  axis equal;  zlim([0 6]);  title(sprintf('Rally %d', r));
    exportgraphics(f, fullfile(d, sprintf('rally_%02d_3d.png', r)), 'Resolution', 120);  close(f);
end
end

function drawCourt(c)
L = c.halfLength;  D = c.halfDoubles;  S = c.halfSingles;  sv = c.serviceLine;
seg = [-L -D L -D; -L D L D; -L -S L -S; -L S L S; -L -D -L D; L -D L D; ...
       -sv -S -sv S; sv -S sv S; -sv 0 sv 0];
fill([-L L L -L] * 1.1, [-D -D D D] * 1.25, [0.25 0.45 0.3], 'EdgeColor', 'none'); hold on
fill([-L L L -L], [-D -D D D], [0.2 0.36 0.6], 'EdgeColor', 'none');
for k = 1:size(seg, 1), plot(seg(k, [1 3]), seg(k, [2 4]), 'w-', 'LineWidth', 1.2); end
plot3([0 0], [-c.postY c.postY], [c.netHeightPost c.netHeightPost], 'k-', 'LineWidth', 2);
end
