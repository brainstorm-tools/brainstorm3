function varargout = process_adjust_coordinates(varargin)
    % Adjust, recompute, or remove various coordinate transformations.
    
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
    % Authors: Marc Lalancette, 2018
    
    %   TO DO:
    % Are the head points kept in their original coordinate system or do they
    % follow the EEG transformations?  Not clear from channel_apply_transf.
    % Can test by applying/removing refine with head points (multiple times
    % if needed)
    %
    % Should we return all files or only the ones that were modified?
    %
    % BUG: when importing channel file, we get:
    % {'Dewar=>Native', 'Native=>Brainstorm/CTF', 'Native=>Brainstorm/CTF'}
    % But the second one is identity.
    
    eval(macro_method);
end



function sProcess = GetDescription() %#ok<DEFNU>
    % Description of the process
    sProcess.Comment     = 'Adjust coordinate transformations';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/CoordinateSystems';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 304;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Option [to do: ignore bad segments]
%     sProcess.options.warning.Comment = 'Only for CTF MEG recordings with HLC channels recorded.<BR><BR>';
%     sProcess.options.warning.Type    = 'label';
    sProcess.options.info.Comment = ['Order of coordinate system transformations: <BR>', ...
        'Dewar=>Native, AdjustedNative, Native=>Brainstorm/CTF, refine registration: head points'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.action.Type     = 'radio_label';
    sProcess.options.action.Comment  = {'Adjust head position to median location - CTF only (AdjustedNative).', ...
        'Remove head position adjustment (AdjustedNative).', ...
        'Compute Native to SCS/CTF transformation using digitized landmarks.', ...
        'Remove Native to SCS/CTF transformation.', ...
        'Refine MRI coregistration using digitized head points.', ...
        'Remove MRI coregistration refinement.'; ...
        'Adjust', 'UndoAdjust', 'SCS', 'UndoSCS', 'Refine', 'UndoRefine'};
    sProcess.options.action.Value    = 'Adjust';
    sProcess.options.display.Type    = 'checkbox';
    sProcess.options.display.Comment = 'Display "before" and "after" alignment figures.';
    sProcess.options.display.Value   = 1;
end



function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end



function OutputFiles = Run(sProcess, sInputs)
    
    isDisplay = sProcess.options.display.Value;
    nFiles = length(sInputs);
    
    isFileOk = false(1, nFiles);
    if isDisplay
        hFigAfter = [];
        hFigBefore = [];
        bst_memory('UnloadAll', 'Forced'); % Close all the existing figures. (Including progress?)
    end
    switch sProcess.options.action.Value
        case 'Adjust'
            bst_progress('start', 'Adjust head position', ...
                'Loading HLU locations...', 0, 2*nFiles);
            for iFile = 1:nFiles
                if isDisplay
                    % Display "before" results.
                    close([hFigBefore, hFigAfter]);
                    hFigBefore = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
                end
                
                % The data could be changed such that the head position
                % could be readjusted (e.g. by deleting segments).  This is
                % now allowed and the previous adjustment will be replaced.
                ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
                if any(strcmp(ChannelMat.TransfMegLabels, 'AdjustedNative'))
                    bst_report('Info', sProcess, sInputs(iFile), ...
                        'Head position already adjusted. Previous adjustment will be replaced.');
                    %                     fprintf('Head position already adjusted. Undo first if you wish to adjust again.\n');
                    %                     bst_progress('inc', 2);
                    %                     continue;
                end
                
                % Load head coil locations, in m.
                bst_progress('text', 'Loading HLU locations...');
                bst_progress('inc', 1);
                Locations = process_evt_head_motion('LoadHLU', sInputs(iFile), [], false);
                bst_progress('text', 'Correcting position...');
                bst_progress('inc', 1);
                % If a collection was aborted, the channels will be filled with
                % zeros. We must remove these locations.
                % This reshapes to continuous if in epochs, but works either way.
                Locations(:, all(Locations == 0, 1)) = [];
                
                MedianLoc = MedianLocation(Locations);
                %         disp(MedianLoc);
                
                % Also get the initial reference position.  We only use it to see
                % how much the adjustment moves.
                InitRefLoc = ReferenceHeadLocation(ChannelMat, sInputs(iFile));
                if isempty(InitRefLoc) 
                    % There was an error, already reported. Skip this file.
                    continue;
                end
                
                % Extract transformations that are applied before and after the
                % head position adjustment.  Any previous adjustment will be
                % ignored here and replaced later.
                [TransfBefore, TransfAdjust, TransfAfter, iAdjust, iDewToNat] = ...
                    GetTransforms(ChannelMat, sInputs(iFile));
                if isempty(TransfBefore) 
                    % There was an error, already reported. Skip this file.
                    continue;
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
                
                bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
                isFileOk(iFile) = true;
                
                if isDisplay
                    % Display "after" results, besides the "before" figure.
                    hFigAfter = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
                end
                
                % Give an idea of the distance we moved.
                AfterRefLoc = ReferenceHeadLocation(ChannelMat, sInputs(iFile));
                if isempty(AfterRefLoc) 
                    % There was an error, already reported. Skip this file.
                    continue;
                end
                DistanceAdjusted = process_evt_head_motion('RigidDistances', AfterRefLoc, InitRefLoc);
                fprintf('Head position adjusted by %1.1f mm.\n', DistanceAdjusted * 1e3);
                bst_report('Info', sProcess, sInputs(iFile), ...
                    sprintf('Head position adjusted by %1.1f mm.\n', DistanceAdjusted * 1e3));
                
            end % file loop
            bst_progress('stop');
            
        case 'SCS'
            bst_progress('start', 'Native to SCS/CTF transformation', ...
                'Loading data...', 0, 2*nFiles);
            for iFile = 1:nFiles
                if isDisplay
                    % Display "before" results.
                    close([hFigBefore, hFigAfter]);
                    hFigBefore = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
                end
                
                ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
                if any(strcmp(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF'))
                    bst_report('Info', sProcess, sInputs(iFile), ...
                        'Re-computing and replacing existing native to SCS/CTF transformation.');
                end
                
                % Find existing SCS transformation.
                % Otherwise look for head point refinment.
                
                % Load head coil locations, in m.
                bst_progress('text', 'Loading data...');
                bst_progress('inc', 1);
%                 Locations = process_evt_head_motion('LoadHLU', sInputs(iFile), [], false);
                bst_progress('text', 'Correcting position...');
                bst_progress('inc', 1);
                % If a collection was aborted, the channels will be filled with
                % zeros. We must remove these locations.
                % This reshapes to continuous if in epochs, but works either way.
                Locations(:, all(Locations == 0, 1)) = [];
                
                MedianLoc = MedianLocation(Locations);
                %         disp(MedianLoc);
                
                % Also get the initial reference position.  We only use it to see
                % how much the adjustment moves.
                InitRefLoc = ReferenceHeadLocation(ChannelMat, sInputs(iFile));
                if isempty(InitRefLoc) 
                    % There was an error, already reported. Skip this file.
                    continue;
                end
                
                % Extract transformations that are applied before and after the
                % head position adjustment.  Any previous adjustment will be
                % ignored here and replaced later.
                [TransfBefore, TransfAdjust, TransfAfter, iAdjust, iDewToNat] = ...
                    GetTransforms(ChannelMat, sInputs(iFile));
                if isempty(TransfBefore) 
                    % There was an error, already reported. Skip this file.
                    continue;
                end
                % Compute transformation corresponding to coil position.
                [TransfMat, TransfAdjust] = LocationTransform(MedianLoc, ...
                    TransfBefore, TransfAdjust, TransfAfter);
                % This TransfMat would automatically give an identity
                % transformation if the process is run multiple times, and
                % TransfAdjust would not change. 
                
                % This transformation applies to MEG, EEG and head points.
                iMeg = sort([good_channel(ChannelMat.Channel, [], 'MEG'), ...
                    good_channel(ChannelMat.Channel, [], 'MEG REF')]);
                iEeg = ;
                ChannelMat = channel_apply_transf(ChannelMat, TransfMat, [iMeg, iEeg], true); % Apply to head points.
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
                
                bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
                isFileOk(iFile) = true;
                
                if isDisplay
                    % Display "after" results, besides the "before" figure.
                    hFigAfter = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
                end
                
                % Give an idea of the distance we moved.
                AfterRefLoc = ReferenceHeadLocation(ChannelMat, sInputs(iFile));
                if isempty(AfterRefLoc) 
                    % There was an error, already reported. Skip this file.
                    continue;
                end
                DistanceAdjusted = process_evt_head_motion('RigidDistances', AfterRefLoc, InitRefLoc);
                fprintf('Head position adjusted by %1.1f mm.\n', DistanceAdjusted * 1e3);
                bst_report('Info', sProcess, sInputs(iFile), ...
                    sprintf('Head position adjusted by %1.1f mm.\n', DistanceAdjusted * 1e3));
                
            end % file loop
            bst_progress('stop');
            
        case {'UndoAdjust', 'UndoSCS', 'UndoRefine'}
            isHeadPoints = strcmp(sProcess.options.action.Value, {'UndoSCS', 'UndoRefine'});
            switch sProcess.options.action.Value
                case 'UndoAdjust'
                    TransfLabel = 'AdjustedNative';
                case 'UndoSCS'
                    TransfLabel = 'Native=>Brainstorm/CTF';
                case 'UndoRefine'
                    TransfLabel = 'refine registration: head points';
            end
            for iFile = 1:nFiles
                if isDisplay
                    % Display "before" results.
                    close([hFigBefore, hFigAfter]);
                    hFigBefore = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
                end
                ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
                
                
                Found = false;
                iUndo = find(strcmpi(ChannelMat.TransfMegLabels, TransfLabel), 1, 'last');
                if ~isempty(iUndo)
                    TransfAfter = eye(4);
                    for t = iUndo+1:numel(ChannelMat.TransfMeg)
                        TransfAfter = TransfAfter * ChannelMat.TransfMeg{t};
                    end
                    % Only remove the selected transform, reapply the following ones.
                    Transf = (TransfAfter / ChannelMat.TransfMeg{iUndo}) / TransfAfter; % T * inv(U) * inv(T), associativity is importanat here.
                    % Apply inverse transformation.
                    iChan = sort([good_channel(ChannelMat.Channel, [], 'MEG'), ...
                        good_channel(ChannelMat.Channel, [], 'MEG REF')]);
                    % Need to check for empty, otherwise applies to all channels!
                    if ~isempty(iChan)
                        ChannelMat = channel_apply_transf(ChannelMat, Transf, iChan, isHeadPoints);
                        ChannelMat = ChannelMat{1};
                    end
                    % Remove last tranformation we just added and the one it cancels.
                    ChannelMat.TransfMegLabels([iUndo, end]) = [];
                    ChannelMat.TransfMeg([iUndo, end]) = [];
                    Found = true;
                end
                
                % Redo for EEG.  Can't be certain that the following
                % transformations are the same, just do it independently.
                iUndo = find(strcmpi(ChannelMat.TransfEegLabels, TransfLabel), 1, 'last');
                if ~isempty(iUndo)
                    TransfAfter = eye(4);
                    for t = iUndo+1:numel(ChannelMat.TransfEeg)
                        TransfAfter = TransfAfter * ChannelMat.TransfEeg{t};
                    end
                    % Only remove the selected transform, reapply the following ones.
                    Transf = (TransfAfter / ChannelMat.TransfEeg{iUndo}) / TransfAfter; % T * inv(U) * inv(T), associativity is importanat here.
                    % Apply inverse transformation.
                    iChan = sort([good_channel(ChannelMat.Channel, [], 'EEG'), ...
                        good_channel(ChannelMat.Channel, [], 'SEEG'), ...
                        good_channel(ChannelMat.Channel, [], 'ECOG')]);
                    % Need to check for empty, otherwise applies to all channels!
                    if ~isempty(iChan)
                        % Don't apply the transformation twice to head points!
                        if Found % head points were done with MEG channels, if applicable.
                            ChannelMat = channel_apply_transf(ChannelMat, Transf, iChan, false);
                        else
                            ChannelMat = channel_apply_transf(ChannelMat, Transf, iChan, isHeadPoints);
                        end
                        ChannelMat = ChannelMat{1};
                    end
                    % Remove last tranformation we just added and the one it cancels.
                    ChannelMat.TransfEegLabels([iUndo, end]) = [];
                    ChannelMat.TransfEeg([iUndo, end]) = [];
                    Found = true;
                end
                
                if ~Found
                    bst_report('Warning', sprintf('Coordinate transformation not found for %s.\n', ...
                        sInputs(iFile).FileName));
                    continue;
                end
                
                bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
                
                isFileOk(iFile) = true;
                if isDisplay
                    % Display results.
                    hFigAfter = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
                end
            end
            
    end
    
    % Return the input files that were processed properly.
    OutputFiles = {sInputs(isFileOk).FileName};
end



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
        bst_report('Error', 'process_adjust_head_position', sInput, ...
            'Could not find required transformation.');
        InitLoc = [];
        return;
    end
    iAdjust = find(strcmpi(ChannelMat.TransfMegLabels, 'AdjustedNative'));
    if numel(iAdjust) > 1
        bst_report('Error', 'process_adjust_head_position', sInput, ...
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
end



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
        bst_report('Error', 'process_adjust_head_position', sInput, ...
            'Could not find required transformation.');
        return;
    end
    if iDewToNat > 1
        bst_report('Warning', 'process_adjust_head_position', sInput, ...
            'Unexpected transformations found before ''Dewar=>Native''; ignoring them.');
    end
    if numel(iAdjust) > 1
        bst_report('Error', 'process_adjust_head_position', sInput, ...
            'Could not find required transformation.');
        return;
    elseif isempty(iAdjust)
        iBef = iDewToNat;
        iAft = iDewToNat + 1;
        TransfAdjust = eye(4);
    else
        if iAdjust < iDewToNat
            bst_report('Error', 'process_adjust_head_position', sInput, ...
                'Unable to interpret order of transformations.');
            return;
        elseif iAdjust - iDewToNat > 1
            bst_report('Warning', 'process_adjust_head_position', sInput, ...
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
end



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
end



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


