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
    nistorm_folder = fullfile(tmp_folder,'nirstorm-master');

    nistorm_url = 'https://github.com/Nirstorm/nirstorm/archive/master.zip';
    
    % Download nirstorm
    try 
        unzip(nistorm_url,tmp_folder);
    catch
        err = 'Unable to download nirstorm'; status=0;
        java_dialog('error', sprintf('Nirstorm installation failed :\n%s', err), 'NIRSTORM installation');
        return;
    end
    
    % Install nistorm
    addpath(nistorm_folder);
    try 
        nst_install(mode,extra,nistorm_folder);
    catch ME
        err = ME.message; status=0;
        java_dialog('error', sprintf('Nirstorm installation failed :\n%s', err), 'NIRSTORM installation');
        return;
    end
    
    % Remove temporary files
    if strcmp(mode,'copy')
        rmpath(nistorm_folder)
        rmpath(fullfile(nistorm_folder, 'dist_tools'));
    
        [status,err] = rmdir(nistorm_folder, 's');
        if ~status
            java_dialog('error', sprintf('Nirstorm installation failed :\n%s', err), 'NIRSTORM installation');
            return;
        end
    end
    java_dialog('msgbox', 'NIRSTORM was installed successfully ', 'NIRSTORM installation ');

elseif  strcmp(action, 'uninstall')   
    cur_dir=pwd;
    cd(bst_get('UserProcessDir'));
    uninstall_nirstorm();
    delete( which('uninstall_nirstorm'));
    cd(cur_dir);
    

    java_dialog('msgbox', 'NIRSTORM was uninstalled successfully.', 'NIRSTORM installation ');
end    
end


