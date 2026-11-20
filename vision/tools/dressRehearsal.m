function R = dressRehearsal(root, opts)
%DRESSREHEARSAL  Tuesday's whole chain on a synthetic Tuesday (Chris, 22 Nov, item 7).
%   R = dressRehearsal('out/rehearsal')                         4K at 240, HEVC (CI)
%   R = dressRehearsal('out/rehearsal', struct('size', 'small'))  960 x 540, for a quick local run
%   1. Writes Tuesday's clips (tv.synth.tuesdayClip: empty court and still balls, a drop, a toss onto
%      a target, a machine feed) as camera-like files: HEVC MP4 at the camera's own frame rate,
%      GoPro names, CAM1/CAM2 folders, timecode and start times, an LRV beside each; the machine
%      clip is split into two chapters.
%   2. Runs every piece in Tuesday's order, as on Tuesday: checkCameraFile on each first chapter;
%      quickLook on clip 1 (calibration from the court lines); quickLook on the other clips with
%      clip 1's calibration (one calibration, timing solved per clip); groundTruthReport from a
%      measurements file filled as Chris will fill it.
%   3. Compares with the truth it was made from, and records every step: ok, or what broke.
%   Writes root/rehearsal.md. A step that fails is recorded and the rest still run.
if nargin < 1, root = fullfile(pwd, 'out', 'rehearsal'); end
if nargin < 2, opts = struct(); end
if ~isfield(opts, 'size'), opts.size = 'camera'; end
if ~isfield(opts, 'clips'), opts.clips = {'clip1', 'clip2', 'clip3', 'clip4'}; end
if ~exist(root, 'dir'), mkdir(root); end
here = fileparts(mfilename('fullpath'));
M = tv.readJson(fullfile(here, '..', 'groundtruth', 'template.json'));
M.stillBalls.atS = 1.0;  M.session = 'rehearsal';
R.steps = struct('step', {}, 'ok', {}, 'note', {});
files = struct();  truths = struct();
% --- 1. the clips as camera files ---------------------------------------------------------
for i = 1:numel(opts.clips)
    nm = opts.clips{i};
    try
        [sc, truth] = tv.synth.tuesdayClip(nm, M, opts.size);
        if strcmp(nm, 'clip4'), sc.chapterS = 1.6; end            % a recording in two chapters
        cams = tv.synth.cameras(sc);
        f = cell(1, 2);
        for k = 1:2, f{k} = tv.synth.writeRecording(fullfile(root, sprintf('CAM%d', k)), cams(k), sc, truth, k); end
        files.(nm) = f;  truths.(nm) = struct('truth', truth, 'cams', cams, 'sc', sc);
        R.steps(end+1) = step(sprintf('write %s', nm), true, sprintf('%s, %s', rel(f{1}, root), rel(f{2}, root)));
    catch err
        R.steps(end+1) = step(sprintf('write %s', nm), false, err.message);
    end
