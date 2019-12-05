function cfg = bst_read_duneuro_leadfield(cfg)
% cfg = bst_read_duneur_leadfield(cfg)
% read the duneuro output
% Author :Takfarinas MEDANI, December, 2019.



if cfg.BstDuneuroVersion == 1
    if ~isfield(cfg,'readDuneuroText'); cfg.readDuneuroTextMatrix = 1; end
    if ~isfield(cfg,'readDuneuroBinary'); cfg.readDuneuroBinary = 0; end
    
    if cfg.readDuneuroTextMatrix == 1 % read the leadfield from the text file
        if cfg.useTransferMatrix == 1
            lf_fem = load('Vfem-transfert.txt');
            lf_fem = lf_fem';
            cfg.lf_fem = lf_fem;
        else % not recommended, too long, just for testing the validity of the transfer computation (maybe used for seeg, ecog)
            lf_fem = load('Vfem-direct.txt');
            lf_fem = lf_fem';
            cfg.lf_fem = lf_fem;
        end
    else % read the leadfield from the binary file
        %% Todo
        lf_fem = load('Vfem-transfert.dat');
        lf_fem = lf_fem';
        cfg.lf_fem = lf_fem;
    end
end

if cfg.BstDuneuroVersion == 2
    cfg = bst_read_binary_leadfield_matrix(cfg);
end

clear lf_fem
end