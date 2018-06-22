function varargout = process_headpoints_add( varargin )
% PROCESS_HEADPOINTS_ADD: Add head points to the selected channel files.
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Add head points';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 25;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelFile#Automatic_registration';
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
        'Import head points', ...              % Window title
        'ImportChannel', ...                   % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                          % Selection mode: {single,multiple}
        'files_and_dirs', ...                  % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'channel'), ... % Get all the available file formats
        'ChannelIn'};                          % DefaultFormats
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
    % Get filename to import
    HeadPointsFile = sProcess.options.channelfile.Value{1};
    FileFormat     = sProcess.options.channelfile.Value{2};
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
    % Error: no file selected
    if isempty(HeadPointsFile)
        bst_report('Error', sProcess, sInputs, 'No file selected.');
        return;
    end
    % Get all the channel files 
    uniqueChan = unique({sInputs.ChannelFile});
    % Loop on all the channel files
    for i = 1:length(uniqueChan)
        % Get first input file for this subject
        strMsg = AddHeadpoints(uniqueChan{i}, HeadPointsFile, FileFormat, isFixUnits, isApplyVox2ras);
        % Report message
        if ~isempty(strMsg)
            bst_report('Info', sProcess, sInputs, strMsg);
        end
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end


%% ===== REMOVE HEAD POINTS =====
function strMsg = AddHeadpoints(ChannelFile, HeadPointsFile, FileFormat, isFixUnits, isApplyVox2ras)
    % ===== READ HEAD POINTS FILE =====
    % Parse inputs
    if (nargin < 5) || isempty(isApplyVox2ras)
        isApplyVox2ras = 1;
    end
    if (nargin < 4) || isempty(isFixUnits)
        isFixUnits = 1;
    end
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelFile', ChannelFile); 
    % Read new files
    HeadPoints = [];
    if (nargin < 3) || isempty(HeadPointsFile) || isempty(FileFormat)
        [FileMat, HeadPointsFile, FileFormat] = import_channel(iChanStudies, [], [], [], [], 0, [], []);
    else
        FileMat = import_channel(iChanStudies, HeadPointsFile, FileFormat, [], [], 0, isFixUnits, isApplyVox2ras);
    end
    if isempty(FileMat)
        strMsg = 'No file could be read.';
        return;
    end

    % ===== GET HEAD POINTS =====
    % If head points already defined in structure: use them
    if isfield(FileMat, 'HeadPoints') && ~isempty(FileMat.HeadPoints) && ~isempty(FileMat.HeadPoints.Loc)
        HeadPoints = FileMat.HeadPoints;
    else
        HeadPoints.Loc   = [];
        HeadPoints.Label = {};
        HeadPoints.Type  = {};
    end
    % Add EEG sensors
    iEeg = good_channel(FileMat.Channel, [], 'EEG');
    if ~isempty(iEeg)
        HeadPoints.Loc   = cat(2, HeadPoints.Loc,   FileMat.Channel(iEeg).Loc);
        HeadPoints.Label = cat(2, HeadPoints.Label, {FileMat.Channel(iEeg).Name});
        HeadPoints.Type  = cat(2, HeadPoints.Type,  repmat({'EXTRA'}, [1,length(iEeg)]));
    end
    % If no head points defined
    if isempty(HeadPoints) || isempty(HeadPoints.Loc)
        strMsg = 'No head points found in file.';
        return;
    end

    % ===== ADD TO CHANNEL FILE =====
    % Load channel file
    ChannelMat = in_bst_channel(ChannelFile);
    % Add new head points
    strDupli = '';
    nDupliPoints = 0;
    if isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints) 
        % For each new head point
        for i = 1:length(HeadPoints.Label)
            % Check if head point is not already existing
            if isempty(ChannelMat.HeadPoints.Loc) 
                ChannelMat.HeadPoints.Loc   = HeadPoints.Loc(:,i);
                ChannelMat.HeadPoints.Label = HeadPoints.Label(i);
                ChannelMat.HeadPoints.Type  = HeadPoints.Type(i);
            elseif ~any((abs(ChannelMat.HeadPoints.Loc(1,:) - HeadPoints.Loc(1,i)) < 1e-6) & ...
                        (abs(ChannelMat.HeadPoints.Loc(2,:) - HeadPoints.Loc(2,i)) < 1e-6) & ...
                        (abs(ChannelMat.HeadPoints.Loc(3,:) - HeadPoints.Loc(3,i)) < 1e-6))
                ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   HeadPoints.Loc(:,i)];
                ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, HeadPoints.Label{i}];
                ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  HeadPoints.Type{i}];
            else
                nDupliPoints = nDupliPoints + 1;
            end
        end
        if (nDupliPoints > 0)
            strDupli = sprintf('%d duplicated points (ignored).\n\n', nDupliPoints);
        end
    else
        ChannelMat.HeadPoints = HeadPoints;
    end

    % Message: head points added
    nNewPoints = length(HeadPoints.Label) - nDupliPoints;
    strMsg = sprintf('%d new head points added.\n%sTotal: %d points.', nNewPoints, strDupli, length(ChannelMat.HeadPoints.Label));
    % History: Added head points
    ChannelMat = bst_history('add', ChannelMat, 'headpoints', strrep(strMsg, char(10), '  '));
    % Save modified file
    bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
end





