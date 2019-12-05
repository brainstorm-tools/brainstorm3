function cfg = bst_prepare_conductivity_model(cfg)
% cfg = bst_prepare_conductivity_model(cfg);
% write the conductivity file either for isotrpic modelor anisotrpic

% Author : Takfarinas MEDANI, October 2019,

% Check if it's isotropic or anisotrpic model
if ~isfield(cfg,'isotropic'); cfg.isotropic = 0; end
% Check if use the tensor (even for isotropic we can use tensor ==> more complicated but needed for validation)
if ~isfield(cfg,'useTensor'); cfg.useTensor = 0; end

%% Isotrpic case without tensor.
if (cfg.isotrop == 1)  % isotropic
    if (cfg.useTensor == 0)
        cfg.cond_filename = 'conductivity_model.con';
        if isfield(cfg,'conductivity')
            write_duneuro_conductivity_file(cfg.conductivity,cfg.cond_filename)
        else
            error('The field cfg.conductivity is not specified')
        end
    else  % Isotropi with tensor  cfg.useTensor ==1
        % will use the cauchy file
        cfg.cond_filename = 'conductivity_model.knw';
        if isfield(cfg,'conductivity_tensor') && isfield(cfg,'elem')
            bst_write_cauchy_tensor_conductivity(cfg.elem,cfg.conductivity_tensor,cfg.cond_filename)
        else
            error('The field cfg.conductivity_tensor and/or cfg.elem are not specified')
        end
    end
else  % anisotropic
    % will use the cauchy file
    cfg.cond_filename = 'conductivity_model.knw';
    % and for sure, we wil use tensor, then impose it to 1
    cfg.useTensor = 1;
    % write the cauchy conductivity file
    if isfield(cfg,'conductivity_tensor') && isfield(cfg,'elem')
        bst_write_cauchy_tensor_conductivity(cfg.elem,cfg.conductivity_tensor,cfg.cond_filename)
    else
        error('The field cfg.conductivity_tensor and/or cfg.elem are not specified')
    end
end
end
