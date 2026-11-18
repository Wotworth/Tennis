addpath('/tmp/claude-0/scratchpad/vsnap');
R = load('/home/user/private-footage/run3L2/single.mat'); b = R.bounces;
fid = fopen('/home/user/private-footage/check3L2/bounces2.csv', 'w');
for i = 1:numel(b), fprintf(fid, '%d,%d,%.2f,%.2f,%.2f,%.2f,%s,%s,%.2f\n', b(i).clip, b(i).frame, b(i).u, b(i).v, b(i).x, b(i).y, b(i).call, b(i).kind, b(i).cameM); end
fclose(fid);
k = {b.kind}; printf('play %d, spot %d, dribble %d, off %d\n', nnz(strcmp(k,'play')), nnz(strcmp(k,'spot')), nnz(strcmp(k,'dribble')), nnz(strcmp(k,'off')));
