function previewPlots(dataDir, outDir)
%PREVIEWPLOTS  The PC's session pictures (TV-OUT-05), drawn from a session's output files.
%   Reads shots.json, rallies.json and trajectories.json (the pipeline's
%   outputs, or the synthetic preview in docs/preview/data) and writes:
%     bounce_<type>.png   bounces by shot type, coloured by speed (mph)
%     spin_effect.png     forehand bounces coloured by spin effect (ft)
%     rally_NN_3d.png     one rally's paths in 3D on the court
%     side_RR_SS.png      one shot from the side, real path and no-spin path
%     speed_hist.png, rpm_hist.png   speed and spin-rate histograms by type
%   One colour scheme throughout: parula for values, the court in blue and
%   green with white lines, as the app's court is drawn in white on black.
if ~exist(outDir, 'dir'), mkdir(outDir); end
c = tv.court.constants();
sh = jsondecode(fileread(fullfile(dataDir, 'shots.json')));
tr = jsondecode(fileread(fullfile(dataDir, 'trajectories.json')));
mph = 2.23694;  ft = 3.28084;
types = {'serve', 'forehand', 'backhand'};
for k = 1:numel(types)
    s = sh(strcmp({sh.type}, types{k}));
    B = cell2mat(arrayfun(@(x) reshape(nanIfEmpty(x.bounce), 1, 2), s, 'UniformOutput', false));
    ok = all(isfinite(B), 2);
    f = newFig([0 0 1100 620]);
    drawCourt(c); hold on
    scatter(B(ok, 1), B(ok, 2), 36, [s(ok).speedContact] * mph, 'filled', 'MarkerEdgeColor', [0.1 0.1 0.1]);
    colormap(parula);  cb = colorbar;  cb.Label.String = 'speed at contact (mph)';
    axis equal;  xlim([-15 15]);  ylim([-7.5 7.5]);
    title(sprintf('%ss: %d bounces, coloured by speed (SYNTHETIC)', types{k}, nnz(ok)));
    xlabel('along the court (m)');  ylabel('across (m)');
    save1(f, fullfile(outDir, sprintf('bounce_%s.png', types{k})));
end
s = sh(strcmp({sh.type}, 'forehand'));
B = cell2mat(arrayfun(@(x) reshape(nanIfEmpty(x.bounce), 1, 2), s, 'UniformOutput', false));
fx = arrayfun(@(x) numOr(x.spinEffect), s);
ok = all(isfinite(B), 2) & isfinite(fx(:));
f = newFig([0 0 1100 620]);
drawCourt(c); hold on
scatter(B(ok, 1), B(ok, 2), 36, -fx(ok) * ft, 'filled', 'MarkerEdgeColor', [0.1 0.1 0.1]);
colormap(parula);  cb = colorbar;  cb.Label.String = 'spin effect: ft shorter than with no spin';
axis equal;  xlim([-15 15]);  ylim([-7.5 7.5]);
title('Forehand bounces, coloured by spin effect (SYNTHETIC)');
save1(f, fullfile(outDir, 'spin_effect.png'));
% one rally in 3D
r = 3;
f = newFig([0 0 1100 650]);
drawCourt(c); hold on
for t = tr([tr.rally] == r)'
    P = t.xyz;  plot3(P(:, 1), P(:, 2), P(:, 3), 'LineWidth', 2);
end
plot3([0 0], [-c.postY c.postY], [c.netHeightPost c.netHeightPost], 'k-', 'LineWidth', 2);
view(-35, 22);  axis equal;  zlim([0 6]);  grid on
title(sprintf('Rally %d, every shot (SYNTHETIC)', r));
save1(f, fullfile(outDir, sprintf('rally_%02d_3d.png', r)));
% one shot from the side
t = tr(find([tr.rally] == r & [tr.shot] == 2, 1));
P = t.xyz;  P0 = t.noSpin;
d = (P(end, 1:2) - P(1, 1:2)) / norm(P(end, 1:2) - P(1, 1:2));
along = @(Q) (Q(:, 1:2) - P(1, 1:2)) * d';
f = newFig([0 0 1100 420]);
plot(along(P) * ft, P(:, 3) * ft, 'LineWidth', 2.5); hold on
plot(along(P0) * ft, max(P0(:, 3), 0) * ft, '--', 'LineWidth', 1.5);
s = sh(find([sh.rally] == r & [sh.index] == 2, 1));
yline(0, 'k-');  grid on
xlabel('distance from contact (ft)');  ylabel('height (ft)');
legend({'real path', 'same launch, no spin'}, 'Location', 'northeast');
title(sprintf('Rally %d shot 2, %s %.0f mph: spin brought it down %.1f ft (SYNTHETIC)', r, s.type, s.speedContact * mph, -numOr(s.spinEffect) * ft));
save1(f, fullfile(outDir, sprintf('side_%02d_%02d.png', r, 2)));
% histograms
f = newFig([0 0 1100 450]);
hold on
for k = 1:numel(types)
    histogram([sh(strcmp({sh.type}, types{k})).speedContact] * mph, 'BinWidth', 4, 'DisplayStyle', 'stairs', 'LineWidth', 2);
end
legend(types);  xlabel('speed at contact (mph)');  ylabel('shots');  grid on
title('Speeds by shot type (SYNTHETIC)');
save1(f, fullfile(outDir, 'speed_hist.png'));
f = newFig([0 0 1100 450]);
hold on
for k = 1:numel(types)
    v = arrayfun(@(x) numOr(x.rpm), sh(strcmp({sh.type}, types{k})));
    histogram(v(isfinite(v)), 'BinWidth', 150, 'DisplayStyle', 'stairs', 'LineWidth', 2);
end
legend(types);  xlabel('spin rate (rpm, each about ±25%)');  ylabel('shots');  grid on
title('Spin rates by shot type (SYNTHETIC)');
save1(f, fullfile(outDir, 'rpm_hist.png'));
end

function v = numOr(x)
if isempty(x) || ~isnumeric(x), v = NaN; else, v = double(x); end
end

function b = nanIfEmpty(b)
if isempty(b) || ~isnumeric(b) || numel(b) < 2, b = [NaN NaN]; end
end

function f = newFig(pos)
f = figure('Visible', 'off', 'Color', 'w', 'Position', pos);
end

function save1(f, file)
exportgraphics(f, file, 'Resolution', 150);
close(f);
end

function drawCourt(c)
L = c.halfLength;  D = c.halfDoubles;  S = c.halfSingles;  sv = c.serviceLine;
fill([-L-3 L+3 L+3 -L-3], [-D-2 -D-2 D+2 D+2], [0.24 0.47 0.31], 'EdgeColor', 'none'); hold on
fill([-L L L -L], [-D -D D D], [0.2 0.36 0.59], 'EdgeColor', 'none');
seg = [-L -D L -D; -L D L D; -L -S L -S; -L S L S; -L -D -L D; L -D L D; -sv -S -sv S; sv -S sv S; -sv 0 sv 0];
for k = 1:size(seg, 1), plot(seg(k, [1 3]), seg(k, [2 4]), 'w-', 'LineWidth', 1.2); end
plot([0 0], [-c.postY c.postY], 'k-', 'LineWidth', 2);
end