end
% --- 2a. the camera files -------------------------------------------------------------------
for nm = fieldnames(files)'
    for k = 1:2
        try
            C = checkCameraFile(files.(nm{1}){k});
            bad = C.checks(~strcmp(C.checks(:, 2), 'ok'), :);
            note = strjoin(cellfun(@(a, b, c) sprintf('%s %s (%s)', a, b, c), bad(:, 1), bad(:, 2), bad(:, 3), 'UniformOutput', false)', '; ');
            R.steps(end+1) = step(sprintf('checkCameraFile %s camera %d', nm{1}, k), true, note);
        catch err
            R.steps(end+1) = step(sprintf('checkCameraFile %s camera %d', nm{1}, k), false, err.message);
        end
    end
end
% --- 2b. quick looks: clip 1 calibrates, the others reuse it ------------------------------------
runs = struct();  calibFile = '';
for nm = fieldnames(files)'
    out = fullfile(root, 'run', nm{1});
    try
        if strcmp(nm{1}, 'clip1') || isempty(calibFile)
            res = quickLook(files.(nm{1}), out);
            calibFile = fullfile(out, 'stages', 'calib.mat');
        else
            res = quickLook(files.(nm{1}), out, calibFile);
        end
        runs.(nm{1}) = res;
        tr = truths.(nm{1});
        R.steps(end+1) = step(sprintf('quickLook %s', nm{1}), true, sprintf('%d flights, %d shots; camera 2 offset %.2f ms off the truth', ...
            sum(cellfun(@numel, res.segs)), numel(res.shots), 1000 * offsetErr(res, tr)));
    catch err
        R.steps(end+1) = step(sprintf('quickLook %s', nm{1}), false, err.message);
    end
    % clip 1's calibration serves the rest even when a later stage of clip 1 broke
    if isempty(calibFile) && exist(fullfile(out, 'stages', 'calib.mat'), 'file'), calibFile = fullfile(out, 'stages', 'calib.mat'); end
end
% --- 2c. the accuracy report ----------------------------------------------------------------
try
    if isfield(runs, 'clip1')
        runs.cams = runs.clip1.cams;
        Cf = load(calibFile);  runs.bg = Cf.out.bg;
        sf = cell(1, 2);
        for k = 1:2
            info = runs.clip1.rec(k);
            f0 = find(info.pts >= M.stillBalls.atS, 1);  if isempty(f0), f0 = info.nFrames; end
            sf{k} = tv.media.readFrames(info, f0 - 1, 1);
        end
        runs.stillFrames = sf;
    end
    G = groundTruthReport(M, runs, fullfile(root, 'groundtruth.md'));
    R.groundTruth = G;
    R.steps(end+1) = step('groundTruthReport', true, summary(G));
catch err
    R.steps(end+1) = step('groundTruthReport', false, err.message);
end
R.files = files;
writeOut(R, root);
end

function s = step(name, ok, note)
s = struct('step', name, 'ok', ok, 'note', note);
end

function r = rel(f, root)
r = strrep(f, [root filesep], '');
end

function e = offsetErr(res, tr)
% where camera 2's file starts on camera 1's clock: found (coarse start + the fine offset) against the
% truth (each camera's clock at its first frame, mapped to truth time; camera 1's file starts at 0)
e = NaN;
try
    c = tr.cams;
    truthStart2 = c(2).clockOffset + c(2).recordStart * (1 + c(2).clockDrift) - (c(1).clockOffset + c(1).recordStart);
    e = (res.sync.startOffset(2) + res.sync.delta) - truthStart2;
catch
end
end

function t = summary(G)
t = '';
if isfield(G, 'drop') && ~isempty(G.drop.g), t = [t sprintf('g %.2f, release %.3f m; ', median(G.drop.g), median(G.drop.top))]; end
if isfield(G, 'still'), t = [t sprintf('still balls found %d of %d, error median %.1f cm; ', nnz([G.still.found]), numel(G.still), 100 * median([G.still.err], 'omitnan'))]; end
if isfield(G, 'targets'), t = [t sprintf('target bounces %d; ', sum([G.targets.n]))]; end
if isfield(G, 'machine') && ~isempty(G.machine), t = [t sprintf('machine feeds %d; ', sum([G.machine.n]))]; end
if isfield(G, 'cameras'), t = [t sprintf('cameras %.1f / %.1f cm from the tape', 100 * G.cameras(1).err, 100 * G.cameras(end).err)]; end
end

function writeOut(R, root)
L = {'# Dress rehearsal: a synthetic Tuesday through the whole chain (SYNTHETIC)', ''};
L{end+1} = '| Step | Result | Note |';
L{end+1} = '|---|---|---|';
for s = R.steps(:)'
    ok = 'ok';  if ~s.ok, ok = '**broke**'; end
    L{end+1} = sprintf('| %s | %s | %s |', s.step, ok, strrep(s.note, '|', '/')); %#ok<AGROW>
end
if isfield(R, 'groundTruth') && isfield(R.groundTruth, 'text')
    L{end+1} = '';  L{end+1} = R.groundTruth.text;
end
fid = fopen(fullfile(root, 'rehearsal.md'), 'w');  fprintf(fid, '%s\n', L{:});  fclose(fid);
fprintf('%s\n', L{:});
end
