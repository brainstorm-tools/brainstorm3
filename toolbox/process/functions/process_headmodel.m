function varargout = process_headmodel( varargin )
% PROCESS_HEADMODEL: Compute a head model.

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
% Authors: Francois Tadel, 2012-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Compute head model';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 320;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadModel';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Comment
    sProcess.options.Comment.Comment = 'Comment: ';
    sProcess.options.Comment.Type    = 'text';
    sProcess.options.Comment.Value   = '';
    % Options: Source space
    sProcess.options.label1.Comment = '<BR><B>Source space</B>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.sourcespace.Comment = {'Cortex surface', 'MRI volume', 'Custom source model'};
    sProcess.options.sourcespace.Type    = 'radio';
    sProcess.options.sourcespace.Value   = 1;
    % Options: Volume source model Options
    sProcess.options.volumegrid.Comment = {'panel_sourcegrid', 'MRI volume grid: '};
    sProcess.options.volumegrid.Type    = 'editpref';
    sProcess.options.volumegrid.Value   = [];
    % Option: MEG headmodel
    sProcess.options.label2.Comment = '<BR><B>Forward modeling methods</B>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.meg.Comment = '   - MEG method:';
    sProcess.options.meg.Type    = 'combobox';
    sProcess.options.meg.Value   = {3, {'<none>', 'Single sphere', 'Overlapping spheres', 'OpenMEEG BEM', 'DUNEuro FEM'}};
    % Option: EEG headmodel
    sProcess.options.eeg.Comment = '   - EEG method:';
    sProcess.options.eeg.Type    = 'combobox';
    sProcess.options.eeg.Value   = {3, {'<none>', '3-shell sphere', 'OpenMEEG BEM', 'DUNEuro FEM'}};
    % Option: ECOG headmodel
    sProcess.options.ecog.Comment = '   - ECOG method:';
    sProcess.options.ecog.Type    = 'combobox';
    sProcess.options.ecog.Value   = {2, {'<none>', 'OpenMEEG BEM'}};
    % Option: SEEG headmodel
    sProcess.options.seeg.Comment = '   - SEEG method:';
    sProcess.options.seeg.Type    = 'combobox';
    sProcess.options.seeg.Value   = {2, {'<none>', 'OpenMEEG BEM'}};
    % Options: OpenMEEG Options
    sProcess.options.openmeeg.Comment = {'panel_openmeeg', 'OpenMEEG options: '};
    sProcess.options.openmeeg.Type    = 'editpref';
    sProcess.options.openmeeg.Value   = bst_get('OpenMEEGOptions');
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    isOpenMEEG = 0;
    isDuneuro = 0;
    % == MEG options ==
    if isfield(sProcess.options, 'meg') && isfield(sProcess.options.meg, 'Value') && iscell(sProcess.options.meg.Value)
        switch (sProcess.options.meg.Value{1})
            case 1,  sMethod.MEGMethod = '';
            case 2,  sMethod.MEGMethod = 'meg_sphere';
            case 3,  sMethod.MEGMethod = 'os_meg';
            case 4,  sMethod.MEGMethod = 'openmeeg';  isOpenMEEG = 1;
            case 5,  sMethod.MEGMethod = 'duneuro';   isDuneuro = 1;
        end
    else
        sMethod.MEGMethod = '';
    end
    % == EEG options ==
    if isfield(sProcess.options, 'eeg') && isfield(sProcess.options.eeg, 'Value') && iscell(sProcess.options.eeg.Value)
        switch (sProcess.options.eeg.Value{1})
            case 1,  sMethod.EEGMethod = '';
            case 2,  sMethod.EEGMethod = 'eeg_3sphereberg';
            case 3,  sMethod.EEGMethod = 'openmeeg';   isOpenMEEG = 1;
            case 4,  sMethod.MEGMethod = 'duneuro';    isDuneuro = 1;
        end
    else
        sMethod.EEGMethod = '';
    end
    % == ECOG options ==
    if isfield(sProcess.options, 'ecog') && isfield(sProcess.options.ecog, 'Value') && iscell(sProcess.options.ecog.Value)
        switch (sProcess.options.ecog.Value{1})
            case 1,  sMethod.ECOGMethod = '';
            case 2,  sMethod.ECOGMethod = 'openmeeg';   isOpenMEEG = 1;
        end
    else
        sMethod.ECOGMethod = '';
    end
    % == SEEG options ==
    if isfield(sProcess.options, 'seeg') && isfield(sProcess.options.seeg, 'Value') && iscell(sProcess.options.seeg.Value)
        switch (sProcess.options.seeg.Value{1})
            case 1,  sMethod.SEEGMethod = '';
            case 2,  sMethod.SEEGMethod = 'openmeeg';   isOpenMEEG = 1;
        end
    else
        sMethod.SEEGMethod = '';
    end
    % Source space options
    switch (sProcess.options.sourcespace.Value)
        case 1,  sMethod.HeadModelType = 'surface';
        case 2,  sMethod.HeadModelType = 'volume';
        case 3,  sMethod.HeadModelType = 'mixed';
    end
    % Comment
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        sMethod.Comment = sProcess.options.Comment.Value;
    end
    % Set the source space (grid of source points, and constrained orientation at those source points)
    if isfield(sProcess.options, 'gridloc') && isfield(sProcess.options.gridloc, 'Value') && ~isempty(sProcess.options.gridloc.Value)
        sMethod.GridLoc = sProcess.options.gridloc.Value;
    end
    if isfield(sProcess.options, 'gridorient') && isfield(sProcess.options.gridorient, 'Value') && ~isempty(sProcess.options.gridorient.Value)
        sMethod.GridOrient = sProcess.options.gridorient.Value;
    end
    if isfield(sProcess.options, 'volumegrid') && isfield(sProcess.options.volumegrid, 'Value') && ~isempty(sProcess.options.volumegrid.Value)
        sMethod.GridOptions = sProcess.options.volumegrid.Value;
    else
        sMethod.GridOptions = bst_get('GridOptions_headmodel');
    end

    % Get channel studies
    [sChannels, iChanStudies] = bst_get('ChannelForStudy', unique([sInputs.iStudy]));
    % Check if there are channel files everywhere
    if (length(sChannels) ~= length(iChanStudies))
        bst_report('Error', sProcess, sInputs, ['Some of the input files are not associated with a channel file.' 10 'Please import the channel files first.']);
        return;
    end
    % Keep only once each channel file
    iChanStudies = unique(iChanStudies);
    
    % Copy OpenMEEG options to OPTIONS structure
    if isOpenMEEG
        if ~isempty(sProcess.options.openmeeg.Value)
            sMethod = struct_copy_fields(sMethod, sProcess.options.openmeeg.Value, 1);
            bst_set('OpenMEEGOptions', sProcess.options.openmeeg.Value);
        else
            bst_report('Error', sProcess, [], 'OpenMEEG options are not defined.');
            return;
        end
    end
    % Copy DUNEuro options to OPTIONS structure
    if isDuneuro
        warning('todo');
    end
    % Non-interactive process
    sMethod.Interactive = 0;
    sMethod.SaveFile = 1;
    % Call head modeler
    [HeadModelFiles, errMessage] = panel_headmodel('ComputeHeadModel', iChanStudies, sMethod);
    % Report errors
    if isempty(HeadModelFiles) && ~isempty(errMessage)
        bst_report('Error', sProcess, sInputs, errMessage);
        return;
    elseif ~isempty(errMessage)
        bst_report('Warning', sProcess, sInputs, errMessage);
    end
    % Return the data files in input
    OutputFiles = {sInputs.FileName};
end



