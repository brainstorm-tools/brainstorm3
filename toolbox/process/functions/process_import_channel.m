function varargout = process_import_channel( varargin )
% PROCESS_IMPORT_CHANNEL: Import a raw file in the database.

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
    sProcess.options.usedefault.Type    = 'combobox';
    sProcess.options.usedefault.Value   = {1, strList};
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
    
    % ===== GET DEFAULT =====
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



