function makeTestCard(drive)
%MAKETESTCARD  Turn an empty microSD card into a pretend GoPro card, for the day-one import check.
%   makeTestCard('E:') writes E:\DCIM\100GOPRO\ with two short recordings (test pattern and
%   sound, about 1 MB each) and their LRV and THM files, exactly as a GoPro lays them out,
%   with a made-up camera serial. Put the card in a reader and the watcher imports it as
%   a "new camera": copy, check, wipe the files, archive them in D:, alert "Cards safe to
%   remove". Use an EMPTY card: files already on it are left alone, but check first.
%   (docs/DAY-ONE.md, step "first verified card import".)
if nargin < 1 || isempty(drive), error('Give the card''s drive letter, e.g. makeTestCard(''E:'')'); end
root = [drive filesep];
if ~exist(root, 'dir'), error('No drive %s: is the card in a reader?', drive); end
existing = dir(fullfile(root, 'DCIM', '100GOPRO', '*.MP4'));
if ~isempty(existing), error('%s already has GoPro videos on it: use an empty card.', drive); end
now = tv.util.nowUtc();
tv.testing.fakeCard(root, 'C3509999000001', [now(1:19) '.000Z'], [1 2], 3);
fprintf('Test card ready on %s: put it in a reader on the top of the PC.\n', drive);
end
