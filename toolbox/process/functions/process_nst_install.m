function varargout = process_nst_install( varargin )

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Edouard Delaire 2020

eval(macro_method);
end


function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = getComment();
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'NIRS';
    sProcess.Index       =  2000 * isnotdeployed(); % Hide in the deployed versiom   
    sProcess.Description =  'https://github.com/Nirstorm/nirstorm';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    % Definition of the outputs of this process
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 0;
    
    if status()
        sProcess.options.action.Comment = {'Update','Uninstall',' Action:';'install','uninstall',''} ;
    else
        sProcess.options.action.Comment = {'Install','Uninstall',' Action:';'install','uninstall',''} ;
    end
    
    sProcess.options.action.Type    = 'radio_linelabel';
    sProcess.options.action.Value   = 'installation';
    sProcess.options.action.Controller   = struct('install','installation','uninstall','uninstallation' );
    
    sProcess.options.text1.Comment = [ '<b>Download Nirstorm anatomical template:</b> '];    
    sProcess.options.text1.Type='label';

    sProcess.options.option_colin27_2019.Comment = 'Colin27 (2019)' ;
    sProcess.options.option_colin27_2019.Type    = 'checkbox';
    sProcess.options.option_colin27_2019.Value   = 0;
    sProcess.options.option_colin27_2019.Class   = 'installation';
    
    sProcess.options.option_colin27_2019_low.Comment = 'Colin27 - low resolution (2019)' ;
    sProcess.options.option_colin27_2019_low.Type    = 'checkbox';
    sProcess.options.option_colin27_2019_low.Value   = 0;
    sProcess.options.option_colin27_2019_low.Class   = 'installation';
    
    sProcess.options.option_colin27.Comment = 'Colin27 (deprecaded)' ;
    sProcess.options.option_colin27.Type    = 'checkbox';
    sProcess.options.option_colin27.Value   = 0;
    sProcess.options.option_colin27.Class   = 'installation';
        
    sProcess.options.text2.Comment = [ '<b>Install additional features:</b> ', ...
                                        '<p>wip : install work in progress features <br/>',...
                                            'debug: install developping tool <br />', ...
                                            'For more information about the work in progress features, please contact us on our Github page : <a href="https://github.com/Nirstorm/nirstorm">https://github.com/Nirstorm/nirstorm</a></p>'];
    sProcess.options.text2.Type='label';
    
    sProcess.options.option_wip.Comment = 'Work in progress (wip)' ;
    sProcess.options.option_wip.Type    = 'checkbox';
    sProcess.options.option_wip.Value   = 0;
    sProcess.options.option_wip.Class   = 'installation';
    
    sProcess.options.option_debug.Comment = 'Debug (not recommended)' ;
    sProcess.options.option_debug.Type    = 'checkbox';
    sProcess.options.option_debug.Value   = 0;
    sProcess.options.option_debug.Class   = 'installation';
    
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

function status = isnotdeployed() 
    status = ~(exist('isdeployed', 'builtin') && isdeployed);
end

function comment=getComment()
    if status()
        comment='Update NIRSTORM';
    else
        comment='Install NIRSTORM';
    end     
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles={};
    switch( sProcess.options.action.Value)
        case 'install'
            extra={};
            if sProcess.options.option_debug.Value
                extra{end+1}='debug';
            end
            if sProcess.options.option_wip.Value
                extra{end+1}='wip';
            end
            template = [sProcess.options.option_colin27_2019.Value , ... 
                        sProcess.options.option_colin27_2019_low.Value, ... 
                        sProcess.options.option_colin27.Value];
                    
            errMsg = install(extra,template,1,1);
            
            if ~isempty(errMsg)
                 bst_report('Error',   sProcess, sInputs, errMsg)
            else
                bst_report('Info', sProcess, sInputs, 'NIRSTORM was installed successfully');
            end                
        case 'uninstall'
            if ~status()
                bst_report('Error',   sProcess, sInputs, 'NIRSTORM software is not installed on your computer.')
                return;
            end    
            uninstall();
            bst_report('Info',  sProcess, sInputs, 'NIRSTORM was installed successfully');
    end    
end

