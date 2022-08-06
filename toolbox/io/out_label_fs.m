function out_label_fs(LabelFile, Comment, Vertices, Pos, Values)
% Writes FreeSurfer label file.
%
% INPUTS:
%    - LabelFile : Output file
%    - Comment   : Comment for the first line of the label file
%    - Vertices  : Vertex indices (0 based, column 1)
%    - Pos       : Locations in meters (columns 2 - 4 divided by 1000)
%    - Values    : Values at the vertices (column 5)

[fid, message] = fopen(LabelFile, 'w');
if (fid < 0)
    error('Cannot open file %s (%s)', LabelFile, message);
end

fprintf(fid,'# %s\n', Comment);
fprintf(fid, '%d\n', length(Vertices));
for k = 1:length(Vertices)
   fprintf(fid,'%d %.2f %.2f %.2f %f\n', Vertices(k), 1000*Pos(k,:), Values(k));
end

fclose(fid);

