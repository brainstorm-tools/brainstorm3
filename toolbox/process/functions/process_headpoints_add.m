function varargout = process_headpoints_add( varargin )
% PROCESS_HEADPOINTS_ADD: Add head points to the selected channel files.
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
% Authors: Francois Tadel, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Add head points';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 62;
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
        [strMsg, strWarn] = AddHeadpoints(uniqueChan{i}, HeadPointsFile, FileFormat, isFixUnits, isApplyVox2ras);
        % Report message (as a warning when the MEG coordinate system looks wrong: the alignment
        % warning must not be silently buried in an informational message when running a pipeline)
        if ~isempty(strMsg)
            if isempty(strWarn)
                bst_report('Info', sProcess, sInputs, strMsg);
            else
                bst_report('Warning', sProcess, sInputs, strMsg);
            end
        end
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end


%% ===== REMOVE HEAD POINTS =====
function [strMsg, strWarn] = AddHeadpoints(ChannelFile, HeadPointsFile, FileFormat, isFixUnits, isApplyVox2ras)
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
    % Interactive session when the file was not specified: the user is asked to select it, and can
    % be prompted for the MEG alignment (not the case when running as part of a pipeline)
    isInteractive = (nargin < 3) || isempty(HeadPointsFile) || isempty(FileFormat);
    if isInteractive
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

    % ===== CHECK MEG COORDINATE SYSTEM =====
    % If the MEG sensors are not aligned in SCS, and the imported head points contain anatomical
    % fiducials (NAS/LPA/RPA), warn the user and offer to update the MEG coordinate system.
    % This only applies when the file was selected manually (interactive session), not when the
    % process is running as part of a pipeline.
    [strWarn, isOfferAlign] = GetMegAlignWarning(ChannelMat, HeadPoints);
    strAlignInfo = '';
    if isInteractive && isOfferAlign
        isAlign = java_dialog('confirm', ...
            ['The MEG sensors do not have the "Native=>Brainstorm/CTF" transformation and are ' 10 ...
             'currently in "Native" (head-coil based) coordinates.' 10 ...
             'Do you want to align the MEG sensors in SCS coordinates using the anatomical ' 10 ...
             'fiducials (NAS/LPA/RPA) of the new head points?'], ...
            'Align MEG sensors in SCS', []);
        if isAlign
            ChannelMat = AlignMegToScs(ChannelMat, HeadPoints);
            % The alignment resolved the warning, and is replaced by an informational message
            strAlignInfo = 'The MEG sensors were aligned in SCS coordinates using the digitized anatomical fiducials.';
            strWarn = '';
        end
    end

    % Message: head points added
    nNewPoints = length(HeadPoints.Label) - nDupliPoints;
    strMsg = sprintf('%d new head points added.\n%sTotal: %d points.', nNewPoints, strDupli, length(ChannelMat.HeadPoints.Label));
    % Warning / information about the MEG coordinate system
    if ~isempty(strWarn)
        strMsg = [strMsg 10 10 strWarn];
    elseif ~isempty(strAlignInfo)
        strMsg = [strMsg 10 10 strAlignInfo];
    end
    % History: Added head points
    ChannelMat = bst_history('add', ChannelMat, 'headpoints', strrep(strMsg, char(10), '  '));
    % Save modified file
    bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
end


%% ===== GET MEG ALIGNMENT WARNING =====
function [strWarn, isOfferAlign] = GetMegAlignWarning(ChannelMat, HeadPoints)
    % GET_MEG_ALIGN_WARNING: Check the current MEG coordinate system and the fiducials present in
    % the new head points, to warn about (and possibly offer to fix) a missing or outdated
    % "Native=>Brainstorm/CTF" transformation.
    %
    % OUTPUT:
    %    - strWarn      : Warning message to display (empty if no warning)
    %    - isOfferAlign : 1 if the user should be offered to align MEG in SCS using the new fiducials
    strWarn = '';
    isOfferAlign = 0;
    % If there are no MEG channels in this channel file, the MEG coordinate system is not relevant
    if ~isfield(ChannelMat, 'Channel') || isempty(ChannelMat.Channel) || ~isfield(ChannelMat.Channel, 'Type') || isempty(channel_find(ChannelMat.Channel, 'MEG'))
        return;
    end
    % Does the MEG have the "Native=>Brainstorm/CTF" transformation?
    if isfield(ChannelMat, 'TransfMegLabels') && iscell(ChannelMat.TransfMegLabels) && ~isempty(ChannelMat.TransfMegLabels)
        hasCtfTransf = ismember('Native=>Brainstorm/CTF', ChannelMat.TransfMegLabels);
    else
        hasCtfTransf = 0;
    end
    % Detect the anatomical fiducials (NAS/LPA/RPA) in the imported head points
    [iNas, iLpa, iRpa] = GetAnatomicalFiducials(HeadPoints);
    hasFiducials = ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa);
    % MEG in "Native" coordinates, fiducials available: propose to align in SCS
    if hasFiducials && ~hasCtfTransf
        strWarn = ['WARNING: The MEG sensors are in "Native" coordinates and do not have the ' 10 ...
                   '"Native=>Brainstorm/CTF" transformation, so the digitized fiducials were NOT ' 10 ...
                   'used to align the MEG sensors with the anatomy, and the MEG sensors are likely ' 10 ...
                   'misaligned. The MEG coordinate system cannot be updated from the head points only.' 10 ...
                   'Recommended: re-import the MEG data with a single .pos file that contains both ' 10 ...
                   'the head coils (HPI-N/L/R) and the anatomical fiducials (NAS/LPA/RPA).'];
        isOfferAlign = 1;
    % MEG in "Native" coordinates, no usable fiducials available: warn only
    elseif ~hasCtfTransf
        strWarn = ['WARNING: The MEG sensors are in "Native" coordinates and do not have the ' 10 ...
                   '"Native=>Brainstorm/CTF" transformation. The new head points do NOT provide ' 10 ...
                   'anatomical fiducials (NAS/LPA/RPA) usable to align the MEG: they are either ' 10 ...
                   'missing, or the file contains only one set of three markers (assumed to be ' 10 ...
                   'the MEG head coils, as in older recordings), in which case the head coil ' 10 ...
                   'positions must also be defined on the MRI.'];
    % MEG already in SCS, fiducials available: warn that the new SCS may differ
    elseif hasFiducials
        strWarn = ['Warning: The new head points contain anatomical fiducials (NAS/LPA/RPA) that ' 10 ...
                   'may define a different SCS than the one currently used for the MEG sensors. ' 10 ...
                   'The MEG sensors were NOT re-aligned, and may be misaligned with the anatomy. ' 10 ...
                   'Recommended: re-import the MEG data with the correct single .pos file, or check ' 10 ...
                   'the "Native=>Brainstorm/CTF" transformation of the channel file.'];
    end
