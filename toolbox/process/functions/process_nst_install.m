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
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'NIRS';
    if ~(exist('isdeployed', 'builtin') && isdeployed)
        sProcess.Index       =  2000;
    else % Hide in the deployed versiom
        sProcess.Index       =  0;
    end    
    sProcess.Description =  'https://github.com/Nirstorm/nirstorm';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    % Definition of the outputs of this process
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 0;
    
    if status()
        sProcess.Comment     = 'Update NIRSTORM';
        sProcess.options.action.Comment = {'Update','Uninstall',' Action:';'install','uninstall',''} ;
    else
        sProcess.Comment     = 'Install NIRSTORM';
        sProcess.options.action.Comment = {'Install',' Action:';'install',''} ;
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
    
    sProcess.options.option_colin27.Comment = 'Colin27 (2016)' ;
    sProcess.options.option_colin27.Type    = 'checkbox';
    sProcess.options.option_colin27.Value   = 0;
    sProcess.options.option_colin27.Class   = 'installation';
        
    sProcess.options.text2.Comment = [ '<b>Install additional features:</b> ', ...
                                        '<p>wip : install work in progress features <br/>',...
                                            'For more information about the work in progress features, please contact us on our Github page : <a href="https://github.com/Nirstorm/nirstorm">https://github.com/Nirstorm/nirstorm</a></p>'];
    sProcess.options.text2.Type='label';
    
    sProcess.options.option_wip.Comment = 'Work in progress (wip)' ;
    sProcess.options.option_wip.Type    = 'checkbox';
    sProcess.options.option_wip.Value   = 0;
    sProcess.options.option_wip.Class   = 'installation';
    
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles={};
    switch( sProcess.options.action.Value)
        case 'install'
            extra={};
            if sProcess.options.option_wip.Value
                extra{1}='wip';
            end

            templates = [sProcess.options.option_colin27_2019.Value , ... 
                        sProcess.options.option_colin27_2019_low.Value, ... 
                        sProcess.options.option_colin27.Value];
                    
            [errMsg,updateMsg] = install(extra,templates,0);
            
            if ~isempty(errMsg)
                 bst_report('Error',   sProcess, sInputs, errMsg)
            else
                bst_report('Info', sProcess, sInputs, 'NIRSTORM was installed successfully');
                bst_report('Info', sProcess, sInputs,  updateMsg);
                bst_report('Open', 'current');
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
    status =  exist('process_nst_mbll')==2 && strcmp(fileparts(which('process_nst_mbll')),bst_get('UserProcessDir')); 
end  

function [errMsg,updateMsg] = install(extra,template,isInteractive)
    % process_nst_install('install',extra,isInteractive)
    % 'install': download and install nirstorm
    % INPUTS:
    %    - extra: cell array, list of extra features to install from nirstorm ('debug', 'wip')
    %       - 'debug': install developping tool
    %       - 'wip': install work in progress features
    %   - template: list of template to download. template(k)=1 to download
    %   template number k. 
    %   1: Colin27 (2019), 2:Colin27 low resolution(2019),3: Colin27 (2016)
    %    - isInteractive: bool. 1 if the script is called interactively 
  
    if (nargin < 3)
        isInteractive = 0;
    end    
    if (nargin < 2 || isempty(template))
        if isInteractive 
            % In the interactive version, propose to download Colin27(2019)
            %and Colin27(2019) low resolution
            template = [ 1 1 0]; 
        else 
            template = [ 0 0 0];
        end   
    end 
    
    if (nargin < 1)
        extra = {};
    end    
    
    if  isempty(extra) && isInteractive
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
        file_delete(tmp_file, 1);
        return;
    end
    
    % Install nistorm
    addpath(nistorm_folder);
    try 
        nst_install(mode,extra);
    catch ME
        errMsg = ['Unable to install nirstorm: ' ME.message];
        return;
    end
    updateMsg = fileread(fullfile(nistorm_folder,'updates.txt'));
        
    % Remove temporary files
    if strcmp(mode,'copy')
        rmpath(nistorm_folder)        
        file_delete(tmp_file, 1);
        file_delete(nistorm_folder, 1, 3);
    end
    
    % install nirstorm templates
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
            template_tmp_fn = nst_request_files({{'template', template_bfn}}, ...
                                        isInteractive, ...
                                        nst_get_repository_url(), 18e6);
                                    
                                    
            % Copy to .brainstorm/defaults/anatomy
            file_copy(template_tmp_fn{1}, fullfile(bst_get('BrainstormUserDir'), 'defaults', 'anatomy'));
            % Remove temporary file
            file_delete(template_tmp_fn{1}, 1);            
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
    
    if exist('uninstall_nirstorm')  && strcmp(fileparts(which('uninstall_nirstorm')),bst_get('UserProcessDir'))
        uninstall_nirstorm();
        file_delete(fullfile(bst_get('UserProcessDir'),'uninstall_nirstorm.m'),1)

        % delete nirstorm functions
        function_folder=fullfile(bst_get('BrainstormUserDir'), 'nirstorm');
        if exist(function_folder,'dir')
            rmpath(function_folder)
            file_delete(function_folder, 1,3);
        end    

        % delete nirstorm mex
         mex_folder= bst_get('UserMexDir');
         mex_files = {'dg_voronoi.mexa64','dg_voronoi.mexglx'};
         for i_mex = 1:length(mex_files)
                if exist( fullfile(mex_folder,mex_files{i_mex})  ,'file')
                    file_delete(fullfile(mex_folder,mex_files{i_mex}),1,3);
                end
         end     
    end
    cd(cur_dir);
    bst_progress('stop');
end
