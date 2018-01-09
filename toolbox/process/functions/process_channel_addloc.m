function varargout = process_channel_addloc( varargin )
% PROCESS_CHANNEL_ADDLOC: Import a raw file in the database.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015-2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== EEG DEFAULTS =====
    strList = {''};
    % Get registered Brainstorm EEG defaults
    bstDefaults = bst_get('EegDefaults');
    % Build a list of strings representing all the defaults
    for iGroup = 1:length(bstDefaults)
        for iDef = 1:length(bstDefaults(iGroup).contents)
            strList{end+1} = [bstDefaults(iGroup).name ': ' bstDefaults(iGroup).contents(iDef).name];
        end
    end
    
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Add EEG positions';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Import recordings';
    sProcess.Index       = 31;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy?highlight=%28Add+EEG+positions%29#Access_the_recordings';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Option: File to import
    sProcess.options.channelfile.Comment = 'File to import:';
    sProcess.options.channelfile.Type    = 'filename';
    sProcess.options.channelfile.Value   = {...
        '', ...                                % Filename
        '', ...                                % FileFormat
        'open', ...                            % Dialog type: {open,save}
        'Import channel file', ...             % Window title
        'ImportChannel', ...                   % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                          % Selection mode: {single,multiple}
        'files_and_dirs', ...                  % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'channel'), ... % Get all the available file formats
        'ChannelIn'};                          % DefaultFormats
    % Option: Default channel files
    sProcess.options.usedefault.Comment = 'Or use default:';
    sProcess.options.usedefault.Type    = 'combobox';
    sProcess.options.usedefault.Value   = {1, strList};
    % Fix units
    sProcess.options.fixunits.Comment = 'Fix distance units automatically';
    sProcess.options.fixunits.Type    = 'checkbox';
    sProcess.options.fixunits.Value   = 1;
    % Fix units
    sProcess.options.vox2ras.Comment = 'Apply voxel=>subject transformation from the MRI';
    sProcess.options.vox2ras.Type    = 'checkbox';
    sProcess.options.vox2ras.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    ChannelMat = [];
    
    % ===== LOAD SELECTED FILE =====
    % Get filename to import
    ChannelFile = sProcess.options.channelfile.Value{1};
    FileFormat  = sProcess.options.channelfile.Value{2};
    % Get other options
    if isfield(sProcess.options, 'fixunits') && isfield(sProcess.options.fixunits, 'Value')
        isFixUnits = sProcess.options.fixunits.Value;
    else
        isFixUnits = 1;
    end
    if isfield(sProcess.options, 'vox2ras') && isfield(sProcess.options.vox2ras, 'Value')
        isApplyVox2ras = sProcess.options.vox2ras.Value;
    else
        isApplyVox2ras = 1;
    end
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', [sInputs.iStudy]);
    iChanStudies = unique(iChanStudies);
    % Load file
    if ~isempty(ChannelFile)
        ChannelMat = import_channel(iChanStudies, ChannelFile, FileFormat, [], [], 0, isFixUnits, isApplyVox2ras);
    end

    % ===== USE DEFAULT =====
    if isempty(ChannelFile)
        % Get registered Brainstorm EEG defaults
        bstDefaults = bst_get('EegDefaults');
        % Get default channel file
        iSel   = sProcess.options.usedefault.Value{1};
        strDef = sProcess.options.usedefault.Value{2}{iSel};
        % If there is something selected
        if ~isempty(strDef)
            % Format: "group: name"
            cDef   = strtrim(str_split(strDef, ':'));
            % Find the selected group in the list 
            iGroup = find(strcmpi(cDef{1}, {bstDefaults.name}));
            % If group is found
            if ~isempty(iGroup)
                % Find the selected default in the list 
                iDef = find(strcmpi(cDef{2}, {bstDefaults(iGroup).contents.name}));
                % If default was found
                if ~isempty(iDef)
                    ChannelFile = bstDefaults(iGroup).contents(iDef).fullpath;
                end
            end
        end
        % If nothing was selected (file or default)
        if isempty(ChannelFile)
            bst_report('Error', sProcess, [], 'No channel file selected.');
            return
        end
        % Load channel file
        ChannelMat = in_bst_channel(ChannelFile);
    end

    % ===== ADD POSITIONS =====
    % Add channel positions
    channel_add_loc(iChanStudies, ChannelMat, 0);
end



