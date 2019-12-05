function write_duneuro_conductivity_file(conductivity,cond_filename)
% write_duneuro_conductivity_file(conductivity_tensor,cond_filename)
% Create a file with .con extension.
% This file is used by the duneuro application 
% input : conductivity : vector containing the conductivity value of
% each layer.
% Isotropic conductivity only, one value per layer. 

% Author : Takfarinas MEDANI, August 2019,

[filepath,name,ext] = fileparts(cond_filename);
if isempty(ext) || ~strcmp(ext,'.con')
    ext = '.con';
end
cond_filename = [filepath,name,ext];
fid = fopen(cond_filename , 'w');
fprintf(fid, '%d\t', conductivity);
fclose(fid);
end