function bst_write_mesh_model(cfg)
% Save the mesh on the format specified on the cfg
% cfg.saveMshFormat : MSH format
% cfg.gmshView : Open a View with GMSH
% cfg.node  : list of node
% cfg.elem : list of elem
% cfg.filename : output filename
% cfg.saveBstFormat : brainstorm format
% cfg.TissueLabels : cell string containing the name of the tissus
% cfg.saveMatFormat : matlab format
% cfg.saveCauFormat : cauchy format
% File created on November 21st, 2019.

% Takfarinas MEDANI
% TODO : Add checking of the input argument
%             : optimize the condition,
if ~isfield(cfg,'gmshView'); cfg.gmshView = 0; end
%% Saving the mesh
% Msh format
if isfield(cfg,'saveMshFormat')
    if cfg.saveMshFormat == 1
        disp('Saving the mesh to MSH  format ...')
%         cfg0.node = cfg.node;
%         cfg0.elem = cfg.elem;
%         cfg0.filename = cfg.filename;
%         bst_mesh_mat2msh(cfg0)
        bst_write_msh_file(cfg.node,cfg.elem,cfg.head_filename)
        clear cfg0
        if isfield(cfg,'gmshView')
            if cfg.gmshView == 1
                system(['gmsh ' cfg.filename '.msh']);
            end
        end
    end
end

% Bst matlab format
if isfield(cfg,'saveBstFormat')
    if cfg.saveBstFormat == 1
        disp('Saving the mesh to BST matlab format ...')
        cfg0=[];
        cfg0.savefile =1;
        cfg0.node =  cfg.node;
        cfg0.elem = cfg.elem;
        cfg0.TissueLabels = cfg.tissu;
        cfg0.filename = cfg.filename;
        bst_mesh_mat2bst(cfg0);
        clear cfg0
        disp('Saving the mesh to BST matlab format ... done')
    end
end
% Mat format
if isfield(cfg,'saveMatFormat')
    if cfg.saveMatFormat == 1
        disp('Saving the mesh to matlab format ...')
        TissueLabels = cfg.TissueLabels;
        node = cfg.node;
        elem = cfg.elem;
        save(cfg.filename,'node','elem','TissueLabels','cfg');
        disp('Saving the mesh to matlab format ... done')
    end
end
% Cauchy format
if  isfield(cfg,'saveCauFormat')
    if  cfg.saveCauFormat == 1
        disp('Saving the mesh to Cauchy format ...')
        bst_write_cauchy_geometry(cfg.node,cfg.elem(:,1:4),cfg.filename)
        disp('Saving the mesh to Cauchy format ... done')
    end
end

end