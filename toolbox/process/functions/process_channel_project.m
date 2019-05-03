function varargout = process_channel_project( varargin )
% PROCESS_CHANNEL_PROJECT: Project electrodes on the scalp surface.

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
% Authors: Francois Tadel, 2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Project electrodes on scalp';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 42;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy?highlight=(Project electrodes+on+scalp+surface)#Register_electrodes_with_MRI';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', [sInputs.iStudy]);
    iChanStudies = unique(iChanStudies);
    % Loop on the channel studies
    for iFile = 1:length(iChanStudies)
        % Get channel study
        sStudy = bst_get('Study', iChanStudies(iFile));
        if isempty(sStudy.Channel)
            bst_report('Error', sProcess, [], 'No channel file available.');
            return
        end
        % Read channel file
        ChannelFile = sStudy.Channel(1).FileName;
        ChannelMat = in_bst_channel(ChannelFile);
        % Get EEG channels to project
        iChanToProject = [];
        for iChan = 1:length(ChannelMat.Channel)
            if strcmpi(ChannelMat.Channel(iChan).Type, 'EEG') && ~isempty(ChannelMat.Channel(iChan).Loc) && ~all(ChannelMat.Channel(iChan).Loc(:) == 0)
                iChanToProject(end+1) = iChan;
            end
        end
        if isempty(iChanToProject)
            bst_report('Error', sProcess, [], 'No EEG electrodes to project.');
            return
        end
        % Get subject 
        [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
        if isempty(sSubject) || isempty(sSubject.iScalp) || (sSubject.iScalp > length(sSubject.Surface))
            bst_report('Error', sProcess, [], 'No scalp surface available.');
            return
        end
        % Read scalp surface
        HeadFile = sSubject.Surface(sSubject.iScalp).FileName;
        TessMat = in_tess_bst(HeadFile);
        % Project electrodes positions
        ChanLoc = [ChannelMat.Channel(iChanToProject).Loc]';
        ChanLoc = channel_project_scalp(TessMat.Vertices, ChanLoc);
        % Report projections in original structure
        for iChan = 1:length(iChanToProject)
            ChannelMat.Channel(iChanToProject(iChan)).Loc = ChanLoc(iChan,:)';
        end
        % Save modifications in channel file
        bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end



