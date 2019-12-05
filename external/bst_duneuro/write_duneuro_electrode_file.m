function write_duneuro_electrode_file(channel_loc, electrode_filename)
%write_duneuro_electrode_file(channel_loc, electrode_filename)
% Write the electrode file for Duneuro application
% channel_loc : 3D cartisien position of the electrodes, Nelec x 3
% Authors: Takfarinas MEDANI, August 2019;     

[filepath,name,ext] = fileparts(electrode_filename);
if isempty(ext) || ~strcmp(ext,'.txt')
    ext = '.txt';
end
electrode_filename = [filepath,name,ext];

fid = fopen(electrode_filename, 'wt+');
fprintf(fid, '%d %d %d  \n', channel_loc');
fclose(fid); 
end