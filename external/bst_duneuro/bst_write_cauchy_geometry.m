function bst_write_cauchy_geometry(cfg)

%% Write the CAUCHY Geometry file
%bst_write_cauchy_geometry(node,elem,geofilename)
% inputs : node, elem
% geofilename = 'ca_main_mesh.geo'; string should have the name ca_mesh_XXX
% node = model.volume.node; list of node Nnx3
% elem = model.volume.elem; list of elem Nex4 or Nex8 (tetra ou hex)
% Takfarinas MEDANI : Date of creation October 15th
% todo : check the extension of the file and set it to .geo

node = cfg.node;
elem = cfg.elem;
geofilename = cfg.head_filename;

% check the filename :
[filepath,name,ext] = fileparts(geofilename);
if ~strcmp(ext,'.geo')
    ext = '.geo';
end

name = [name '_mesh'];
filename = [name ext];

node_reshaped = [];
disp('Reshape the node')
for ind = 1 : 2 : size(node,1)-1
    node_reshaped = [node_reshaped; node(ind,:)  node(ind+1,:) ];
end

if size(elem,2)<7
    % tetra\
    disp('Tetra elements are  are detected')
    elem = elem(:,1:4);
else
    % hexa
    disp('Hexa elements are  are detected')
    elem = elem(:,1:8);
end

% write the geo file
fid = fopen(filename, 'w');
fprintf(fid, 'BOI - GEOMETRIEFILE\n');
fprintf(fid, '===================================================================\n');
fprintf(fid, '===================================================================\n');
fprintf(fid,'BOI - STEUERKARTE\n');
fprintf(fid,'ANZAHL DER KNOTEN             :%d\n', (length(node)));
fprintf(fid,'ANZAHL DER ELEMENTE           :%d\n',  (length(elem)));
fprintf(fid,'GEOMETR. STRUKTUR - DIMENSION :      3\n');
fprintf(fid,'EOI - STEUERKARTE\n');
fprintf(fid, '===================================================================\n');
fprintf(fid, '===================================================================\n');
fprintf(fid, 'BOI - KOORDINATENKARTE\n')
% reshape the electrodes here to fits the nbNode/2 6
fprintf(fid, '   %1.7f %1.7f %1.7f     %1.7f %1.7f %1.7f \n', node_reshaped');
% add the last node if the number of nod is odd
if mod(size(node,1),2)
    disp('Add the las odd node ')
    fprintf(fid, '   %1.7f %1.7f %1.7f\n', node(end,:));
end
fprintf(fid, 'EOI - KOORDINATENKARTE\n');
fprintf(fid, '===================================================================\n');
fprintf(fid, '===================================================================\n');
fprintf(fid, 'BOI - ELEMENTKNOTENKARTE\n');
fprintf(fid, '  303: %6d%6d%6d%6d\n',    elem' );
fprintf(fid, 'EOI - ELEMENTKNOTENKARTE\n');
fprintf(fid, '===================================================================\n');
fprintf(fid, '===================================================================\n');
fprintf(fid, 'EOI - GEOMETRIEFILE\n');
fclose(fid);
%fclose('all');
end
