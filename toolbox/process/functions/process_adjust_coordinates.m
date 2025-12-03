function varargout = process_adjust_coordinates(varargin)
% PROCESS_ADJUST_COORDINATES: Adjust, recompute, or remove various coordinate transformations, primarily for CTF MEG datasets.
% 
% Native coordinates are based on system fiducials (e.g. MEG head coils), whereas Brainstorm's SCS
% coordinates are based on the anatomical fiducial points. After alignment between MRI and
% headpoints, the anatomical fiducials on the MRI side define the SCS and the ones in the channel
% files (ChannelMat.SCS) are ignored.

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
% Authors: Marc Lalancette, 2018-2022

eval(macro_method);
end


function sProcess = GetDescription()
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
    % Option
    sProcess.options.reset.Type    = 'checkbox';
    sProcess.options.reset.Comment = 'Reset coordinates using original channel file (removes all adjustments: head, points, manual).';
    sProcess.options.reset.Value   = 0;
    sProcess.options.reset.Controller = 'Reset';
    % Need the file format for re-importing a channel file.
    FileFormatsChan = bst_get('FileFilters', 'channel');
    sProcess.options.format.Type = 'combobox';
    sProcess.options.format.Comment = 'For reset option, specify the channel file format:';
    sProcess.options.format.Value = {1, FileFormatsChan(:, 2)'};
    % sProcess.options.format.Class = 'Reset';
    sProcess.options.head.Type    = 'checkbox';
    sProcess.options.head.Comment = 'Adjust head position to median location - CTF only.';
    sProcess.options.head.Value   = 0;
    sProcess.options.head.Controller = 'Adjust';
    sProcess.options.bad.Type    = 'checkbox';
    sProcess.options.bad.Comment = 'For adjust option, exclude bad segments.';
    sProcess.options.bad.Value   = 1;
    sProcess.options.bad.Class   = 'Adjust';
    sProcess.options.points.Type    = 'checkbox';
    sProcess.options.points.Comment = 'Refine MRI coregistration using digitized head points.';
    sProcess.options.points.Value   = 0;
    sProcess.options.points.Controller = 'Refine';
    sProcess.options.tolerance.Comment = 'Tolerance (outlier points to ignore):';
    sProcess.options.tolerance.Type    = 'value';
    sProcess.options.tolerance.Value   = {0, '%', 0};
    sProcess.options.tolerance.Class = 'Refine';
    sProcess.options.scs.Type    = 'checkbox';
    sProcess.options.scs.Comment = 'Replace MRI nasion and ear points with digitized landmarks (cannot undo). <BR>Requires selecting channel file format above.';
    sProcess.options.scs.Value   = 0;
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
    OutputFiles = {};
    isDisplay = sProcess.options.display.Value;
    nInFiles = length(sInputs);
    
    isFileOk = false(1, nInFiles);
    if isDisplay
        hFigAfter = [];
        hFigBefore = [];
        bst_memory('UnloadAll', 'Forced'); % Close all the existing figures.
    end
    
    [~, iUniqFiles, iUniqInputs] = unique({sInputs.ChannelFile});
    nFiles = numel(iUniqFiles);
    
    % Special cases when replacing MRI fids: don't allow resetting or refining with head points,
    % probably a user mistake. Still possible if done in two separate calls. Adjusting head position
    % ignored with a warning only (would be lost anyway).
    % Also only a single channel file per subject is allowed.
    if ~sProcess.options.remove.Value && sProcess.options.scs.Value 
        % TODO: how to go back to process panel, like for missing TF options in some processes?
        if sProcess.options.reset.Value
            bst_report('Error', sProcess, sInputs, ...
                ['Incompatible options: "Reset coordinates" would be applied first and remove coregistration adjustments.' 10, ...
                '"Replace MRI landmarks" automatically resets all channel files for selected subject(s) after MRI update.']);
            return;
        end
        if sProcess.options.points.Value
            bst_report('Error', sProcess, sInputs, ...
                ['Incompatible options: "Refine with head points" not currently allowed in same call as' 10, ...
                '"Replace MRI landmarks" to avoid user error and possibly loosing manual coregistration adjustments.' 10, ...
                'If you really want to do this, run this process separately for each operation.']);
            return;
        end
        if sProcess.options.head.Value
            bst_report('Warning', sProcess, sInputs, ...
                ['Incompatible options: "Adjust head position" ignored since it would be lost after MRI update.' 10, ...
                '"Replace MRI landmarks" automatically resets all channel files for selected subject(s) after MRI update.']);
            sProcess.options.head.Value = 0;
        end

        % Check for multiple channel files per subject.
        UniqueSubs = unique({sInputs(iUniqFiles).SubjectFile});
        if numel(UniqueSubs) < nFiles
            bst_report('Error', sProcess, sInputs, ...
                '"Replace MRI landmarks" can only be run with a single channel file per subject.');
            return;
        end
    end

    if ~sProcess.options.remove.Value && sProcess.options.head.Value && nFiles < nInFiles
        bst_report('Info', sProcess, sInputs, ...
            'Multiple inputs were found for a single channel file. They will be concatenated for adjusting the head position.');
    end

    bst_progress('start', 'Adjust coordinate system', ' ', 0, nFiles);
    % If resetting, in case the original data moved, and because the same channel file may appear in
    % many places for processed data, keep track of user file selections.
    NewChannelFiles = cell(0, 2);
    for iFile = iUniqFiles(:)' % no need to repeat on same channel file.
        
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        % Get the leading modality
        [~, DispMod] = channel_get_modalities(ChannelMat.Channel);
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
            % The original goal of this option was to fix data affected by a previous bug while
            % keeping as much pre-processing that was previously done.  We re-import the channel
            % file, and copy the projectors (and history) from the old one.
            
            [ChannelMat, NewChannelFiles, isError] = ResetChannelFile(ChannelMat, ...
                NewChannelFiles, sInputs(iFile), sProcess);
            if isError
                continue;
            end
            
            % ----------------------------------------------------------------
        elseif sProcess.options.remove.Value
            % Because channel_align_manual does not consistently apply the manual transformation to
            % all sensors or save it in both TransfMeg and TransfEeg, it could lead to confusion and
            % errors when playing with transforms.  Therefore, if we detect a difference between the
            % MEG and EEG transforms when trying to remove one that applies to both (currently only
            % refine with head points), we don't proceed and recommend resetting with the original
            % channel file instead.
            
            Which = {};
            if sProcess.options.head.Value
                Which{end+1} = 'AdjustedNative'; %#ok<AGROW> 
            end
            if sProcess.options.points.Value
                Which{end+1} = 'refine registration: head points'; %#ok<AGROW> 
            end
            
            for TransfLabel = Which
                TransfLabel = TransfLabel{1}; %#ok<FXSET> 
                ChannelMat = RemoveTransformation(ChannelMat, TransfLabel, sInputs(iFile), sProcess);
            end % TransfLabel loop

            % We cannot change back the MRI fiducials, but in order to be able to update it again
            % from digitized fids without warnings, edit the MRI history.
            if sProcess.options.scs.Value
                % Get subject in database, with subject directory
                sSubject = bst_get('Subject', sInputs(iFile).SubjectFile);
                MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
                % Slightly change the string we use to verify if it was done: append " (hidden)".
                iHist = find(strcmpi(sMri.History(:,3), 'Applied digitized anatomical fiducials'));
                if ~isempty(iHist)
                    for iH = 1:numel(iHist)
                        sMri.History{iHist(iH),3} = [sMri.History{iHist(iH),3}, ' (hidden)'];
                    end
                    try
                        bst_save(file_fullpath(MriFile), sMri, 'v7');
                    catch
                        bst_report('Error', sProcess, sInputs(iFile), ...
                            sprintf('Unable to save MRI file %s.', MriFile));
                        continue;
                    end
                end
            end
            
        end % reset channel file or remove transformations
        
        % ----------------------------------------------------------------
        if ~sProcess.options.remove.Value && sProcess.options.head.Value
            % Complex indexing to get all inputs for this same channel file.
            [ChannelMat, isError] = AdjustHeadPosition(ChannelMat, ...
                sInputs(iUniqInputs == iUniqInputs(iFile)), sProcess);
            if isError
                continue;
            end
        end % adjust head position
        
        % ----------------------------------------------------------------
        if ~sProcess.options.remove.Value && sProcess.options.points.Value
            % Redundant, but makes sense to have it here also.
            
            bst_progress('text', 'Fitting head surface to points...');
            % If called externally without a tolerance value, set isWarning true so it asks.
            if isempty(sProcess.options.tolerance.Value)
                isWarning = true;
                Tolerance = 0;
            else
                isWarning = false;
                Tolerance = sProcess.options.tolerance.Value{1} / 100;
            end
            [ChannelMat, ~, ~, isSkip, isUserCancel, strReport] = channel_align_auto(sInputs(iFile).ChannelFile, ...
                ChannelMat, isWarning, 0, Tolerance); % No confirmation
            % ChannelFile needed to find subject and scalp surface, but not used otherwise when
            % ChannelMat is provided.
            if ~isempty(strReport)
                bst_report('Info', sProcess, sInputs(iFile), strReport);
            elseif isSkip
                bst_report('Warning', sProcess, sInputs(iFile), ...
                    'Refine registration using head points, failed finding a better fit.');
                continue;
            elseif isUserCancel
                bst_report('Info', sProcess, sInputs(iFile), 'User cancelled registration with head points.');
                continue
            end
            
        end % refine registration with head points
        
        % ----------------------------------------------------------------
        % Save channel file. 
        % Before potiential MRI update since that function takes ChannelFile, not ChannelMat.
        bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
        
        % ----------------------------------------------------------------
        if ~sProcess.options.remove.Value && sProcess.options.scs.Value
            % This is now a subfunction in this process
            [~, isCancel, isError] = channel_align_scs(sInputs(iFile).ChannelFile, eye(4), ...
                false, false, sInputs(iFile), sProcess); % interactive warnings but no confirmation
            % Head surface was unloaded from memory, in case we want to display "after" figure.
            % TODO Maybe modify like channel_align_auto to take in and return ChannelMat.
            if isError
                return;
            elseif isCancel 
                continue;
            end
            % If something happened and channel files were not reset, there was a pop-up error and
            % we'll just let the user deal with it for now (i.e. try again to reset the channel file).
             
            % TODO Verify
        end

        % ----------------------------------------------------------------
        isFileOk(iFile) = true;

        if isDisplay && ~isempty(Modality)
            % Display "after" results, besides the "before" figure.
            hFigAfter = channel_align_manual(sInputs(iFile).ChannelFile, Modality, 0);
        end
        
    end % file loop
    bst_progress('stop');
    
    % Return the input files that were processed properly.  Include those that were removed due to
    % sharing a channel file, where appropriate. The complicated indexing picks the first input of
    % those with the same channel file, i.e. the one that was marked ok.
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


function [ChannelMat, NewChannelFiles, isError] = ResetChannelFile(ChannelMat, NewChannelFiles, sInput, sProcess)
    % Reload a channel file, but keep projectors and history. First look for original file from
    % history, and if it's no longer there, user will be prompted. User selections are noted as
    % pairs {old, new} in NewChannelFiles for potential reuse (e.g. same original data at multiple
    % pre-processing steps).
    % This function does not save the file, but only returns the updated structure.
    if nargin < 4 || isempty(sProcess)
        sProcess = [];
        isReport = false;
    else
        isReport = true;
    end
    if nargin < 3
        sInput = [];
    end
    if nargin < 2 || isempty(NewChannelFiles)
        NewChannelFiles = cell(0,2);
    end
    isError = false;
    bst_progress('text', 'Importing channel file...');
    % Extract original data file from channel file history.
    if any(size(ChannelMat.History) < [1, 3]) || ~strcmp(ChannelMat.History{1, 2}, 'import')
        NotFound = true;
        ChannelFile = '';
    else
        ChannelFile = regexp(ChannelMat.History{1, 3}, '(?<=: )(.*)(?= \()', 'match');
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
            if isReport
                bst_report('Info', sProcess, sInput, ...
                    sprintf('Using channel file in new location: %s.', ChannelFile));
            end
        end
    end
    if isfield(sProcess, 'options') && isfield(sProcess.options, 'format')
        FileFormatsChan = bst_get('FileFilters', 'channel');
        FileFormat = FileFormatsChan{sProcess.options.format.Value{1}, 3};
    else
        FileFormat = [];
    end
    if NotFound
        if isReport
            bst_report('Info', sProcess, sInput, ...
                sprintf('Could not find original channel file: %s.', ChannelFile));
        end
        % import_channel will prompt the user, but they would not know which file to pick!  And
        % prompt is modal for Matlab, so likely can't look at command window (e.g. if Brainstorm is
        % in front). So add another pop-up with the needed info.
        [ChanPath, ChanName, ChanExt] = fileparts(ChannelFile);
        MsgFig = msgbox(sprintf('Select the new location of channel file %s %s to reset %s.', ...
            ChanPath, [ChanName, ChanExt], sInput.ChannelFile), ...
            'Reset channel file', 'replace');
        movegui(MsgFig, 'north');
        figure(MsgFig); % bring it to front.
        % Adjust default format to the one selected.
        if ~isempty(FileFormat)
            DefaultFormats = bst_get('DefaultFormats');
            DefaultFormats.ChannelIn = FileFormat;
            bst_set('DefaultFormats',  DefaultFormats);
        end
        
        [NewChannelMat, NewChannelFile] = import_channel(sInput.iStudy, '', FileFormat, 0, 0, 0, [], []);
    else
        
        % Import from original file.
        [NewChannelMat, NewChannelFile] = import_channel(sInput.iStudy, ChannelFile, FileFormat, 0, 0, 0, [], 0);
        % iStudies, ChannelFile, FileFormat, ChannelReplace, ChannelAlign, isSave, isFixUnits, isApplyVox2ras)
        % iStudy index is needed to avoid error for noise recordings with missing SCS transform.
        % ChannelReplace is for replacing the file, only if isSave.
        % ChannelAlign is for headpoints, but also ONLY if isSave.  We do it later if user selected.
        % isApplyVox2ras should be false to avoid the pop-up asking if we want to use the MRI world
        % transformation even before checking for digitized fids (it would then apply MRI world > MRI vox > MRI SCS).
    end
    
    % See if it worked.
    if isempty(NewChannelFile)
        if isReport
            bst_report('Error', sProcess, sInput, 'No channel file selected.');
        else
            bst_error('No channel file selected.');
        end
        isError = true;
        return;
    elseif isempty(NewChannelMat)
        if isReport
            bst_report('Error', sProcess, sInput, sprintf('Unable to import channel file: %s', NewChannelFile));
        else
            bst_error(sprintf('Unable to import channel file: %s', NewChannelFile));
        end
        isError = true;
        return;
    elseif numel(NewChannelMat.Channel) ~= numel(ChannelMat.Channel)
        if isReport
            bst_report('Error', sProcess, sInput, ...
                'Original channel file has different channels than current one, aborting.');
        else
            bst_error('Original channel file has different channels than current one, aborting.');
        end
        isError = true;
        return;
    elseif NotFound && ~isempty(ChannelFile)
        % Save the selected new location.
        NewChannelFiles(end+1, :) = {ChannelFile, NewChannelFile};
    end
    % Copy the old projectors and history to the new structure.
    NewChannelMat.Projector = ChannelMat.Projector;
    NewChannelMat.History = ChannelMat.History;
    ChannelMat = NewChannelMat;

    % Add number of channels to comment, like in db_set_channel.
    ChannelMat.Comment = [ChannelMat.Comment, sprintf(' (%d)', length(ChannelMat.Channel))];
    % Add history
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
        % Note: NIRS doesn't have a separate set of transformations, but "refine" and "SCS" are
        % applied to NIRS as well.
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