function status=status()
    % process_nst_install('status')
    % return if nirstorm is installed
    status =  exist('uninstall_nirstorm')==2 && strcmp(fileparts(which('uninstall_nirstorm')),bst_get('UserProcessDir')); 
end  

function errMsg = install(extra,template,isInteractive,fromProcess)
    % process_nst_install('install',extra,isInteractive)
    % 'install': download and install nirstorm
    % INPUTS:
    %    - extra: cell array, list of extra features to install from nirstorm ('debug', 'wip')
    %       - 'debug': install developping tool
    %       - 'wip': install work in progress features
    %    - isInteractive: bool. 1 if the script is called interactively 
    if (nargin < 4)
        fromProcess = 0;
    end    
    if (nargin < 3)
        isInteractive = 0;
    end    
    if (nargin < 2 || isempty(template))
        template = [ 0 0 0];
    end 
    
    if (nargin < 1)
        extra = {};
    end    
    
    if  isempty(extra) && isInteractive && ~fromProcess
        isOk = java_dialog('confirm','Would you like to download work in progress features?', 'NIRSTORM installation');
        if isOk
            extra={'wip'};
        end    
    end
    
    mode = 'copy'; 
    tmp_folder = bst_get('BrainstormTmpDir');
    tmp_file   = fullfile(tmp_folder,'nirstorm.zip');
    nistorm_folder = fullfile(tmp_folder,'nirstorm-master');
    
    nistorm_url = 'https://github.com/Nirstorm/nirstorm/archive/master.zip';
    
    errMsg = gui_brainstorm('DownloadFile',nistorm_url, tmp_file, 'Download NIRSTORM');
    if ~isempty(errMsg)
        errMsg = ['Impossible to download NIRSTORM: ' 10 errMsg];
        return;
    end    
    
    bst_progress('start', 'NIRSTORM', 'Installing NIRSTORM...');
    
    % Unzip nirstorm
    try 
        unzip(tmp_file,tmp_folder);
    catch
        errMsg = 'Unable to unzip nirstorm';
        delete(tmp_file);
        return;
    end
    
    % Install nistorm
    addpath(nistorm_folder);

    try 
        nst_install(mode,extra,nistorm_folder);
    catch ME
        errMsg = 'Unable to install nirstorm';
        return;
    end
    
    % Remove temporary files
    if strcmp(mode,'copy')
        rmpath(nistorm_folder)
        rmpath(fullfile(nistorm_folder, 'dist_tools'));
        
        delete(tmp_file);
        [status,errMsg] = rmdir(nistorm_folder, 's');
    end
    
    
    
    if any(template)
        bst_progress('start', 'NIRSTORM', 'Downloading templates...', 0, sum(template));
        template_names = {'Colin27_4NIRS_Jan19', ...
                          'Colin27_4NIRS_lowres', ... 
                            'Colin27_4NIRS'};
                        
        for i_template = 1:length(template_names)
            if ~template(i_template)
                continue;
            end    
            
            template_bfn = [template_names{i_template} '.zip'];
            template_tmp_fn = nst_request_files({{'template', template_bfn}}, 0, ...
                                        nst_get_repository_url(), 18e6);
                                    
                                    
            % Copy to .brainstorm/defaults/anatomy
            copyfile(template_tmp_fn{1}, fullfile(bst_get('BrainstormUserDir'), 'defaults', 'anatomy'));
            % Remove temporary file
            delete(template_tmp_fn{1});
            
            bst_progress('inc', 1);
        end   
        bst_progress('stop');
    end    
    
    
    
    
end

function uninstall()
    % process_nst_install('uninstall')
    % 'uninstall': uninstall nirstorm   
    bst_progress('start', 'NIRSTORM', 'Uninstalling NIRSTORM...');
    
    cur_dir=pwd;
    cd(bst_get('UserProcessDir'));
    uninstall_nirstorm();
    delete( which('uninstall_nirstorm'));
    cd(cur_dir);
    
    bst_progress('stop');

end

function template_names = nst_core_get_available_templates()
%TODO: add descriptions
template_names = {'Colin27_4NIRS', ...
                  'Colin27_4NIRS_lowres', ...
                  'Colin27_4NIRS_Jan19'};
end