end


%% ===== GET ANATOMICAL FIDUCIALS =====
function [iNas, iLpa, iRpa] = GetAnatomicalFiducials(HeadPoints)
    % GET_ANATOMICAL_FIDUCIALS: Find the indices of the three anatomical fiducials (NAS/LPA/RPA)
    % in a set of head points. Empty indices are returned for the fiducials that are not present.
    % Normally the digitization also contains the three MEG head coils (HPI-N/L/R), and both sets
    % are required to define the coordinate systems. Older datasets contain a single set of three
    % markers only, labeled either like the anatomical fiducials or like the head coils
    % (HPI-N/L/R): in that case the markers are assumed to be the head coils (without them,
    % nothing useful can be done with MEG data), not the anatomical fiducials, so no anatomical
    % fiducial is returned. See in_channel_pos and in_fopen_ctf for the same convention.
    iNas = [];
    iLpa = [];
    iRpa = [];
    if isfield(HeadPoints, 'Label') && isfield(HeadPoints, 'Loc') && ~isempty(HeadPoints.Label) && (size(HeadPoints.Loc, 2) == length(HeadPoints.Label))
        iNas = find(strcmpi(HeadPoints.Label, 'Nasion') | strcmpi(HeadPoints.Label, 'NAS'));
        iLpa = find(strcmpi(HeadPoints.Label, 'Left')   | strcmpi(HeadPoints.Label, 'LPA'));
        iRpa = find(strcmpi(HeadPoints.Label, 'Right')  | strcmpi(HeadPoints.Label, 'RPA'));
        % Both sets must be present: a single set of markers is treated as head coils only
        hasCoils = any(strcmpi(HeadPoints.Label, 'HPI-N')) && any(strcmpi(HeadPoints.Label, 'HPI-L')) && any(strcmpi(HeadPoints.Label, 'HPI-R'));
        if ~(~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa) && hasCoils)
            iNas = [];
            iLpa = [];
            iRpa = [];
        end
    end
end


%% ===== ALIGN MEG TO SCS =====
function ChannelMat = AlignMegToScs(ChannelMat, HeadPoints)
    % ALIGN_MEG_TO_SCS: Re-define the SCS coordinate system of the channel file from the anatomical
    % fiducials (NAS/LPA/RPA) contained in the new head points, and re-align the MEG sensors and
    % head points in SCS accordingly. This adds (or updates) the "Native=>Brainstorm/CTF"
    % transformation to the channel file.
    % If the fiducials are not all present in HeadPoints, the channel file is returned unchanged.

    % Safety: only apply this when the MEG has not been aligned in SCS yet. Re-aligning sensors
    % that are already in SCS would apply the transformation twice and misalign them.
    if isfield(ChannelMat, 'TransfMegLabels') && iscell(ChannelMat.TransfMegLabels) && ~isempty(ChannelMat.TransfMegLabels) && ismember('Native=>Brainstorm/CTF', ChannelMat.TransfMegLabels)
        return;
    end
    % Get the three anatomical fiducials: if they are not all present, return unchanged
    [iNas, iLpa, iRpa] = GetAnatomicalFiducials(HeadPoints);
    if isempty(iNas) || isempty(iLpa) || isempty(iRpa)
        return;
    end
    % Define SCS from the digitized fiducials (positions are in meters)
    ChannelMat.SCS.NAS = mean(HeadPoints.Loc(:,iNas)', 1);
    ChannelMat.SCS.LPA = mean(HeadPoints.Loc(:,iLpa)', 1);
    ChannelMat.SCS.RPA = mean(HeadPoints.Loc(:,iRpa)', 1);
    % Re-align the sensors and the head points in SCS. channel_detect_type computes the SCS
    % transformation from the three fiducials, converts all the positions to SCS, and appends
    % the "Native=>Brainstorm/CTF" transformation to the channel file.
    ChannelMat = channel_detect_type(ChannelMat, 1, 0);
end





