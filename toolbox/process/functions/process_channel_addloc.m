function varargout = process_channel_addloc( varargin )
% PROCESS_CHANNEL_ADDLOC: Import a raw file in the database.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015-2023

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
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 36;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy?highlight=%28Add+EEG+positions%29#Access_the_recordings';
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
    sProcess.options.usedefault.Type    = 'combobox_label';
    sProcess.options.usedefault.Value   = {'', cat(1, strList, strList)};
    % Fix units
    sProcess.options.fixunits.Comment = 'Fix distance units automatically';
    sProcess.options.fixunits.Type    = 'checkbox';
    sProcess.options.fixunits.Value   = 1;
    % Apply vox2ras transformation 
    sProcess.options.vox2ras.Comment    = 'Apply voxel=>subject transformation from the MRI';
    sProcess.options.vox2ras.Type       = 'checkbox';
    sProcess.options.vox2ras.Value      = 1;           % If value is set to 2 programatically, then it also removes the MRI coregistration (see process_import_bids)
    sProcess.options.vox2ras.Controller = 'Vox2ras';
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Reference MRI...', ...            % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'files', ...                       % Selection mode: {files,dirs,files_and_dirs}
        {{'_subjectimage'}, 'Volume from Brainstorm database (*subjectimage*.mat)', 'BST'}, ... % Accept only files from the database
        'MriIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % Option: MRI file
    sProcess.options.mrifile.Comment = 'Reference MRI:';
    sProcess.options.mrifile.Type    = 'filename';
    sProcess.options.mrifile.Value   = SelectOptions;
    sProcess.options.mrifile.Class   = 'Vox2ras';
    % Option: Fiducials
    sProcess.options.fiducials.Comment = 'Anatomical fiducials';
    sProcess.options.fiducials.Type    = 'label';
    sProcess.options.fiducials.Value   = [];
    sProcess.options.fiducials.Hidden  = 1;
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

    % HANDLING ISSUE #591: https://github.com/brainstorm-tools/brainstorm3/issues/591
    % The list of default caps is changing between versions of Brainstorm, therefore the index of a "combobox" option can't be considered a reliable information.
    % On 6-Jan-2022: The option "usedefault" was changed from type "combobox" to "combobox_label" and the use of previous syntax is now an error.
    % Users with existing scripts will get an error and will be requested to update their scripts.
    if isempty(ChannelFile) && ~ischar(sProcess.options.usedefault.Value{1})
        bst_report('Error', sProcess, [], [...
            'On 6-Jan-2023, the option "usedefault" of process_channel_add loc was changed from type "combobox" to "combobox_label".' 10 ...
            'This parameter was previously an integer, indicating an index in a list that unfortunately changes across versions of Brainstorm.' 10 ...
            'The value now must be a string, which points at a specific default EEG cap with no amibiguity.' 10 10 ...
            'Scripts generated before 30-Jun-2022 and executed with a version of Brainstorm posterior to 30-Jun-2022' 10 ...
            'might have been selecting the wrong EEG cap, and should be fixed and executed again.' 10 10 ...
            'If you get this error, you must edit your processing script (or saved pipeline):' 10 ...
            'Use the pipeline editor to generate a new script to call the process "Add EEG position".' 10 10 ...
            'More information in GitHub issue #591: ' 10 ...
            'https://github.com/brainstorm-tools/brainstorm3/issues/591']);
        return
    end

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
    % Get reference MRI
    if isfield(sProcess.options, 'mrifile') && isfield(sProcess.options.mrifile, 'Value')
        MriFile = sProcess.options.mrifile.Value{1};
    else
        MriFile = [];
    end
    % Get fiducials
    if isfield(sProcess.options, 'fiducials') && isfield(sProcess.options.fiducials, 'Value') && ~isempty(sProcess.options.fiducials.Value)
        sFid = sProcess.options.fiducials.Value;
        isApplyVox2ras = 0;
    else
        sFid = [];
    end

    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', [sInputs.iStudy]);
    iChanStudies = unique(iChanStudies);
    % Load file
    if ~isempty(ChannelFile)
        ChannelMat = import_channel(iChanStudies, ChannelFile, FileFormat, [], [], 0, isFixUnits, isApplyVox2ras, MriFile);
        % Apply fiducials
        if ~isempty(sFid) && isfield(sFid, 'NAS') && (length(sFid.NAS)==3) && isfield(sFid, 'LPA') && (length(sFid.LPA)==3) && isfield(sFid, 'RPA') && (length(sFid.RPA)==3) && ~(isequal(sFid.NAS(:), [0;0;0]) && isequal(sFid.LPA(:), [0;0;0]) && isequal(sFid.RPA(:), [0;0;0]))
            ChannelMat.SCS.NAS = sFid.NAS;
            ChannelMat.SCS.LPA = sFid.LPA;
            ChannelMat.SCS.RPA = sFid.RPA;
            ChannelMat = channel_detect_type(ChannelMat, 1);
        end
    end

    % ===== USE DEFAULT =====
    if isempty(ChannelFile)
        % Get registered Brainstorm EEG defaults
        bstDefaults = bst_get('EegDefaults');
        % Get default channel file
        strDef = sProcess.options.usedefault.Value{1};
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
                    isMni = strcmpi(bstDefaults(iGroup).name, 'ICBM152');
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
    else
        isMni = 0;
    end

    % ===== ADD POSITIONS =====
    % Add channel positions
    if ~isempty(ChannelMat)
        channel_add_loc(iChanStudies, ChannelMat, 0, isMni);
    else
        bst_report('Warning', sProcess, [], 'No channel positions added.');
    end
    
    % Return input files
    OutputFiles = {sInputs.FileName};
end