function [ChannelMat, isError] = AdjustHeadPosition(ChannelMat, sInputs, sProcess)
    isError = false;
    % Check the input is CTF.
    isRaw = (length(sInputs(1).FileName) > 9) && ~isempty(strfind(sInputs(1).FileName, 'data_0raw'));
    if isRaw
        DataMat = in_bst_data(sInputs(1).FileName, {'Device', 'F'});
    else
        DataMat = in_bst_data(sInputs(1).FileName, {'Device', 'Events', 'Time'});
    end
    if ~strcmp(DataMat.Device, 'CTF')
        bst_report('Error', sProcess, sInputs, ...
            'Adjust head position is currently only available for CTF data.');
        isError = true;
        return;
    end
    
    % The data could be changed such that the head position could be readjusted (e.g. by deleting
    % segments).  This is allowed and the previous adjustment will be replaced.
    if isfield(ChannelMat, 'TransfMegLabels') && iscell(ChannelMat.TransfMegLabels) && ...
            ismember('AdjustedNative', ChannelMat.TransfMegLabels)
        bst_report('Info', sProcess, sInputs, ...
            'Head position already adjusted. Previous adjustment will be replaced.');
    end
    
    % Load head coil locations, in m.
    bst_progress('text', 'Loading head coil locations...');
    %                 bst_progress('inc', 1);

    % A trial marked as bad is excluded from the process file selection box.
    % Loop over trial data files for the same channel file.
    Locations = [];
    for iIn = 1:numel(sInputs)
        [Locs, HeadSamplePeriod] = process_evt_head_motion('LoadHLU', sInputs(iIn), [], false);
        if isempty(Locs)
            % No HLU channels. Error already reported. Skip this file.
            isError = true;
            return;
        end
        % Exclude all bad segments.
        if sProcess.options.bad.Value
            if isRaw
                DataMat = in_bst_data(sInputs(iIn).FileName, {'F'});
                DataMat = DataMat.F;
            else
                DataMat = in_bst_data(sInputs(iIn).FileName, {'Events', 'Time'});
                DataMat.events = DataMat.Events;
                DataMat.prop.sfreq = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
                DataMat.prop.times = DataMat.Time([1, end]);
            end
            [BadSegments, BadEpoch] = panel_record('GetBadSegments', DataMat); % samples that correspond to times
            if ~isempty(BadSegments)
                % Shift so first sample is 1.
                BadSegments = BadSegments - DataMat.prop.sfreq * DataMat.prop.times(1) + 1;
                % Convert bad samples to continuous (non-epoched) sample indices, but rounding up
                % the number of samples per epoch to an integer multiple of HeadSamplePeriod.
                SampleBounds = round(DataMat.prop.times .* DataMat.prop.sfreq); % This is single epoch samples if epoched.
                nSamplesPerEpoch = SampleBounds(2) - SampleBounds(1) + 1;
                nSamplesPerEpoch = ceil(nSamplesPerEpoch/HeadSamplePeriod) * HeadSamplePeriod;
                [nChannels, nHeadSamples, nEpochs] = size(Locs);
                Locs = reshape(Locs, nChannels, []);
                % "Real" (but rounded up per epoch) sample indices of (downsampled) head samples.
                iHeadSamples = 1 + ((1:(nHeadSamples*nEpochs)) - 1) * HeadSamplePeriod; % first is 1
                iBad = [];
                for iSeg = 1:size(BadSegments, 2)
                    iBad = [iBad, nSamplesPerEpoch * (BadEpoch(1,iSeg) - 1) + (BadSegments(1,iSeg):BadSegments(2,iSeg))]; %#ok<AGROW>
                    % iBad = [iBad, find((DataMat.Time >= badTimes(1,iSeg)) & (DataMat.Time <= badTimes(2,iSeg)))];
                end
                % Exclude bad samples.
                Locs(:, ismember(iHeadSamples, iBad)) = [];
            end
        end
        Locations = [Locations, Locs]; %#ok<AGROW> 
    end
    
    % If a collection was aborted, the channels will be filled with zeros. Remove these.
    Locations(:, all(Locations == 0, 1)) = []; % (This reshapes to continuous.)
    
    bst_progress('text', 'Correcting head position...');
    MedianLoc = MedianLocation(Locations);
    if isempty(MedianLoc)
        isError = true;
        return;
    end
    %         disp(MedianLoc);
    
    % Also get the initial reference position.  We only use it to estimate how much the adjustment moves.
    InitRefLoc = ReferenceHeadLocation(ChannelMat, sInputs);
    if isempty(InitRefLoc)
        % There was an error, already reported. Skip this file.
        isError = true;
        return;
    end
    
    % Extract transformations that are applied before and after the head position adjustment.  Any
    % previous adjustment will be ignored here and replaced later.
    [TransfBefore, TransfAdjust, TransfAfter, iAdjust, iDewToNat] = ...
        GetTransforms(ChannelMat, sInputs);
    if isempty(TransfBefore)
        % There was an error, already reported. Skip this file.
        isError = true;
        return;
    end
    % Compute transformation corresponding to coil position.
    [TransfMat, TransfAdjust] = LocationTransform(MedianLoc, ...
        TransfBefore, TransfAdjust, TransfAfter);
    % This TransfMat would automatically give an identity transformation if the process is run
    % multiple times, and TransfAdjust would not change.
    
    % Apply this transformation to the current head position. This is a correction to the
    % 'Dewar=>Native' transformation so it applies to MEG channels only and not to EEG or head
    % points, which start in Native.
    iMeg  = sort([good_channel(ChannelMat.Channel, [], 'MEG'), ...
        good_channel(ChannelMat.Channel, [], 'MEG REF')]);
    ChannelMat = channel_apply_transf(ChannelMat, TransfMat, iMeg, false); % Don't apply to head points.
    ChannelMat = ChannelMat{1};
    
    % After much thought, it was decided to save this adjustment transformation separately and at
    % its logical place: between 'Dewar=>Native' and 'Native=>Brainstorm/CTF'.  In particular, this
    % allows us to use it directly when displaying head motion distance. This however means we must
    % correctly move the transformation from the end where it was just applied to its logical place.
    % This "moved" transformation is also computed in LocationTransform above.
    if isempty(iAdjust)
        iAdjust = iDewToNat + 1;
        % Shift transformations to make room for the new adjustment, and reject the last one, that
        % we just applied.
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
    AfterRefLoc = ReferenceHeadLocation(ChannelMat, sInputs);
    if isempty(AfterRefLoc)
        % There was an error, already reported. Skip this file.
        isError = true;
        return;
    end
    DistanceAdjusted = process_evt_head_motion('RigidDistances', AfterRefLoc, InitRefLoc);
    fprintf('Head position adjusted by %1.1f mm.\n', DistanceAdjusted * 1e3);
    bst_report('Info', sProcess, sInputs, ...
        sprintf('Head position adjusted by %1.1f mm.', DistanceAdjusted * 1e3));
