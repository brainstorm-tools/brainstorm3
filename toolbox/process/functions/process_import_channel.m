function varargout = process_import_channel( varargin )
% PROCESS_IMPORT_CHANNEL: Import a raw file in the database.

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
% Authors: Francois Tadel, 2012-2017

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
    sProcess.Comment     = 'Set channel file';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 30;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy#Prepare_the_channel_file';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
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
    % Separator
    sProcess.options.separator.Type = 'separator';
    sProcess.options.separator.Comment = ' ';
    % Align sensors
    sProcess.options.channelalign.Comment = 'Align sensors using headpoints';
    sProcess.options.channelalign.Type    = 'checkbox';
    sProcess.options.channelalign.Value   = 1;
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
    
    % ===== GET FILE =====
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
            'If you get this error, you must edit your processing script:' 10 ...
            'Use the pipeline editor to generate a new script to call process_channel_add.' 10 10 ...
            'More information in GitHub issue #591: ' 10 ...
            'https://github.com/brainstorm-tools/brainstorm3/issues/591']);
        return
    end
    
    % ===== GET DEFAULT =====
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
                end
            end
        end
        FileFormat = 'BST';
    end
    % If nothing was selected (file or default)
    if isempty(ChannelFile)
        bst_report('Error', sProcess, [], 'No channel file selected.');
        return
    end

    % ===== SET CHANNEL FILE =====
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', [sInputs.iStudy]);
    iChanStudies = unique(iChanStudies);
    % Channel align
    ChannelAlign = 2 * double(sProcess.options.channelalign.Value);
    % Other options
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
    % Import channel files
    ChannelReplace = 2;
    isSave = 1;
    import_channel(iChanStudies, ChannelFile, FileFormat, ChannelReplace, ChannelAlign, isSave, isFixUnits, isApplyVox2ras);
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end



