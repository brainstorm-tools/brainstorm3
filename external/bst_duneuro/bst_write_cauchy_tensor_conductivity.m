function bst_write_cauchy_tensor_conductivity(elem,conductivity_tensor,condfilename)

%% Write the CAUCHY Conductivity file
%bst_write_cauchy_tensor_conductivity(elem,tensor,confilename)
%geofilename = 'ca_conductivity.knw';
% inputs : elem
% geofilename = 'ca_main_mesh.geo'; string should have the name ca_mesh_XXX
% elem = model.volume.elem; list of elem Nex4 (or x5 with label) or Nex8
% (tetra ou hex) (or x9 with label)
% geofilename = 'ca_main_mesh.geo'; string should have the name ca_mesh_XXX
% elem = model.volume.elem; list of elem Nex4 (or x5 with label) or Nex8
% (tetra ou hex) (or x9 with label)
% tensor should be a matrix with NbLayers x 6 % xx, yy, zz, xy, yz, zx or just a vector of 1 x 6 for each layer, which
% mean Nblayer x 6  in case of Nblayer layer
% in the case of the tensor has the size of the number of element, then
% these value will be write directly in the file

% example : 
% conductivity_tensor = [ 11 12 13 14 15 16;...
%                                     21 22 23 24 25 26;...
%                                     31 32 33 34 35 36];
% condfilename = 'ca_tensor.knw' ; 
% bst_write_cauchy_tensor_conductivity(elem,tensor,geofilename)

%Author : Takfarinas MEDANI, October 2019.

%% ====> the space between value are important, for cauchy file geo and as well here
% todo : check the extension of the file and set it to .knw
%% Read tensor
% xx, yy, zz, xy, yz, zx or just a vector of 1 x 6 for each layer, which
% mean Nbx6 layer in case of 6 layer
% model of tensor file : 
% BOI - TENSOR
% 1  0.33000      0.33000      0.33000
% 0.0000       0.0000       0.0000
% 2  0.33000      0.33000      0.33000
% 0.0000       0.0000       0.0000
% 3  0.33000      0.33000      0.33000
% ...
%     475270  0.38878E-01  0.39538E-01  0.97841E-02
% 0.27725E-02 -0.89063E-02  0.10029E-01
% 475271  0.38878E-01  0.39538E-01  0.97841E-02                                

% check the filename :
[filepath,name,ext] = fileparts(condfilename);
if ~strcmp(ext,'.knw')
    ext = '.knw';
end

name = [name '_tensor'];
filename = [name ext];

%% Read elem
if size(elem,2)<7
    % tetra\
    disp('Tetra elements are detected')
    %elem = elem(:,1:4);
else
    % hexa
    disp('Hexa elements are detected')
    %elem = elem(:,1:8);
end

% to check for hexahedra mesh
index_elem = 1 : length(elem); index_elem = index_elem';
if length(conductivity_tensor) ~= length(index_elem)
% case of isotropic 
if sum(size(conductivity_tensor)) == 7  % == [1 6] or == [6 1]
conductivity_tensor = [ conductivity_tensor;...
                                    conductivity_tensor ;...
                                    conductivity_tensor];
end
conductivity_tensor = reshape(conductivity_tensor,[],6);

disp('Compare the nb of layer from the elements labels and the tensor')
if size(conductivity_tensor,1) ~= length(unique(elem(:,end)))
    disp(['There are ' num2str(size(conductivity_tensor,1)) ' conductivities tensors values for  '  num2str( length(unique(elem(:,end)))) ' layers']);
    error('The element id and the connectivity tensor are not the same')
else
    disp('The mesh model fits to the conductivity model');
    disp(['There are ' num2str(size(conductivity_tensor,1)) ' conductivities tensors values for ' num2str( length(unique(elem(:,end)))) ' layers']);
end

% elem index : 1 : Ne
% tensor
    value_line1 = [index_elem conductivity_tensor(elem(:,5),:) ];
else
    % cas anisotropic
    value_line1 = [index_elem conductivity_tensor];
end
%value_line2 = [conductivity_tensor(elem(:,5),4:6)];

% write the geo file
fid = fopen(filename, 'w');
fprintf(fid, 'BOI - TENSORVALUEFILE\n');
fprintf(fid, '========================================================\n');
fprintf(fid, '========================================================\n');
fprintf(fid,'BOI - TENSOR\n');
fprintf(fid,'         %d   %1.5f       %1.5f       %1.5f\n             %1.5f       %1.5f       %1.5f\n', value_line1' );
fprintf(fid,'EOI - TENSOR\n');
fprintf(fid,'========================================================\n');
fprintf(fid,'========================================================\n');
fprintf(fid,'EOI - TENSORVALUEFILE\n');

fclose(fid);
%fclose('all');
end