end % AdjustHeadPosition


function [InitLoc, Message] = ReferenceHeadLocation(ChannelMat, sInput)
    % Compute initial head location in Dewar coordinates.
    
    % Here we want to recreate the correct triangle shape from the relative head coil locations and
    % in the position saved as the reference (initial) head position according to Brainstorm
    % coordinate transformation matrices.
    
    if nargin < 2
        sInput = [];
    elseif numel(sInput) > 1
        sInput = sInput(1);
    end
    Message = '';

    % From recent investigations, digitized locations are probably not as robust/accurate as those
    % measured by the MEG. So use the .hc positions if available.
    if ~isempty(sInput) && isfield(sInput, 'header') && isfield(sInput.header, 'hc') && isfield(sInput.header.hc, 'SCS') && ...
            all(isfield(sInput.header.hc.SCS, {'NAS','LPA','RPA'})) && length(sInput.header.hc.SCS.NAS) == 3
        % Initial head coil locations from the CTF .hc file, but in dewar coordinates, NOT in SCS coordinates!
        InitLoc = [sInput.header.hc.SCS.NAS(:), sInput.header.hc.SCS.LPA(:), sInput.header.hc.SCS.RPA(:)]; % 3x3 by columns
        InitLoc = InitLoc(:);
        return;
        % ChannelMat.SCS are not the coil positions in the .hc file, which are not saved in Brainstorm,
        % but the digitized coil positions, if present. However, both are saved in "Native" coordinates
        % and thus give the same transformation.
    elseif isfield(ChannelMat, 'SCS') && all(isfield(ChannelMat.SCS, {'NAS','LPA','RPA'})) && ...
            (length(ChannelMat.SCS.NAS) == 3) && (length(ChannelMat.SCS.LPA) == 3) && (length(ChannelMat.SCS.RPA) == 3)
        %         % Use the SCS distances from origin, with left and right PA points symmetrical.
        %         LeftRightDist = sqrt(sum((ChannelMat.SCS.LPA - ChannelMat.SCS.RPA).^2));
        %         NasDist = ChannelMat.SCS.NAS(1);
        InitLoc = [ChannelMat.SCS.NAS(:), ChannelMat.SCS.LPA(:), ChannelMat.SCS.RPA(:); ones(1, 3)];
    else
        % Just use some reasonable distances, with a warning.
        Message = 'Exact reference head coil locations not available. Using reasonable (adult) locations according to head position.';
        LeftRightDist = 0.14;
        NasDist = 0.10;
        InitLoc = [[NasDist; 0; 0; 1], [0; LeftRightDist/2; 0; 1], [0; -LeftRightDist/2; 0; 1]];
    end
    % InitLoc above is in Native coordiates (if pre head loc didn't fail).
    % Bring it back to Dewar coordinates to compare with HLU channels.
    %
    % Take into account if the initial/reference head position was "adjusted", i.e. replaced by the
    % median position throughout the recording.  If so, use all transformations from 'Dewar=>Native'
    % to this adjustment transformation.  (In practice there shouldn't be any between them.)
    [TransfBefore, TransfAdjust] = GetTransforms(ChannelMat, sInput);
    InitLoc = TransfBefore \ (TransfAdjust \ InitLoc);
    InitLoc(4, :) = [];
    InitLoc = InitLoc(:);
end % ReferenceHeadLocation


function [TransfBefore, TransfAdjust, TransfAfter, iAdjust, iDewToNat] = GetTransforms(ChannelMat, sInputs)
    % Extract transformations that are applied before and after the head position adjustment we are
    % creating now.  We keep the 'Dewar=>Native' transformation intact and separate from the
    % adjustment for no deep reason, but it is the only remaining trace of the initial head coil
    % positions in Brainstorm.
    
    % The reason this function was split from LocationTransform is that it can be called only once
    % outside the head sample loop in process_sss, whereas LocationTransform is called many times
    % within the loop.
    
    % When this is called from process_sss, we are possibly working on a second head adjustment,
    % this time based on the instantaneous head position, so we need to keep the global adjustment
    % based on the entire recording if it is there.
    
    if nargin < 2
        sInputs = [];
    end
    % Check order of transformations.  These situations should not happen unless there was some
    % manual editing.
    iDewToNat = find(strcmpi(ChannelMat.TransfMegLabels, 'Dewar=>Native'));
    iAdjust = find(strcmpi(ChannelMat.TransfMegLabels, 'AdjustedNative'));
    TransfBefore = [];
    TransfAfter = [];
    TransfAdjust = [];
    if isempty(iDewToNat)
        bst_report('Warning', 'process_adjust_coordinates', sInputs, ...
            'Missing ''Dewar=>Native'' transformation; adjustment will start from dewar coordinates.');
        iDewToNat = 0;
    end
    if iDewToNat > 1
        bst_report('Warning', 'process_adjust_coordinates', sInputs, ...
            'Unexpected transformations found before ''Dewar=>Native''; perhaps channel file should be reset.');
    end
    if numel(iAdjust) > 1 || numel(iDewToNat) > 1
        bst_report('Error', 'process_adjust_coordinates', sInputs, ...
            'Multiple identical transformations found: channel file should be reset.');
        return;
    elseif isempty(iAdjust)
        iBef = iDewToNat;
        iAft = iDewToNat + 1;
        TransfAdjust = eye(4);
    else
        if iAdjust < iDewToNat
            bst_report('Error', 'process_adjust_coordinates', sInputs, ...
                'Unable to interpret order of transformations: channel file should be reset.');
            return;
        elseif iAdjust - iDewToNat > 1
            bst_report('Warning', 'process_adjust_coordinates', sInputs, ...
                'Unexpected transformations found between ''Dewar=>Native'' and ''AdjustedNative''; perhaps channel file should be reset.');
        end
        iBef = iAdjust - 1;
        iAft = iAdjust + 1;
        TransfAdjust = ChannelMat.TransfMeg{iAdjust};
    end
    
    TransfBefore = eye(4);
    if iBef > 0
        % Now starting from 1st transformation, even if not Dewar=>Native.
        for t = 1:iBef
            TransfBefore = ChannelMat.TransfMeg{t} * TransfBefore;
        end
    end
    TransfAfter = eye(4);
    for t = iAft:numel(ChannelMat.TransfMeg)
        TransfAfter = ChannelMat.TransfMeg{t} * TransfAfter;
    end
end % GetTransforms


function [TransfMat, TransfAdjust] = LocationTransform(Loc, TransfBefore, TransfAdjust, TransfAfter)
    % Compute transformation corresponding to head coil positions. We want this to be as efficient
    % as possible, since used many times by process_sss.
    
    % Check for previous version.
    if nargin < 4
        error('Missing inputs.');
    end
    
    % Transformation matrices are in m, as are HLU channels.
    %
    % The HLU channels (here Loc) are in dewar coordinates.  Bring them to the current system by
    % applying all saved transformations, starting with 'Dewar=>Native'.  This will save us from
    % having to use inverse transformations later.
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
    
    % TransfMat at this stage is a transformation from the current system back to the now adjusted
    % Native system.  We thus need to reapply the following tranformations.
    
    if nargout > 1
        % Transform from non-adjusted native coordinates to newly adjusted native coordinates.  To
        % be saved in channel file between "Dewar=>Native" and "Native=>Brainstorm/CTF".
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
        MedianLoc = [];
        return;
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
    % Calculate the geometric median: the point that minimizes sum of Euclidean distances to all
    % points.  size(X) = [n, d, ...], where n is the number of data points, d is the number of
    % components for each point and any additional array dimension is treated as independent sets of
    % data and a median is calculated for each element along those dimensions sequentially; size(M)
    % = [1, d, ...].  This is an approximate iterative procedure that stops once the desired
    % precision is achieved.  If Precision is not provided, 1e-4 of the max distance from the
    % centroid is used.
    %
    % Weiszfeld's algorithm is used, which is a subgradient algorithm; with (Verdi & Zhang 2001)'s
    % modification to avoid non-optimal fixed points (if at any iteration the approximation of M
    % equals a data point).
    %
    % Marc Lalancette 2012-05
    
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
    
    % Initial estimate: median in each dimension separately.  Though this gives a chance of picking
    % one of the data points, which requires special treatment.
    M2 = median(X, 1);
    
    % It might be better to calculate separately each independent set, otherwise, they are all
    % iterated until the worst case converges.
    for s = 1:nSets
        
        % For convenience, pick another point far enough so the loop will always start.
        M = bsxfun(@plus, M2(:, :, s), Precision(:, :, s));
        % Iterate.
        while  sum((M - M2(:, :, s)).^2 , 2) > Precision(s)^2  % any()scalar
            M = M2(:, :, s); % [n, d]
            % Distances from M.
            %       R = sqrt(sum( (M(ones(n, 1), :) - X(:, :, s)).^2 , 2 )); % [n, 1]
            R = sqrt(sum( bsxfun(@minus, M, X(:, :, s)).^2 , 2 )); % [n, 1]
            % Find data points not equal to M, that we use in the computation below.
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
            %
            % Note the possibility of D = 0 and (n - nG) = 0, in which case 0/0 should be 0, but
            % here gives NaN, which the max function ignores, returning 0 instead of 1. This is fine
            % however since this multiplies D (=0 in that case).
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


function [AlignType, isMriUpdated, isMriMatch, isSessionMatch, ChannelMat] = CheckPrevAdjustments(ChannelMat, sMri)
    % Flag if auto or manual registration performed, and if MRI fids updated. Print to command
    % window for now, if no output arguments. Also make sure to update ChannelMat.SCS if outputting
    % ChannelMat.
    AlignType = [];
    isMriUpdated = [];
    isMriMatch = [];
    isSessionMatch = [];
    isPrint = nargout == 0;
    if any(~isfield(ChannelMat, {'History', 'HeadPoints'}))
        % Nothing to check.
        return;
    end
    if nargin < 2 || isempty(sMri) || ~isfield(sMri, 'History') || isempty(sMri.History)
        iMriHist = [];
    else
        % History string is set in figure_mri SaveMri.
        iMriHist = find(strcmpi(sMri.History(:,3), 'Applied digitized anatomical fiducials'), 1, 'last');
    end
    % Can also be reset, so check for 'import' action and ignore previous alignments.
    iImport = find(strcmpi(ChannelMat.History(:,2), 'import'));
    iAlign = find(strcmpi(ChannelMat.History(:,2), 'align'));
    iAlign(iAlign < iImport(end)) = [];
    if numel(iImport) > 1
        AlignType = 'none/reset';
    else
        AlignType = 'none';
    end
    while ~isempty(iAlign)
        % Check which adjustment was done last.
        switch lower(ChannelMat.History{iAlign(end),3}(1:5))
            case 'remov' % ['Removed transform: ' TransfLabel]
                % Removed a previous step. Ignore corresponding adjustment and look again.
                if strncmpi(ChannelMat.History{iAlign(end),3}(20:24), 'AdjustedNative', 5)
                    iAlignRemoved = find(cellfun(@(c)strcmpi(c(1:5), 'added'), ChannelMat.History(iAlign,3)), 1, 'last');
                elseif strncmpi(ChannelMat.History{iAlign(end),3}(20:24), 'refine registration: head points', 5)
                    iAlignRemoved = find(cellfun(@(c)strcmpi(c(1:5), 'refin'), ChannelMat.History(iAlign,3)), 1, 'last');
                elseif strncmpi(ChannelMat.History{iAlign(end),3}(20:24), 'manual correction', 5)
                    iAlignRemoved = find(cellfun(@(c)strcmpi(c(1:5), 'align'), ChannelMat.History(iAlign,3)), 1, 'last');
                else
                    bst_error('Unrecognized removed transformation in history.');
                    return;
                end
                iAlign(end) = [];
                if isempty(iAlignRemoved)
                    bst_error('Missing removed transformation in history.');
                    return;
                else
                    iAlign(iAlignRemoved) = [];
                end
            case 'added' % 'Added adjustment to Native coordinates based on median head position' 
                % This alignment is between points and functional dataset, ignore here.
                iAlign(end) = [];
            case 'refin' % 'Refining the registration using the head points:' 
                % Automatic MRI-points alignment
                AlignType = 'auto';
                break;
            case 'align' % 'Align channels manually:'
                % Manual MRI-points alignment
                AlignType = 'manual';
                break;
            case 'non-l' % 'Non-linear transformation'
                AlignType = 'non-linear';
                break;
            otherwise
                AlignType = 'unrecognized';
                break;
        end
    end
    if isPrint
        disp(['BST> Previous registration adjustment: ' AlignType]);
    end
    if ~isempty(iMriHist)
        isMriUpdated = true;
        % Compare digitized fids to MRI fids (in MRI coordinates, mm). ChannelMat.SCS fids are NOT
        % kept up to date when adjusting registration (manual or auto), so get them from head points
        % again.
        % Get the three fiducials in the head points
        ChannelMat = UpdateChannelMatScs(ChannelMat);
        % Check if coordinates differ by more than 1 um.
        if isempty(ChannelMat.SCS.NAS) || isempty(ChannelMat.SCS.LPA) || isempty(ChannelMat.SCS.RPA) 
            isMriMatch = false;
            isSessionMatch = false;
            if isPrint
                disp('BST> MRI fiducials previously updated, but different session than current (missing) digitized fiducials.');
            end
        elseif any(abs(sMri.SCS.NAS - cs_convert(sMri, 'scs', 'mri', ChannelMat.SCS.NAS) .* 1000) > 1e-3) || ...
                any(abs(sMri.SCS.LPA - cs_convert(sMri, 'scs', 'mri', ChannelMat.SCS.LPA) .* 1000) > 1e-3) || ...
                any(abs(sMri.SCS.RPA - cs_convert(sMri, 'scs', 'mri', ChannelMat.SCS.RPA) .* 1000) > 1e-3)
            isMriMatch = false;
            % Check if just different alignment, or if different set of fiducials (different
            % session), using inter-fid distances.
            DiffMri = [sMri.SCS.NAS - sMri.SCS.LPA, sMri.SCS.LPA - sMri.SCS.RPA, sMri.SCS.RPA - sMri.SCS.NAS];
            DiffChannel = [ChannelMat.SCS.NAS - ChannelMat.SCS.LPA, ChannelMat.SCS.LPA - ChannelMat.SCS.RPA, ChannelMat.SCS.RPA - ChannelMat.SCS.NAS];
            if any(abs(DiffMri - DiffChannel) > 1e-3)
                isSessionMatch = false;
                if isPrint
                    disp('BST> MRI fiducials previously updated, but different session than current digitized fiducials.');
                end
            else
                isSessionMatch = true;
                if isPrint
                    disp('BST> MRI fiducials previously updated, same session but not aligned with current digitized fiducials.');
                end
            end
        else
            isMriMatch = true;
            isSessionMatch = true;
            if isPrint
                disp('BST> MRI fiducials previously updated, and match current digitized fiducials.');
            end
        end
    else
        if nargout > 4
            % Update SCS for consistency.
            % Get the three fiducials in the head points
            ChannelMat = UpdateChannelMatScs(ChannelMat);
        end
        isMriUpdated = false;
        isMriMatch = false;
        isSessionMatch = false;
    end
end


function [DistHead, DistSens, Message] = CheckCurrentAdjustments(ChannelMat, ChannelMatRef)
    % Display max displacement from registration adjustments, in command window.
    % If second ChannelMat is provided as reference, get displacement between the two.
    isPrint = nargout == 0;
    if nargin < 2 || isempty(ChannelMatRef)
        ChannelMatRef = [];
    end

    % Update SCS from head points if present.
    ChannelMat = UpdateChannelMatScs(ChannelMat);

    if ~isempty(ChannelMatRef)
        ChannelMatRef = UpdateChannelMatScs(ChannelMatRef);
        % For head displacement, we use the "rigid distance" from the head motion code, basically
        % the max distance of any point on a simplified spherical head.
        DistHead = process_evt_head_motion('RigidDistances', ...
            [ChannelMat.SCS.NAS(:); ChannelMat.SCS.LPA(:); ChannelMat.SCS.RPA(:)], ...
            [ChannelMatRef.SCS.NAS(:); ChannelMatRef.SCS.LPA(:); ChannelMatRef.SCS.RPA(:)]);
        DistSens = max(sqrt(sum(([ChannelMat.Channel.Loc] - [ChannelMatRef.Channel.Loc]).^2)));
    else
        % Implicitly using actual (MRI) SCS as reference, this includes all adjustments.
        DistHead = process_evt_head_motion('RigidDistances', ...
            [ChannelMat.SCS.NAS(:); ChannelMat.SCS.LPA(:); ChannelMat.SCS.RPA(:)]);
        % Get equivalent transform for all adjustments to "undo" on sensors for comparison. The
        % adjustments we want come after 'Native=>Brainstorm/CTF'
        iNatToScs = find(strcmpi(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF'));
        if iNatToScs < numel(ChannelMat.TransfMeg)
            Transf = eye(4);
            for t = iNatToScs+1:numel(ChannelMat.TransfMeg)
                Transf = ChannelMat.TransfMeg{t} * Transf;
            end
            Loc = [ChannelMat.Channel.Loc];
            % Inverse transf: subtract translation first, then rotate the "other way" (transpose).
            LocRef = Transf(1:3,1:3)' * bsxfun(@minus, Loc, Transf(1:3,4));
            DistSens = max(sqrt(sum((Loc - LocRef).^2)));
        else
            DistSens = 0;
        end
    end

    Message = sprintf('BST> Max displacement for registration adjustment:\n    head: %1.1f mm\n    sensors: %1.1f cm\n', ...
            DistHead*1000, DistSens*100);
    if isPrint
        fprintf(Message);
    end

end


function ChannelMat = UpdateChannelMatScs(ChannelMat)
    % Update the coordinates of the digitized anatomical fiducials in the channel SCS field, after
    % potentially having edited the coregistration such that these points no longer define the SCS
    % for the functional data - it's still defined by the MRI anatomical fiducials.
    if ~isfield(ChannelMat, 'HeadPoints')
        return;
    end
    % Get the three anatomical fiducials in the head points
    iNas = find(strcmpi(ChannelMat.HeadPoints.Label, 'Nasion') | strcmpi(ChannelMat.HeadPoints.Label, 'NAS'));
    iLpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'Left')   | strcmpi(ChannelMat.HeadPoints.Label, 'LPA'));
    iRpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'Right')  | strcmpi(ChannelMat.HeadPoints.Label, 'RPA'));
    if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
        ChannelMat.SCS.NAS = mean(ChannelMat.HeadPoints.Loc(:,iNas)', 1); %#ok<*UDIM> 
        ChannelMat.SCS.LPA = mean(ChannelMat.HeadPoints.Loc(:,iLpa)', 1);
        ChannelMat.SCS.RPA = mean(ChannelMat.HeadPoints.Loc(:,iRpa)', 1);
        % The SCS.R, T and Origin fields no longer have any use, except for missing digitized fids
        % (see below), but keep them updated always for consistency.
        [~, ChannelMat] = cs_compute(ChannelMat, 'scs');
    end
    % Do the same with head coils, used when exporting coregistration to BIDS
    % Also, if only the head coils were digitized and no anatomical points, use these as SCS, which
    % is what Brainstorm will implicitly use as SCS coordinates to align with the MRI anyway.
    iHpiN = find(strcmpi(ChannelMat.HeadPoints.Label, 'HPI-N'));
    iHpiL = find(strcmpi(ChannelMat.HeadPoints.Label, 'HPI-L'));
    iHpiR = find(strcmpi(ChannelMat.HeadPoints.Label, 'HPI-R'));
    if ~isempty(iHpiN) && ~isempty(iHpiL) && ~isempty(iHpiR)
        % Temporarily put the head coils there to calculate transform.
        ChannelMat.Native.NAS = mean(ChannelMat.HeadPoints.Loc(:,iHpiN)', 1);
        ChannelMat.Native.LPA = mean(ChannelMat.HeadPoints.Loc(:,iHpiL)', 1);
        ChannelMat.Native.RPA = mean(ChannelMat.HeadPoints.Loc(:,iHpiR)', 1);
        % Get "current" SCS to Native transformation.
        TmpChanMat = ChannelMat;
        TmpChanMat.SCS = ChannelMat.Native;
        % cs_compute doesn't change coordinates, only adds the R,T,Origin fields
        % Digitized points are normally saved in Native coordinates, and converted to SCS if anat
        % fids present. This transformation would then go back from SCS to Native.
        [~, TmpChanMat] = cs_compute(TmpChanMat, 'scs');
        ChannelMat.Native = TmpChanMat.SCS;
        % If SCS missing (no anat points), Native matches SCS. Explicitly save SCS, which is missing
        % from initial import.
        if ~isfield(ChannelMat, 'SCS') || ~isfield(ChannelMat.SCS, 'NAS') || isempty(ChannelMat.SCS.NAS)
            ChannelMat.SCS = ChannelMat.Native;
        else
            % Now apply the transform to the digitized anat fiducials. These are not used anywhere yet,
            % only the transform, but might as well be consistent and save the same points as in .SCS
            % (digitized anat fids). Still in meters, not cm, despite actual native CTF being in cm.
            ChannelMat.Native.NAS(:) = [ChannelMat.Native.R, ChannelMat.Native.T] * [ChannelMat.SCS.NAS'; 1];
            ChannelMat.Native.LPA(:) = [ChannelMat.Native.R, ChannelMat.Native.T] * [ChannelMat.SCS.LPA'; 1];
            ChannelMat.Native.RPA(:) = [ChannelMat.Native.R, ChannelMat.Native.T] * [ChannelMat.SCS.RPA'; 1];
        end
    else
        if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
            % Missing digitized MEG head coils, probably the anatomical points are actually coils.
            % No study, subject or file name available to print here.
            disp('BST> Missing digitized MEG head coils (in channel file), assuming NAS/LPA/RPA are actually head coils, but they should be renamed.');
            ChannelMat.Native = ChannelMat.SCS;
        else
            ChannelMat.Native.R = [];
            ChannelMat.Native.T = [];
            disp('BST> No digitized fiducials, neither anatomical nor MEG head coils.');
        end
    end
end


% Decided to bring this back as subfunction of this process, as it is the only place to run it from for now.
function [Transform, isCancel, isError] = channel_align_scs(ChannelFile, Transform, isInteractive, isConfirm, sInput, sProcess)
% CHANNEL_ALIGN_SCS: Saves new MRI anatomical points after manual or auto registration adjustment.
%
% USAGE:  Transform = channel_align_scs(ChannelFile, Transform=eye(4), isInteractive=1, isConfirm=1)
%
% DESCRIPTION: 
%       After modifying registration between digitized head points and MRI (with "refine with head
%       points" or manually), this function allows saving the change in the MRI fiducials so that
%       they exactly match the digitized anatomical points (nasion and ears). This would replace
%       having to save a registration adjustment transformation for each functional dataset sharing
%       this set of digitized points. This affects all files registered to the MRI and should
%       therefore be done as one of the first steps after importing, and with only one set of
%       digitized points (one session). Surfaces are adjusted to maintain alignment with the MRI.
%       Additional sessions for the same Brainstorm subject, with separate digitized points, will
%       still need the usual "per dataset" registration adjustment to align with the same MRI.
%
%       This function will not modify an MRI that it changed previously without user confirmation
%       (if both isInteractive and isConfirm are false). In that case, Transform is returned unaltered.
%
% INPUTS:
%     - ChannelFile : Channel file to align with its anatomy
%     - Transform   : Transformation matrix from digitized SCS coordinates to MRI SCS coordinates, 
%                     after some alignment is made (auto or manual) and the two no longer match.
%                     This transform should not already be saved in the ChannelFile, though the
%                     file may already contain similar adjustments, in which case Transform would be
%                     an additional adjustment to add. (This will typically be empty or identity, it
%                     was intended for calling from manual alignment panel, but now done after.)
%     - isInteractive : If true, display dialog in case of errors, or if this was already done 
%                     previously for this MRI. 
%     - isConfirm   : If true, ask the user for confirmation before proceeding.
%
% OUTPUTS:
%     - Transform   : If the MRI fiducial points and coordinate system are updated, the transform 
%                     becomes the identity. If the MRI was not updated, the input Transform is
%                     returned. The idea is that the returned Transform applied to the *reset*
%                     channels would maintain the registration. If channel files were not reset
%                     (error or cancellation in this function), this will no longer be true and the
%                     user should verify the registration of all affected studies.
%     - isCancel    : If true, nothing was changed nor saved.
%     - isError     : An error occurred that can affect registration of MRI and functional studies,
%                     e.g. the MRI was updated, but some channel files of that subject were not
%                     reset.

% The Transform output is currently unused. It was changed (below is the previous behavior) since it
% depended on CTF MEG specific transform labels.
%     - Transform   : If the MRI fiducial points and coordinate system are updated, and the channel 
%                     file is reset, the transform becomes the identity. If the channel file is not
%                     reset, Transform will be the inverse of all previous manual or automatic
%                     adjustments. If the MRI was not updated, the input Transform is returned. The
%                     idea is that the returned Transform applied to the channels would maintain the
%                     registration.

% Authors: Marc Lalancette 2022-2025

if nargin < 6 || isempty(sProcess)
    isReport = false;
else
    isReport = true;
end
if nargin < 4 || isempty(isConfirm)
    isConfirm = true;
end
if nargin < 3 || isempty(isInteractive)
    isInteractive = true;
end
if nargin < 2 || isempty(Transform)
    Transform = eye(4);
end
if nargin < 1 || isempty(ChannelFile)
    bst_error('ChannelFile argument required.');
end

isError = false;
isCancel = false;
% Get study
sStudy = bst_get('ChannelFile', ChannelFile);
% Get subject
sSubject = bst_get('Subject', sStudy.BrainStormSubject);
% Check if default anatomy.
if sSubject.UseDefaultAnat
    Message = 'Digitized nasion and ear points cannot be applied to default anatomy.';
    if isReport
        bst_report('Error', sProcess, sInput, Message);
    elseif isInteractive
        bst_error(Message, 'Apply digitized anatomical fiducials to MRI', 0);
    else
        disp(['BST> ' Message]);
    end
    isCancel = true;
    return;
end
% Get Channels
ChannelMat = in_bst_channel(ChannelFile);

% Check if digitized anat points present, saved in ChannelMat.SCS.
% Note that these coordinates are NOT currently updated when doing refine with head points (below).
% They are in "initial SCS" coordinates, updated in channel_detect_type.
if ~all(isfield(ChannelMat.SCS, {'NAS','LPA','RPA'})) || ~(length(ChannelMat.SCS.NAS) == 3) || ~(length(ChannelMat.SCS.LPA) == 3) || ~(length(ChannelMat.SCS.RPA) == 3)
    Message = 'Digitized nasion and ear points not found.';
    if isReport
        bst_report('Error', sProcess, sInput, Message);
    elseif isInteractive
        bst_error(Message, 'Apply digitized anatomical fiducials to MRI', 0);
    else
        disp(['BST> ' Message]);
    end
    isCancel = true;
    return;
end

% Check if already adjusted
sMriOld = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
% This Check function also updates ChannelMat.SCS with the saved (possibly previously adjusted) head
% points IF isMriUpdated. (We don't consider isMriMatch here because we still have to apply the
% provided Transformation.)
[~, isMriUpdated, ~, ~, ChannelMat] = CheckPrevAdjustments(ChannelMat, sMriOld);
% Get user confirmation
if isMriUpdated
    % Already done previously.
    if isInteractive || isConfirm
        % Request confirmation.
        [Proceed, isCancel] = java_dialog('confirm', ['The MRI fiducial points NAS/LPA/RPA were previously updated from a set of' 10 ...
            'aligned digitized points. Updating them again will break any previous alignment' 10 ...
            'with other sets of digitized points and associated functional datasets.' 10 10 ...
            'Proceed and overwrite previous alignment?' 10], 'Head points/anatomy registration');
        if ~Proceed || isCancel
            isCancel = true;
            return;
        end
    else
        % Do not proceed.
        Message = 'Digitized nasion and ear points previously applied to this MRI. Not applying again.';
        if isReport
            bst_report('Warning', sProcess, sInput, Message);
        else
            disp(['BST> ' Message]);
        end
        isCancel = true;
        return;
    end
elseif isConfirm
    % Request confirmation.
    [Proceed, isCancel] = java_dialog('confirm', ['Updating the MRI fiducial points NAS/LPA/RPA to match a set of' 10 ...
        'aligned digitized points is mainly used for exporting registration to a BIDS dataset.' 10 ...
        'It will break any previous alignment of this subject with all other functional datasets!' 10 10 ...
        'Proceed and update MRI now?' 10], 'Head points/anatomy registration');
    if ~Proceed || isCancel
        isCancel = true;
        return;
    end
end
%% TEMPORARY BYPASS OF EEG POP-UP
if isConfirm 
% If EEG, warn that only linear transformation would be saved this way.
if ~isempty([good_channel(ChannelMat.Channel, [], 'EEG'), good_channel(ChannelMat.Channel, [], 'SEEG'), good_channel(ChannelMat.Channel, [], 'ECOG')])
    [Proceed, isCancel] = java_dialog('confirm', ['Updating the MRI fiducial points NAS/LPA/RPA will only save' 10 ...
        'global rotations and translations. Any other changes to EEG channels will be lost.' 10 10 ...
        'Proceed and update MRI now?' 10], 'Head points/anatomy registration');
    if ~Proceed || isCancel
        isCancel = true;
        return;
    end
end
end

% Convert digitized fids to MRI SCS coordinates.
% Here, ChannelMat.SCS already may contain some auto/manual adjustment, and we're adding a new one (possibly identity).
% Apply the transformation provided.
sMri = sMriOld;
% Intermediate step, these are not valid coordinates for sMri.
sMri.SCS.NAS = (Transform(1:3,:) * [ChannelMat.SCS.NAS'; 1])';
sMri.SCS.LPA = (Transform(1:3,:) * [ChannelMat.SCS.LPA'; 1])';
sMri.SCS.RPA = (Transform(1:3,:) * [ChannelMat.SCS.RPA'; 1])';
% Then convert to MRI coordinates (mm), this is how sMri.SCS is saved.
% cs_convert mri is in meters
sMri.SCS.NAS = cs_convert(sMriOld, 'scs', 'mri', sMri.SCS.NAS) .* 1000;
sMri.SCS.LPA = cs_convert(sMriOld, 'scs', 'mri', sMri.SCS.LPA) .* 1000;
sMri.SCS.RPA = cs_convert(sMriOld, 'scs', 'mri', sMri.SCS.RPA) .* 1000;
% Re-compute transformation in this struct, which goes from MRI to SCS (but the fids stay in MRI coords in this struct).
[~, sMri] = cs_compute(sMri, 'scs');

% Compare with existing MRI fids, replace if changed (> 1um), and update surfaces.
sMri.FileName = sSubject.Anatomy(sSubject.iAnatomy).FileName;
figure_mri('SaveMri', sMri);
% At minimum, we must unload surfaces that have been modified, but we want to avoid closing figures
% for when we show "before" and "after" figures.
bst_memory('UnloadAll'); % not 'forced' so won't close figures, but won't unload what we want most likely.
bst_memory('UnloadSurface'); % this unloads the head surface as we want.
% Now that MRI is saved, update Transform to identity.
Transform = eye(4);

% MRI SCS now matches digitized-points-defined SCS (defined from same points), but registration is
% now broken with all channel files that were adjusted! Reset channel file, and all others for this
% anatomy.
isError = ResetChannelFiles(ChannelMat, sSubject, isConfirm, sInput, sProcess);

% Removed this output Transform for now as GetTransform only works on CTF MEG data and the rest of
% this function can work more generally.
% if isError
%     % Get the equivalent overall registration adjustment transformation previously saved.
%     [~, ~, TransfAfter] = GetTransforms(ChannelMat);
%     % Return its inverse as it's now part of the MRI and should be removed from the channel file.
%     Transform = inverse(TransfAfter);
% else
%     Transform = eye(4);
% end

end % main function

% (This function was based on channel_align_manual CopyToOtherFolders).
function [isError, Message] = ResetChannelFiles(ChannelMatSrc, sSubject, isConfirm, sInput, sProcess)
    if nargin < 5 || isempty(sProcess)
        sProcess = [];
        isReport = false;
    else
        isReport = true;
    end
    % Confirmation: ask the first time 
    if nargin < 3 || isempty(isConfirm)
        isConfirm = true;
    end

    NewChannelFiles = cell(0,2);
    % First, always reset the "source" channel file.
    [ChannelMatSrc, NewChannelFiles, isError] = ResetChannelFile(ChannelMatSrc, NewChannelFiles, sInput, sProcess);
    if isError
        Message = sprintf(['Unable to reset channel file for subject: %s\n' ...
            'MRI registration for all their functional studies should be verified!'], sSubject.Name);
        if isReport
            bst_report('Error', sProcess, sInput, Message);
        end
        % This is very important so always show it interactively.
        java_dialog('msgbox', Message);
        return;
    end
    bst_save(file_fullpath(sInput.ChannelFile), ChannelMatSrc, 'v7');

    % If the subject is configured to share its channel files, nothing to do
    if (sSubject.UseDefaultChannel >= 1)
        return;
    end
    % Get all the dependent studies
    sStudies = bst_get('StudyWithSubject', sSubject.FileName);
    % List of channel files to update
    ChannelFiles = {};
    % Loop on the other folders
    for i = 1:length(sStudies)
        % Skip studies without channel files
        if isempty(sStudies(i).Channel) || isempty(sStudies(i).Channel(1).FileName)
            continue;
        end
        % Add channel file to list of files to process
        ChannelFiles{end+1} = sStudies(i).Channel(1).FileName; %#ok<AGROW>
    end
    % Unique files and skip "source".
    ChannelFiles = setdiff(unique(ChannelFiles), sInput.ChannelFile);
    if ~isempty(ChannelFiles)
        % Ask confirmation to the user
        if isConfirm
            Proceed = java_dialog('confirm', ...
                sprintf('Reset all %d other channel files for this subject (typically recommended)?', numel(ChannelFiles)), 'Reset channel files');
            if ~Proceed
                Message = sprintf(['User cancelled resetting %d other channel files for subject: %s\n' ...
                    'MRI registration for all functional studies should be verified!'], numel(ChannelFiles), sSubject.Name);
                if isReport
                    bst_report('Warning', sProcess, sInput, Message);
                else
                    java_dialog('msgbox', Message);
                end
                return;
            end
        end
        % Progress bar
        bst_progress('start', 'Reset channel files', 'Updating other studies...');
        strMsg = [sInput.ChannelFile 10];
        strErr = '';
        for iChan = 1:numel(ChannelFiles)
            ChannelFile = ChannelFiles{iChan};
            % Load channel file
            ChannelMat = in_bst_channel(ChannelFile);
            % Reset & save
            % Need correct sInput for each study here, not the "source" study. Only 3 fields used.
            [sStudyTmp, iStudy] = bst_get('ChannelFile', ChannelFile);
            sInputTmp.FileName = sStudyTmp(1).Data.FileName; % for report only
            sInputTmp.iStudy = iStudy; % this is the study getting reset
            sInputTmp.ChannelFile = ChannelFile; % this is the file being read
            [ChannelMat, NewChannelFiles, isError] = ResetChannelFile(ChannelMat, NewChannelFiles, sInputTmp, sProcess);
            if isError
                strErr = [strErr ChannelFile 10]; %#ok<AGROW>
            else
                strMsg = [strMsg ChannelFile 10]; %#ok<AGROW>
                bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
            end
        end
        bst_progress('stop');
        % Give report to the user
        if ~isempty(strErr)
                Message = sprintf(['Unable to reset channel file(s) for subject %s:\n%s\n' ...
                    'MRI registration should be verified for these studies!'], sSubject.Name, strErr);
                if isReport
                    bst_report('Error', sProcess, sInput, Message);
                end
                % This is very important so always show it interactively.
                java_dialog('msgbox', Message);
                return;
        end
        Message = sprintf('%d channel files reset for subject %s:\n%s', numel(ChannelFiles)+1, sSubject.Name, strMsg);
        if isReport
            bst_report('Info', sProcess, sInput, Message);
        elseif isConfirm
            java_dialog('msgbox', Message);
        else
            disp(Message);
        end
    end
end

