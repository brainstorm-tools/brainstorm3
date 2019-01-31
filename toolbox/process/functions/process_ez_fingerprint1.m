function varargout = process_ez_fingerprint1( varargin )
% process_ez_fingerprint1: open EZ Fingerprint or prompt to download
% Copyright 2018 - 2019 University of Southern California
% License: General Public License, version 3 (GPLv3)
% For more information see: https://silencer1127.github.io/software/EZ_Fingerprint/ezf_main
% For support contact jli981@usc.edu

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Author: Jian Li (Andrew), 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'EZ Fingerprint';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Epilepsy';
    sProcess.Index       = 1800;
    sProcess.isSeparator = 0;
    sProcess.Description = 'https://silencer1127.github.io/software/EZ_Fingerprint/ezf_main';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix', 'import'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    
    % Definition of the options
    %sProcess.options.desc.Type = 'label';
    %sProcess.options.desc.Comment = ezf_getProcessDescription();
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    
    OutputFiles = {};
    
    f = ezf_checkMaltabVersion();
    [isEZFInstalled, ezfAppInfo] = ezf_checkEZFInstallation();
    
    if isEZFInstalled
        ezf = fullfile(ezfAppInfo.location, 'code', 'EZFingerprint.m');
        run(ezf);
    else
        if f == -1
            web('https://silencer1127.github.io/software/EZ_Fingerprint/ezf_install', '-browser');
        else
            web('https://silencer1127.github.io/software/EZ_Fingerprint/ezf_main', '-browser');
        end
    end
    
end
