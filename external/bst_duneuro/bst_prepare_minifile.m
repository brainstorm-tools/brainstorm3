function cfg = bst_prepare_minifile(cfg)
% cfg = bst_prepare_minifile(cfg)
% set the configration values used by duneuro computation.
% this function will also write the mini file.
% Set mini file parameter /configuration
% put all the paramater in the cfg structure this step could  be modified
% from the bst gui via cfg structure. 
% Takfarinas MEDANI

cfg = bst_set_minifile(cfg);
cfg.mini_filename = [ cfg.filename '_minifile.mini' ];
write_duneuro_minifile(cfg);

end