function [status,err] = nst_setup(action, extra,isInteractive)
% INSTALL_NIRSTORM Download and install NIRSTORM in Brainstorm
% 
% INPUTS: 
%    - action : str 
%        - 'status': return if nirstorm is installed
%        - 'install': download and install nirstorm
%        - 'uninstall': uninstall nirstorm         
%    - extra: cell array, list of extra features to install from nirstorm ('debug', 'wip')
%       - 'debug': install developping tool
%       - 'wip': install work in progress features
%    - isInteractive: bool. 1 if the script is called interactively 
%
% Authors: Edouard Delaire, 2020

err = {};
status = 1;

if nargin < 3
    isInteractive = 0;
end    

if strcmp(action, 'status')
    status =  exist('uninstall_nirstorm')==2 && strcmp(fileparts(which('uninstall_nirstorm')),bst_get('UserProcessDir'));
elseif  strcmp(action, 'install')   
    if (nargin < 2) || isempty(extra)
        extra = {}; 
        if isInteractive
            isOk = java_dialog('confirm','Would you like to download work in progress features?', 'NIRSTORM installation');
            if isOk
                extra={'wip'};
            end    
        end   
    end
    
    mode = 'copy'; 
    tmp_folder = bst_get('BrainstormTmpDir');
    tmp_file   = fullfile(tmp_folder,'nirstorm.zip');
    nistorm_folder = fullfile(tmp_folder,'nirstorm-master');
    
    nistorm_url = 'https://github.com/Nirstorm/nirstorm/archive/master.zip';
    
    err = gui_brainstorm('DownloadFile',nistorm_url, tmp_file, 'Download NIRSTORM');
    if ~isempty(err)
        status=0;
        if isInteractive 
            java_dialog('error', sprintf('Nirstorm installation failed :\n%s', err), 'NIRSTORM installation');
        end
        return;
    end   
        
    % Unzip nirstorm
    try 
        unzip(tmp_file,tmp_folder);
    catch
        err = 'Unable to unzip nirstorm'; status=0;
        if isInteractive 
            java_dialog('error', sprintf('Nirstorm installation failed :\n%s', err), 'NIRSTORM installation');
        end
        delete(tmp_file);
        return;
    end
    
    % Install nistorm
    addpath(nistorm_folder);

    try 
        nst_install(mode,extra,nistorm_folder);
    catch ME
        err = ME.message; status=0;
        if isInteractive
            java_dialog('error', sprintf('Nirstorm installation failed :\n%s', err), 'NIRSTORM installation');
        end
        return;
    end
    
    % Remove temporary files
    if strcmp(mode,'copy')
        rmpath(nistorm_folder)
        rmpath(fullfile(nistorm_folder, 'dist_tools'));
        
        delete(tmp_file);
        [status,err] = rmdir(nistorm_folder, 's');
         if ~status && isInteractive
            java_dialog('error', sprintf('Nirstorm installation failed :\n%s', err), 'NIRSTORM installation');
            return;
         end
    end
    
    err='NIRSTORM was installed successfully';
    if isInteractive
        java_dialog('msgbox', err, 'NIRSTORM installation ');
    end    

elseif  strcmp(action, 'uninstall')   
    cur_dir=pwd;
    cd(bst_get('UserProcessDir'));
    uninstall_nirstorm();
    delete( which('uninstall_nirstorm'));
    cd(cur_dir);
    
    if isInteractive
        java_dialog('msgbox', 'NIRSTORM was uninstalled successfully.', 'NIRSTORM installation ');
    end    
end    
end


