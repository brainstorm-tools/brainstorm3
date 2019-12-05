function bst_write_msh_file(newnode,newelem,fname)

% improved version of fc_ecriture_fichier_msh2.m
%http://www.ensta-paristech.fr/~kielbasi/docs/gmsh.pdf

% last update 05/12/2019
% faster without for loops and duplicate matrix (less memory)
% Takfarinas Medani, created December, 2015,


[filepath,name,ext] = fileparts(fname);
if isempty(ext) || ~strcmp(ext,'.msh')
    ext = '.msh';
end

fname = [ name ext];
% nnode = [(1:length(cfg.node))' cfg.node];
% nelem = [(1:length(cfg.elem))' cfg.elem];
% ouvre ou crée un fichier
fid = fopen(fname,'wt');

%% Informations du format du fichier de maillage
fprintf(fid,'%s\r\n','$MeshFormat');
fprintf(fid,'%s\r\n','2.2 0 8');
fprintf(fid,'%s\r\n','$EndMeshFormat ');
%% bloc des noeuds
fprintf(fid,'%s\r\n','$Nodes ');
fprintf(fid,'%i \r\n',length(newnode));
fprintf(fid,'%i  %i  %i  %i \r\n',[(1:length(newnode))',newnode(:,1),newnode(:,2),newnode(:,3)]');
fprintf(fid,'%s\r\n','$EndNodes');

%% bloc des elemnts
elm_type_tetra=4;
fprintf(fid,'\r\n');
fprintf(fid,'%s\r\n','$Elements');
fprintf(fid,'%i \r\n',length(newelem));
fprintf(fid,'%i %i %i  %i  %i  %i %i  %i %i \r\n',[(1:length(newelem))',elm_type_tetra*ones(length(newelem),1),...
                                                                                2*ones(length(newelem),1),newelem(:,5)-1,0*ones(length(newelem),1),...
                                                                                    newelem(:,1),newelem(:,2),newelem(:,3),newelem(:,4)]'); % modification of TIM
fprintf(fid,'%s\r\n','$EndElements');

moreData = 0 ;
if moreData
    %% bloc physical Names
    fprintf(fid,'%s\r\n','$PhysicalNames');
    fprintf(fid,'%i \r\n',length(unique(newelem(:,6))));
    fprintf(fid,'%i %i %s\r\n','1 1 toto1');
    fprintf(fid,'%i %i %s\r\n','2 2 toto2');
    fprintf(fid,'%i %i %s\r\n','3 3 toto3');
    fprintf(fid,'%i %i %s\r\n','4 4 toto4');
    fprintf(fid,'%s\r\n','$EndPhysicalNames');
    
    %% $NodeData
    % http://geuz.org/gmsh/doc/texinfo/gmsh.html#SEC62
    fprintf(fid,'%s\r\n','$NodeData');
    fprintf(fid,'%i \r\n',1); % one string tag:
    fprintf(fid,'%s\r\n','"A scalar view"');
    fprintf(fid,'%i\r\n',1); %one real tag:
    fprintf(fid,'%i\r\n',0.0); %the time value (0.0)
    fprintf(fid,'%i\r\n',3); % three integer tags:
    fprintf(fid,'%i\r\n',0); %the time step (0; time steps always start at 0)
    fprintf(fid,'%i\r\n',1); % 1-component (scalar) field
    fprintf(fid,'%i\r\n',length(newnode)); % nb associated nodal values
    fprintf(fid,'%i %i \r\n',[nn,Vn']');
    fprintf(fid,'%s\r\n','$End$NodeData');
end
fclose(fid);
end


