function cfg = bst_prepare_head_model(cfg)
% cfg = bst_prepare_head_model(cfg) write the head model file to the disc
% the format can be either msh or geo according to the simulation isotrop or anisotrop.
% File created by Takfarinas MEDANI, November 2019;

if ~isfield(cfg,'filename'); cfg.filename = 'head_model'; end  % Use the default name.
if ~isfield(cfg,'useTensor'); cfg.useTensor = 0; end  % Use the tensor model or not
if ~isfield(cfg,'isotrop'); cfg.isotrop = 1; end  % Use the tensor model or not

if cfg.isotrop == 1
    if cfg.useTensor == 0
        % Duneuro uses the msh file
        cfg.head_filename = [cfg.filename '.msh'];
        cfg.saveMshFormat = 1;
        bst_write_mesh_model(cfg);
    else % case cfg.useTensor =1
        % Duneuro uses the Cauchy files
        cfg.head_filename = [cfg.filename '.geo'];
        cfg.saveCauFormat = 1;
        bst_write_cauchy_geometry(cfg);
    end
end

if ~isfield(cfg,'savefile'); cfg.savefile = 1; end 
if ~isfield(cfg,'saveBstFormat'); cfg.saveBstFormat = 0; end 
if cfg.saveBstFormat == 1
    % write to the bst head model
    femhead = bst_mesh_mat2bst(cfg);
end
end