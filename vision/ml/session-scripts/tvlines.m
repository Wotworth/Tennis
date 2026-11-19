% the line pixels the calibration found on a video's empty court (env VID), for the review document
addpath('/tmp/claude-0/scratchpad/vsnap'); pkg load image
v = getenv('VID'); out = ['/home/user/private-footage/run' v];
bg = double(imread([out '/bg.png']));
[mask, ~] = tv.calib.linePixels(bg, struct('minContrast', 20, 'minLength', 40, 'reach', [3 7]));
imwrite(uint8(255 * mask), [out '/lines.png']);
