function varargout = process_adjust_coordinates(varargin)
% PROCESS_ADJUST_COORDINATES: Adjust, recompute, or remove various coordinate transformations.

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
% Authors: Marc Lalancette, 2018

eval(macro_method);
end



function sProcess = GetDescription() %#ok<DEFNU>
    % Description of the process
    sProcess.Comment     = 'Adjust coordinate system';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadMotion#Adjust_the_reference_head_position';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 40;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Option [to do: ignore bad segments]
    sProcess.options.reset.Type    = 'checkbox';
    sProcess.options.reset.Comment = 'Reset coordinates using original channel file (removes all adjustments: head, points, manual).';
    sProcess.options.reset.Value   = 0;
    sProcess.options.reset.Controller = 'Reset';
    % Need the file format for re-importing a channel file.
    FileFormatsChan = bst_get('FileFilters', 'channel');
    sProcess.options.format.Type = 'combobox';
    sProcess.options.format.Comment = 'For reset option, specify the channel file format:';
    sProcess.options.format.Value = {1, FileFormatsChan(:, 2)'};
    sProcess.options.format.Class = 'Reset';
    sProcess.options.head.Type    = 'checkbox';
    sProcess.options.head.Comment = 'Adjust head position to median location - CTF only.';
    sProcess.options.head.Value   = 0;
    sProcess.options.points.Type    = 'checkbox';
    sProcess.options.points.Comment = 'Refine MRI coregistration using digitized head points.';
    sProcess.options.points.Value   = 0;
    sProcess.options.remove.Type    = 'checkbox';
    sProcess.options.remove.Comment = 'Remove selected adjustments (if present) instead of adding them.';
    sProcess.options.remove.Value   = 0;
    sProcess.options.display.Type    = 'checkbox';
    sProcess.options.display.Comment = 'Display "before" and "after" alignment figures.';
    sProcess.options.display.Value   = 0;
    
end



function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end



function OutputFiles = Run(sProcess, sInputs)
    
    isDisplay = sProcess.options.display.Value;
    nInFiles = length(sInputs);
    
    isFileOk = false(1, nInFiles);
    if isDisplay
        hFigAfter = [];
        hFigBefore = [];
        bst_memory('UnloadAll', 'Forced'); % Close all the existing figures.
    end
    
    [UniqueChan, iUniqFiles, iUniqInputs] = unique({sInputs.ChannelFile});
    nFiles = numel(iUniqFiles);
    
    if ~sProcess.options.remove.Value && sProcess.options.head.Value && ...
            nFiles < nInFiles
        bst_report('Warning', sProcess, sInputs, ...
            'Multiple inputs were found for a single channel file. Only the first one will be used for adjusting the head position.');
    end
    bst_progress('start', 'Adjust coordinate system', ...
        ' ', 0, nFiles);
    % If resetting, in case the original data moved, and because the same
    % channel file may appear in many places for processed data, keep track
    % of user file selections.
    NewChannelFiles = cell(0, 2);
    for iFile = iUniqFiles(:)' % no need to repeat on same channel file.
        
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        % Get the leading modality
        [tmp, DispMod] = channel_get_modalities(ChannelMat.Channel);
        % 'MEG' is added when 'MEG GRAD' or 'MEG MAG'.
        ModPriority = {'MEG', 'EEG', 'SEEG', 'ECOG', 'NIRS'};
        iMod = find(ismember(ModPriority, DispMod), 1, 'first');
        if isempty(iMod)
            Modality = [];
        else
            Modality = ModPriority{iMod};
        end
        
        if isDisplay && ~isempty(Modality)
            % Display "before" results.
            close([hFigBefore, hFigAfter]);
            hFigBefore = channel_align_manual(sInputs(iFile).ChannelFile, Modality, 0);
        end
        
        bst_progress('inc', 1);
        
        
        % ----------------------------------------------------------------
        if sProcess.options.reset.Value
            % The main goal of this option is to fix a bug in a previous
            % version: when importing a channel file, when going to SCS
            % coordinates based on digitized coils and anatomical
            % fiducials, the channel orientation was wrong.  We wish to fix
            % this but keep as much pre-processing that was previously
            % done.  Thus we will re-import the channel file, and copy the
            % projectors (and history) from the old one.
            
            [ChannelMat, NewChannelFiles, Failed] = ...
                ResetChannelFile(ChannelMat, NewChannelFiles, sInputs(iFile), sProcess);
            if Failed
                continue;
            end
            
            % ----------------------------------------------------------------
        elseif sProcess.options.remove.Value
            % Because channel_align_manual does not consistently apply the
            % manual transformation to all sensors or save it in both
            % TransfMeg and TransfEeg, it could lead to confusion and
            % errors when playing with transforms.  Therefore, if we detect
            % a difference between the MEG and EEG transforms when trying
            % to remove one that applies to both (currently only refine
            % with head points), we don't proceed and recommend resetting
            % with the original channel file instead.
            
            Which = {};
            if sProcess.options.head.Value
                Which{end+1} = 'AdjustedNative';
            end
            if sProcess.options.points.Value
                Which{end+1} = 'refine registration: head points';
            end
            
            for TransfLabel = Which
                TransfLabel = TransfLabel{1};
                ChannelMat = RemoveTransformation(ChannelMat, TransfLabel, sInputs(iFile), sProcess);
            end % TransfLabel loop
            
        end % reset channel file or remove transformations
        
        % ----------------------------------------------------------------
        if ~sProcess.options.remove.Value && sProcess.options.head.Value
            [ChannelMat, Failed] = AdjustHeadPosition(ChannelMat, sInputs(iFile), sProcess);            
            if Failed
                continue;
            end
        end % adjust head position        
        
        % ----------------------------------------------------------------
        if ~sProcess.options.remove.Value && sProcess.options.points.Value
            % Redundant, but makes sense to have it here also.
            
            bst_progress('text', 'Fitting head surface to points...');
            [ChannelMat, R, T, isSkip] = ...
                channel_align_auto(sInputs(iFile).ChannelFile, ChannelMat, 0, 0); % No warning or confirmation
            % ChannelFile needed to find subject and scalp surface, but not
            % used otherwise when ChannelMat is provided.
            if isSkip
                bst_report('Error', sProcess, sInputs(iFile), ...
                    'Error trying to refine registration using head points.');
                continue;
            end
            
        end % refine registration with head points
        
        % ----------------------------------------------------------------
        % Save channel file.
        bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
        isFileOk(iFile) = true;
        
        if isDisplay && ~isempty(Modality)
            % Display "after" results, besides the "before" figure.
            hFigAfter = channel_align_manual(sInputs(iFile).ChannelFile, Modality, 0);
        end
        
    end % file loop
    bst_progress('stop');
    
    % Return the input files that were processed properly.  Include those
    % that were removed due to sharing a channel file, where appropriate.
    % The complicated indexing picks the first input of those with the same
    % channel file, i.e. the one that was marked ok.
    OutputFiles = {sInputs(isFileOk(iUniqInputs(iUniqFiles))).FileName};
end

%     if ~sProcess.options.remove.Value && sProcess.options.scs.Value
%             % This not yet implemented option could apply the Native to SCS
%             % transformation for head points loaded after the raw data was
%             % imported.
%                 % Find existing SCS transformation. If it's missing, make a
%                 % place for it before head point refinement, or at the end.
%                 iTransf = find(strcmp(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF'));
%                 if numel(iTransf) > 1
%                     % Remove duplicates.
%                     ChannelMat.TransfMeg(iTransf(2:end)) = [];
%                     ChannelMat.TransfMegLabels(iTransf(2:end)) = [];
%                 elseif isempty(iTransf)
%                     % Look for head point refinment.
%                     iTransf = find(strcmp(ChannelMat.TransfMegLabels, 'refine registration: head points'));
%                     if isempty(iTransf)
%                         iTransf = end+1;
%                         ChannelMat.TransfMeg(iTransf) = eye(4);
%                         ChannelMat.TransfMegLabels(iTransf) = 'Native=>Brainstorm/CTF';
%                     else
%                         ChannelMat.TransfMeg(iTransf+1:end+1) = ChannelMat.TransfMeg(iTransf:end);
%                         ChannelMat.TransfMegLabels(iTransf+1:end+1) = ChannelMat.TransfMegLabels(iTransf:end);
%                         ChannelMat.TransfMeg(iTransf) = eye(4);
%                         ChannelMat.TransfMegLabels(iTransf) = 'Native=>Brainstorm/CTF';
%                     end
%                 end
%                 % Repeat for EEG transformations.
%                 iTransf = find(strcmp(ChannelMat.TransfEegLabels, 'Native=>Brainstorm/CTF'));
%                 if numel(iTransf) > 1
%                     % Remove duplicates.
%                     ChannelMat.TransfEeg(iTransf(2:end)) = [];
%                     ChannelMat.TransfEegLabels(iTransf(2:end)) = [];
%                 elseif isempty(iTransf)
%                     % Look for head point refinment.
%                     iTransf = find(strcmp(ChannelMat.TransfEegLabels, 'refine registration: head points'));
%                     if isempty(iTransf)
%                         iTransf = end+1;
%                         ChannelMat.TransfEeg(iTransf) = eye(4);
%                         ChannelMat.TransfEegLabels(iTransf) = 'Native=>Brainstorm/CTF';
%                     else
%                         ChannelMat.TransfEeg(iTransf+1:end+1) = ChannelMat.TransfMeg(iTransf:end);
%                         ChannelMat.TransfEegLabels(iTransf+1:end+1) = ChannelMat.TransfMegLabels(iTransf:end);
%                         ChannelMat.TransfEeg(iTransf) = eye(4);
%                         ChannelMat.TransfEegLabels(iTransf) = 'Native=>Brainstorm/CTF';
%                     end
%                 end


function [ChannelMat, NewChannelFiles, Failed] = ...
        ResetChannelFile(ChannelMat, NewChannelFiles, sInput, sProcess)
    if nargin < 4
        sProcess = [];
    end
    Failed = false;
    bst_progress('text', 'Importing channel file...');
    % Extract original data file from channel file history.
    if any(size(ChannelMat.History) < [1, 3]) || ...
            ~strcmp(ChannelMat.History{1, 2}, 'import')
        NotFound = true;
        ChannelFile = '';
    else
        ChannelFile = regexp(ChannelMat.History{1, 3}, ...
            '(?<=: )(.*)(?= \()', 'match');
        if isempty(ChannelFile)
            NotFound = true;
        else
            ChannelFile = ChannelFile{1};
            if exist(ChannelFile, 'file') % could be file or folder (e.g. .ds)
                NotFound = false;
            else
                NotFound = true;
            end
        end
    end
    if NotFound && ~isempty(ChannelFile)
        % See if the user already gave the new file location.
        [NewFound, iNew] = ismember(ChannelFile, NewChannelFiles(:, 1));
        if NewFound
            ChannelFile = NewChannelFiles{iNew, 2};
            NotFound = false;
            bst_report('Info', sProcess, sInput, ...
                sprintf('Using channel file in new location: %s.', ChannelFile));
        end
    end
    FileFormatsChan = bst_get('FileFilters', 'channel');
    FileFormat = FileFormatsChan{sProcess.options.format.Value{1}, 3};
    if NotFound
        bst_report('Info', sProcess, sInput, ...
            sprintf('Could not find original channel file: %s.', ChannelFile));
        % import_channel will prompt the user, but they will not
        % know which file to pick!  And prompt is modal for Matlab,
        % so likely can't look at command window (e.g. if
        % Brainstorm is in front).
        [ChanPath, ChanName, ChanExt] = fileparts(ChannelFile);
        MsgFig = msgbox(sprintf('Select the new location of channel file %s %s to reset %s.', ...
            ChanPath, [ChanName, ChanExt], sInput.ChannelFile), ...
            'Reset channel file', 'replace');
        movegui(MsgFig, 'north');
        figure(MsgFig); % bring it to front.
        % Adjust default format to the one selected.
        DefaultFormats = bst_get('DefaultFormats');
        DefaultFormats.ChannelIn = FileFormat;
        bst_set('DefaultFormats',  DefaultFormats);
        
        [NewChannelMat, NewChannelFile] = import_channel(...
            sInput.iStudy, '', FileFormat, 0, 0, 0, [], []);
    else
        
        % Import from original file.
        [NewChannelMat, NewChannelFile] = import_channel(...
            sInput.iStudy, ChannelFile, FileFormat, 0, 0, 0, [], []);
        % iStudies, ChannelFile, FileFormat, ChannelReplace, ChannelAlign, isSave, isFixUnits, isApplyVox2ras)
        % iStudy index is needed to avoid error for noise recordings with missing SCS transform.
        % ChannelReplace is for replacing the file, only if isSave.
        % ChannelAlign is for headpoints, but also ONLY if isSave.  We do it later if user selected.
    end
    
    % See if it worked.
    if isempty(NewChannelFile)
        bst_report('Error', sProcess, sInput, ...
            'No file channel file selected.');
        Failed = true;
        return;
    elseif isempty(NewChannelMat)
        bst_report('Error', sProcess, sInput, ...
            sprintf('Unable to import channel file: %s', NewChannelFile));
        Failed = true;
        return;
    elseif numel(NewChannelMat.Channel) ~= numel(ChannelMat.Channel)
        bst_report('Error', sProcess, sInput, ...
            'Original channel file has different channels than current one, aborting.');
        Failed = true;
        return;
    elseif NotFound && ~isempty(ChannelFile)
        % Save the selected new location.
        NewChannelFiles(end+1, :) = {ChannelFile, NewChannelFile};
    end
    % Copy the new old projectors and history to the new structure.
    NewChannelMat.Projector = ChannelMat.Projector;
    NewChannelMat.History = ChannelMat.History;
    ChannelMat = NewChannelMat;
    %     clear NewChannelMat
    % Add number of channels to comment, like in db_set_channel.
    ChannelMat.Comment = [ChannelMat.Comment, sprintf(' (%d)', length(ChannelMat.Channel))];
    ChannelMat = bst_history('add', ChannelMat, 'import', ...
        ['Reset from: ' NewChannelFile ' (Format: ' FileFormat ')']);
end % ResetChannelFile


function ChannelMat = RemoveTransformation(ChannelMat, TransfLabel, sInput, sProcess)
    if nargin < 4
        sProcess = [];
    end
    Found = false;
    iUndoMeg = find(strcmpi(ChannelMat.TransfMegLabels, TransfLabel), 1, 'last');
    isMegOnly = strcmp(TransfLabel, 'AdjustedNative');
    if isMegOnly
        iChan = sort([good_channel(ChannelMat.Channel, [], 'MEG'), ...
            good_channel(ChannelMat.Channel, [], 'MEG REF')]);
        % Need to check for empty, otherwise applies to all channels!
    else
        iChan = []; % All channels.
        % Note: NIRS doesn't have a separate set of
        % transformations, but "refine" and "SCS" are applied
        % to NIRS as well.
    end
    while ~isempty(iUndoMeg)
        if isMegOnly && isempty(iChan)
            % No MEG channels, just delete transformation.
            ChannelMat.TransfMegLabels(iUndoMeg) = [];
            ChannelMat.TransfMeg(iUndoMeg) = [];
        else
            TransfAfter = eye(4);
            for t = iUndoMeg+1:numel(ChannelMat.TransfMeg)
                TransfAfter = ChannelMat.TransfMeg{t} * TransfAfter;
            end
            % Only remove the selected transform, reapply the following ones.
            Transf = (TransfAfter / ChannelMat.TransfMeg{iUndoMeg}) / TransfAfter; % T * inv(U) * inv(T), associativity is importanat here.
            if ~isMegOnly
                % Find the same transformation for EEG.
                iUndoEeg = find(strcmpi(ChannelMat.TransfEegLabels, TransfLabel), 1, 'last');
                if isempty(iUndoEeg)
                    bst_report('Error', sProcess, sInput, ...
                        ['EEG transformation not found: ', TransfLabel, '. Reset recommended.']);
                    break;
                end
                TransfAfterE = eye(4);
                for t = iUndoEeg+1:numel(ChannelMat.TransfEeg)
                    TransfAfterE = ChannelMat.TransfEeg{t} * TransfAfterE;
                end
                % Only remove the selected transform, reapply the following ones.
                TransfE = (TransfAfterE / ChannelMat.TransfEeg{iUndoEeg}) / TransfAfterE; % T * inv(U) * inv(T), associativity is importanat here.
                if max(abs(TransfE(:) - Transf(:))) > 1e-10
                    bst_report('Error', sProcess, sInput, ...
                        ['MEG and EEG transformation mismatch: ', TransfLabel, '. Reset recommended.']);
                    break;
                end
            end
            % Apply inverse transformation.
            ChannelMat = channel_apply_transf(ChannelMat, Transf, iChan, ~isMegOnly);
            ChannelMat = ChannelMat{1};
            % Remove last tranformation we just added and the one it cancels.
            ChannelMat.TransfMegLabels([iUndoMeg, end]) = [];
            ChannelMat.TransfMeg([iUndoMeg, end]) = [];
            if ~isMegOnly
                ChannelMat.TransfEegLabels([iUndoEeg, end]) = [];
                ChannelMat.TransfEeg([iUndoEeg, end]) = [];
            end
        end
        Found = true;
        
        iUndoMeg = find(strcmpi(ChannelMat.TransfMegLabels, TransfLabel), 1, 'last');
    end % While transformation is found.
    
    if ~Found
        bst_report('Info', sProcess, sInput, ...
            ['Coordinate transformation not found: ', TransfLabel]);
    else
        ChannelMat = bst_history('add', ChannelMat, 'align', ['Removed transform: ' TransfLabel]);
    end
end % RemoveTransformation


function [ChannelMat, Failed] = AdjustHeadPosition(ChannelMat, sInput, sProcess)
    if nargin < 4
        sProcess = [];
    end
    Failed = false;
    % Check the input is CTF.
    DataMat = in_bst_data(sInput.FileName, 'Device');
    if ~strcmp(DataMat.Device, 'CTF')
        bst_report('Error', sProcess, sInput, ...
            'Adjust head position is currently only available for CTF data.');
        Failed = true;
        return;
    end
    
    % The data could be changed such that the head position
    % could be readjusted (e.g. by deleting segments).  This is
    % allowed and the previous adjustment will be replaced.
    if isfield(ChannelMat, 'TransfMegLabels') && iscell(ChannelMat.TransfMegLabels) && ...
            ismember('AdjustedNative', ChannelMat.TransfMegLabels)
        bst_report('Info', sProcess, sInput, ...
            'Head position already adjusted. Previous adjustment will be replaced.');
    end
    
    % Load head coil locations, in m.
    bst_progress('text', 'Loading head coil locations...');
    %                 bst_progress('inc', 1);
    Locations = process_evt_head_motion('LoadHLU', sInput, [], false);
    if isempty(Locations)
        % No HLU channels. Error already reported. Skip this file.
        Failed = true;
        return;
    end
    bst_progress('text', 'Correcting head position...');
    % If a collection was aborted, the channels will be filled with
    % zeros. We must remove these locations.
    % This reshapes to continuous if in epochs, but works either way.
    Locations(:, all(Locations == 0, 1)) = [];
    
    MedianLoc = MedianLocation(Locations);
    %         disp(MedianLoc);
    
    % Also get the initial reference position.  We only use it to see
    % how much the adjustment moves.
    InitRefLoc = ReferenceHeadLocation(ChannelMat, sInput);
    if isempty(InitRefLoc)
        % There was an error, already reported. Skip this file.
        Failed = true;
        return;
    end
    
    % Extract transformations that are applied before and after the
    % head position adjustment.  Any previous adjustment will be
    % ignored here and replaced later.
    [TransfBefore, TransfAdjust, TransfAfter, iAdjust, iDewToNat] = ...
        GetTransforms(ChannelMat, sInput);
    if isempty(TransfBefore)
        % There was an error, already reported. Skip this file.
        Failed = true;
        return;
    end
    % Compute transformation corresponding to coil position.
    [TransfMat, TransfAdjust] = LocationTransform(MedianLoc, ...
        TransfBefore, TransfAdjust, TransfAfter);
    % This TransfMat would automatically give an identity
    % transformation if the process is run multiple times, and
    % TransfAdjust would not change.
    
    % Apply this transformation to the current head position.
    % This is a correction to the 'Dewar=>Native'
    % transformation so it applies to MEG channels only and not
    % to EEG or head points, which start in Native.
    iMeg  = sort([good_channel(ChannelMat.Channel, [], 'MEG'), ...
        good_channel(ChannelMat.Channel, [], 'MEG REF')]);
    ChannelMat = channel_apply_transf(ChannelMat, TransfMat, iMeg, false); % Don't apply to head points.
    ChannelMat = ChannelMat{1};
    
    % After much thought, it was decided to save this
    % adjustment transformation separately and at its logical
    % place: between 'Dewar=>Native' and
    % 'Native=>Brainstorm/CTF'.  In particular, this allows us
    % to use it directly when displaying head motion distance.
    % This however means we must correctly move the
    % transformation from the end where it was just applied to
    % its logical place. This "moved" transformation is also
    % computed in LocationTransform above.
    if isempty(iAdjust)
        iAdjust = iDewToNat + 1;
        % Shift transformations to make room for the new
        % adjustment, and reject the last one, that we just
        % applied.
        ChannelMat.TransfMegLabels(iDewToNat+2:end) = ...
            ChannelMat.TransfMegLabels(iDewToNat+1:end-1); % reject last one
        ChannelMat.TransfMeg(iDewToNat+2:end) = ChannelMat.TransfMeg(iDewToNat+1:end-1);
    else
        ChannelMat.TransfMegLabels(end) = []; % reject last one
        ChannelMat.TransfMeg(end) = [];
    end
    % Change transformation label to something unique to this process.
    ChannelMat.TransfMegLabels{iAdjust} = 'AdjustedNative';
    % Insert or replace the adjustment.
    ChannelMat.TransfMeg{iAdjust} = TransfAdjust;
    
    ChannelMat = bst_history('add', ChannelMat, 'align', ...
        'Added adjustment to Native coordinates based on median head position');
    
    % Give an idea of the distance we moved.
    AfterRefLoc = ReferenceHeadLocation(ChannelMat, sInput);
    if isempty(AfterRefLoc)
        % There was an error, already reported. Skip this file.
        Failed = true;
        return;
    end
    DistanceAdjusted = process_evt_head_motion('RigidDistances', AfterRefLoc, InitRefLoc);
    fprintf('Head position adjusted by %1.1f mm.\n', DistanceAdjusted * 1e3);
    bst_report('Info', sProcess, sInput, ...
        sprintf('Head position adjusted by %1.1f mm.\n', DistanceAdjusted * 1e3));
end % AdjustHeadPosition



function InitLoc = ReferenceHeadLocation(ChannelMat, sInput)
    % Compute initial head location in Dewar coordinates.
    
    if nargin < 2
        sInput = [];
    end
    
    % This isn't exactly the coil positions in the .hc file, but was verified
    % to give the same transformation.
    if isfield(ChannelMat, 'SCS') && all(isfield(ChannelMat.SCS, {'NAS','LPA','RPA'})) && ...
            (length(ChannelMat.SCS.NAS) == 3) && (length(ChannelMat.SCS.LPA) == 3) && (length(ChannelMat.SCS.RPA) == 3)
        % Use the SCS distances from origin, with left and right PA points
        % symmetrical.
        LeftRightDist = sqrt(sum((ChannelMat.SCS.LPA - ChannelMat.SCS.RPA).^2));
        NasDist = ChannelMat.SCS.NAS(1);
    else
        % Just use some reasonable distances.
        LeftRightDist = 0.14;
        NasDist = 0.10;
    end
    InitLoc = [[NasDist; 0; 0; 1], [0; LeftRightDist/2; 0; 1], ...
        [0; -LeftRightDist/2; 0; 1]];
    % That InitLoc is in Native coordiates.  Bring it back to Dewar
    % coordinates to compare with HLU channels.
    %
    % Take into account if the initial/reference head position was
    % "adjusted", i.e. replaced by the median position throughout the
    % recording.  If so, use all transformations between 'Dewar=>Native' to
    % this adjustment transformation.  (In practice there shouldn't be any
    % between them.)
    iDewToNat = find(strcmpi(ChannelMat.TransfMegLabels, 'Dewar=>Native'));
    if isempty(iDewToNat) || numel(iDewToNat) > 1
        bst_report('Error', 'process_adjust_coordinates', sInput, ...
            'Could not find required transformation.');
        InitLoc = [];
        return;
    end
    iAdjust = find(strcmpi(ChannelMat.TransfMegLabels, 'AdjustedNative'));
    if numel(iAdjust) > 1
        bst_report('Error', 'process_adjust_coordinates', sInput, ...
            'Could not find required transformation.');
        InitLoc = [];
        return;
    elseif isempty(iAdjust)
        iAdjust = iDewToNat;
    end
    for t = iAdjust:-1:iDewToNat
        InitLoc = ChannelMat.TransfMeg{t} \ InitLoc;
    end
    InitLoc(4, :) = [];
    InitLoc = InitLoc(:);
end % ReferenceHeadLocation


function [TransfBefore, TransfAdjust, TransfAfter, iAdjust, iDewToNat] = ...
        GetTransforms(ChannelMat, sInput)
    % Extract transformations that are applied before and after the head
    % position adjustment we are creating now.  We keep the 'Dewar=>Native'
    % transformation intact and separate from the adjustment for no deep
    % reason, but it is the only remaining trace of the initial head coil
    % positions in Brainstorm.
    
    % The reason this function was split from LocationTransform is that it
    % can be called only once outside the head sample loop in process_sss,
    % whereas LocationTransform is called many times within the loop.
    
    % When this is called from process_sss, we are possibly working on a
    % second head adjustment, this time based on the instantaneous head
    % position, so we need to keep the global adjustment based on the entire
    % recording if it is there.
    
    % Check order of transformations.  These situations should not happen
    % unless there was some manual editing.
    iDewToNat = find(strcmpi(ChannelMat.TransfMegLabels, 'Dewar=>Native'));
    iAdjust = find(strcmpi(ChannelMat.TransfMegLabels, 'AdjustedNative'));
    TransfBefore = [];
    TransfAfter = [];
    TransfAdjust = [];
    if isempty(iDewToNat) || numel(iDewToNat) > 1
        bst_report('Error', 'process_adjust_coordinates', sInput, ...
            'Could not find required transformation.');
        return;
    end
    if iDewToNat > 1
        bst_report('Warning', 'process_adjust_coordinates', sInput, ...
            'Unexpected transformations found before ''Dewar=>Native''; ignoring them.');
    end
    if numel(iAdjust) > 1
        bst_report('Error', 'process_adjust_coordinates', sInput, ...
            'Could not find required transformation.');
        return;
    elseif isempty(iAdjust)
        iBef = iDewToNat;
        iAft = iDewToNat + 1;
        TransfAdjust = eye(4);
    else
        if iAdjust < iDewToNat
            bst_report('Error', 'process_adjust_coordinates', sInput, ...
                'Unable to interpret order of transformations.');
            return;
        elseif iAdjust - iDewToNat > 1
            bst_report('Warning', 'process_adjust_coordinates', sInput, ...
                'Unexpected transformations found between ''Dewar=>Native'' and ''AdjustedNative''; assuming they make sense there.');
        end
        iBef = iAdjust - 1;
        iAft = iAdjust + 1;
        TransfAdjust = ChannelMat.TransfMeg{iAdjust};
    end
    
    TransfBefore = eye(4);
    for t = iDewToNat:iBef
        TransfBefore = ChannelMat.TransfMeg{t} * TransfBefore;
    end
    TransfAfter = eye(4);
    for t = iAft:numel(ChannelMat.TransfMeg)
        TransfAfter = ChannelMat.TransfMeg{t} * TransfAfter;
    end
end % GetTransforms


function [TransfMat, TransfAdjust] = LocationTransform(Loc, ...
        TransfBefore, TransfAdjust, TransfAfter)
    % Compute transformation corresponding to head coil positions.
    % We want this to be as efficient as possible, since used many times by
    % process_sss.
    
    % Transformation matrices are in m, as are HLU channels.
    % The HLU channels (here Loc) are in dewar coordinates.  Bring them to
    % the current system by applying all saved transformations, starting with
    % 'Dewar=>Native'.  This will save us from having to use inverse
    % transformations later.
    Loc = TransfAfter(1:3, :) * TransfAdjust * TransfBefore * [reshape(Loc, 3, 3); 1, 1, 1];
    %   [[Loc(1:3), Loc(4:6), Loc(5:9)]; 1, 1, 1]; % test if efficiency difference.
    
    % For efficiency, use these local functions.
    CrossProduct = @(a, b) [a(2).*b(3)-a(3).*b(2); a(3).*b(1)-a(1).*b(3); a(1).*b(2)-a(2).*b(1)];
    Norm = @(a) sqrt(sum(a.^2));
    
    Origin = (Loc(4:6)' + Loc(7:9)') / 2;
    X = Loc(1:3)' - Origin;
    X = X / Norm(X);
    Y = Loc(4:6)' - Origin; % Not yet perpendicular to X in general.
    Z = CrossProduct(X, Y);
    Z = Z / Norm(Z);
    Y = CrossProduct(Z, X); % Doesn't go through PA points anymore in general.
    %     Y = Y / Norm(Y); % Not necessary
    TransfMat = eye(4);
    TransfMat(1:3,1:3) = [X, Y, Z]';
    TransfMat(1:3,4) = - [X, Y, Z]' * Origin;
    
    % TransfMat at this stage is a transformation from the current system
    % back to the now adjusted Native system.  We thus need to reapply the
    % following tranformations.
    
    if nargout > 1
        % Transform from non-adjusted native coordinates to newly adjusted native
        % coordinates.  To be saved in channel file between "Dewar=>Native" and
        % "Native=>Brainstorm/CTF".
        TransfAdjust = TransfMat * TransfAfter * TransfAdjust;
    end
    
    % Transform from current Bst coordinates, to adjusted Bst coordinates.
    % To be applied to sensor locations.
    TransfMat = TransfAfter * TransfMat;
end % LocationTransform


function MedianLoc = MedianLocation(Locations)
    % Overall geometric median location of each head coil.
    
    if size(Locations, 1) ~= 9
        bst_error('Expecting 9 HLU channels in first dimension.');
    end
    
    nSxnT = size(Locations, 2) * size(Locations, 3);
    MedianLoc = GeoMedian( ...
        permute(reshape(Locations, [3, 3, nSxnT]), [3, 1, 2]), 1e-3 );
    MedianLoc = reshape(MedianLoc, [9, 1]);
    
end % MedianLocation


function M = GeoMedian(X, Precision)
    % Geometric median of a list of points in d dimensions.
    %
    % M = GeoMedian(X, Precision)
    %
    % Calculate the geometric median: the point that minimizes sum of
    % Euclidean distances to all points.  size(X) = [n, d, ...], where n is
    % the number of data points, d is the number of components for each point
    % and any additional array dimension is treated as independent sets of
    % data and a median is calculated for each element along those dimensions
    % sequentially; size(M) = [1, d, ...].  This is an approximate iterative
    % procedure that stops once the desired precision is achieved.  If
    % Precision is not provided, 1e-4 of the max distance from the centroid
    % is used.
    %
    % Weiszfeld's algorithm is used, which is a subgradient algorithm; with
    % (Verdi & Zhang 2001)'s modification to avoid non-optimal fixed points
    % (if at any iteration the approximation of M equals a data point).
    %
    %
    % © Copyright 2018 Marc Lalancette
    % The Hospital for Sick Children, Toronto, Canada
    %
    % This file is part of a free repository of Matlab tools for MEG
    % data processing and analysis <https://gitlab.com/moo.marc/MMM>.
    % You can redistribute it and/or modify it under the terms of the GNU
    % General Public License as published by the Free Software Foundation,
    % either version 3 of the License, or (at your option) a later version.
    %
    % This program is distributed WITHOUT ANY WARRANTY.
    % See the LICENSE file, or <http://www.gnu.org/licenses/> for details.
    %
    % 2012-05
    
    nDims = ndims(X);
    XSize = size(X);
    n = XSize(1);
    d = XSize(2);
    if nDims > 3
        nSets = prod(XSize(3:nDims));
        X = reshape(X, [n, d, prod(XSize(3:nDims))]);
    elseif nDims == 3
        nSets = XSize(3);
    else
        nSets = 1;
    end
    
    % For better stability, center and normalize the data.
    Centroid = mean(X, 1);
    Scale = max(max(abs(X), [], 1), [], 2); % [1, 1, nSets]
    Scale(Scale == 0) = 1;
    X = bsxfun(@rdivide, bsxfun(@minus, X, Centroid), Scale); % (X - Centroid(ones(n, 1), :, :)) ./ Scale(ones(n, 1), ones(d, 1), :);
    
    if ~exist('Precision', 'var') || isempty(Precision)
        Precision = 1e-4 * ones(1, 1, nSets);
    else
        Precision = bsxfun(@rdivide, Precision, Scale); % Precision ./ Scale; % [1, 1, nSets]
    end
    
    % Initial estimate: median in each dimension separately.  Though this
    % gives a chance of picking one of the data points, which requires
    % special treatment.
    M2 = median(X, 1);
    
    % It might be better to calculate separately each independent set,
    % otherwise, they are all iterated until the worst case converges.
    for s = 1:nSets
        
        % For convenience, pick another point far enough so the loop will always
        % start.
        M = bsxfun(@plus, M2(:, :, s), Precision(:, :, s));
        % Iterate.
        while  sum((M - M2(:, :, s)).^2 , 2) > Precision(s)^2  % any()scalar
            M = M2(:, :, s); % [n, d]
            % Distances from M.
            %       R = sqrt(sum( (M(ones(n, 1), :) - X(:, :, s)).^2 , 2 )); % [n, 1]
            R = sqrt(sum( bsxfun(@minus, M, X(:, :, s)).^2 , 2 )); % [n, 1]
            % Find data points not equal to M, that we use in the computation
            % below.
            Good = logical(R);
            nG = sum(Good);
            if nG % > 0
                %       D = sum( (M(ones(nG, 1), :) - X(Good, :, s)) ./ R(Good, ones(d, 1)) , 1 ); % [1, d, 1]
                D = sum( bsxfun(@rdivide, bsxfun(@minus, M, X(Good, :, s)), R(Good)) , 1 ); % [1, d, 1]
                %       DNorm = sqrt(sum( D.^2 , 2 )); % scalar
                %       W = sum(1 ./ R, 1); % scalar. Sum of "weights" (in one viewpoint of this problem).
            else % all points are in the same location
                % Above formula would give error due to second bsxfun on empty.
                D = 0;
            end
            
            % New estimate.
            % Note the possibility of D = 0 and (n - nG) = 0, in which case 0/0
            % should be 0, but here gives NaN, which the max function ignores,
            % returning 0 instead of 1. This is fine however since this
            % multiplies D (=0 in that case).
            M2(:, :, s) = M - max(0, 1 - (n - nG)/sqrt(sum( D.^2 , 2 ))) * ...
                D / sum(1 ./ R, 1);
        end
        
    end
    
    % Go back to original space and shape.
    %   M = M2 .* Scale(1, ones(d, 1), :) + Centroid;
    M = bsxfun(@times, M2, Scale) + Centroid;
    if nDims > 3
        M = reshape(M, [1, XSize(2:end)]);
    end
    
end % GeoMedian


