function cfg = bst_run_duneuro_cmd(cfg)
% cfg = bst_run_duneuro_cmd(cfg)
% set the arguments and run the duneuro computation.
% Author , Takfarinas MEDANI, December 2019,


arg1 = cfg.mini_filename; % the configuration file.

if ~isfield(cfg,'BstDuneuroVersion');  cfg.BstDuneuroVersion = 1; end % or 2 for the new version of Juan

if cfg.BstDuneuroVersion == 2
    arg2 = [' '  '--' cfg.modality];
    % add here other modalities
end

%% run the command
% To avoid the display on the terminal : use : evalc('[status,cmdout] = system([cfg.cmd '.exe' ' '  arg1]);;')
% version 1
if cfg.BstDuneuroVersion == 1
    if ispc
        [status,cmdout] = system([cfg.cmd '.exe' ' '  arg1]);
    elseif isunix
        [status,cmdout] = system(['./' cfg.cmd ' '  arg1]);
    elseif ismac
        [status,cmdout] = system(['./' cfg.cmd ' '  arg1]);
    end
end
% version 2
if cfg.BstDuneuroVersion == 2
    if ispc
        [status,cmdout] = system([cfg.cmd '.exe' ' '  arg1 arg2]);
    elseif isunix
        [status,cmdout] = system(['./' cfg.cmd ' '  arg1 arg2]);
    elseif ismac
        [status,cmdout] = system(['./' cfg.cmd ' '  arg1 arg2]);
    end
end

%% Check status
if status ~= 0
    duneuro_logfile = 'duneuro_log.txt';
    fid = fopen(duneuro_logfile , 'w');
    fprintf(fid, '%st', cmdout);
    fclose(fid);
    error('Something was wrong during duneuro computation, please check %s', duneuro_logfile);
end

end
