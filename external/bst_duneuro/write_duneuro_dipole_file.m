function write_duneuro_dipole_file(dipoles_pos,dipole_filename)
% write_duneuro_dipole_file(dipoles_pos,dipole_filename)
% dipoles_pos : 3D dipoles position within Cartisien coordinates, forma :
% Ndipole x 3   [x1,y1,z1 ; x2 y2 z3; .... ; xn yn zn]
% dipole_filename : string with the name of the output file from this
% function.
% This function will generate also the unconstrained orientation for each
% dipole. ie the output file will have 3*N dipoles (3 cartisian direction for each)
%      [x1,y1,z1, 1, 0, 0,;
%      x1,y1,z1, 0, 1, 0;
%      x1,y1,z1, 1, 0, 1;
%      x2,y2,z2, 1, 0, 0;
%      x2,y2,z2, 0, 1, 0;
%      x2 y2 y2, 0, 0, 1;
%      .... ; 
%      xn yn zn];
% Authors: Takfarinas MEDANI, August 2019;     

[filepath,name,ext] = fileparts(dipole_filename);
if isempty(ext) || ~strcmp(ext,'.txt')
    ext = '.txt';
end
dipole_filename = [filepath,name,ext];
Nb_dipole = size(dipoles_pos, 1); 
% generate triedre orientation for each dipole
dipoles_pos_orie = [kron(dipoles_pos,ones(3,1)), kron(ones(Nb_dipole,1), eye(3))];
fid = fopen(dipole_filename, 'wt+');
fprintf(fid, '%d %d %d %d %d %d \n', dipoles_pos_orie');
fclose(fid); 
end