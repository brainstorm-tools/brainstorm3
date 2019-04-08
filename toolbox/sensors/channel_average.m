function [MeanChannelMat, Message] = channel_average(ChannelMats, iStudies, Method)
    % CHANNEL_AVERAGE: Averages positions of MEG/EEG sensors.
    %
    % INPUT:
    %     - ChannelMats: Cell array of channel.mat structures
    %     - iStudies: Array of indices of input studies
    %     - Method: 'common', 'all' (default), or 'first'
    % OUPUT:
    %     - MeanChannelMat: Average channel mat
    
    % @=============================================================================
    % This function is part of the Brainstorm software:
    % https://neuroimage.usc.edu/brainstorm
    %
    % Copyright (c)2000-2019 University of Southern California & McGill University
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
    % Authors: Francois Tadel 2012-2018, Marc Lalancette 2019
    
    % To do: reorder the channels in 'all' method.
    
    if nargin < 3 || isempty(Method)
        Method = 'all';
    end
    if nargin < 2 || isempty(iStudies)
        iStudies = [];
    elseif numel(iStudies) ~= numel(ChannelMats)
        Message = 'Error: iStudies should be same length as ChannelMats';
        MeanChannelMat = [];
        return
    end
    Message = [];
    
    nFiles = numel(ChannelMats);
    MeanChannelMat = ChannelMats{1};
    if ~isempty(iStudies) && numel(unique(iStudies)) == 1
        % Only one input, no need to process further.
        return;
    end
    
    switch lower(Method)
        case 'common'
            % Find common channels from all files.
            for i = 1:nFiles
                if i == 1
                    KeepChans = {ChannelMats{i}.Channel.Name};
                else
                    KeepChans = intersect(KeepChans, {ChannelMats{i}.Channel.Name}, 'stable');
                end
            end
            [Unused, iMean, iChans] = intersect(KeepChans, {MeanChannelMat.Channel.Name}, 'stable'); % Stable keeps the order of CommonChans.
            MeanChannelMat.Channel = MeanChannelMat.Channel(:, iChans);
        case 'all'
            % Find all channels from all files.
            for i = 1:nFiles
                if i == 1
                    KeepChans = {ChannelMats{i}.Channel.Name};
                else
                    % Union can order sorted or 'stable' which is all 1
                    % then new 2.  Ideally we'd want the new 2 to be in
                    % their "normal" spot. (To do)
                    %                     nChans = numel(KeepChans);
                    [KeepChans, Unused, iNew] = union(KeepChans, {ChannelMats{i}.Channel.Name}, 'stable');
                    %                     nNew = numel(iNew);
                    %                     for n = 1:nNew
                    %                         iBef =
                    %                     end
                    if ~isempty(iNew)
                        
                        iMeg = find(strcmp({ChannelMats{i}.Channel.Type}, 'MEG'));
                        [Unused, iMegNew] = ismember(iNew, iMeg);
                        % iiMeg is zero for non-matches. Get actual indices of new MEG channels.
                        iMegNew(iMegNew == 0) = [];
                        if ~isempty(iMegNew)
                            % Add CTF compensation coefs for new channels if same number of references (actual same set confirmed later).
                            if size(MeanChannelMat.MegRefCoef, 2) == size(ChannelMats{i}.MegRefCoef, 2)
                                MeanChannelMat.MegRefCoef = [MeanChannelMat.MegRefCoef; ChannelMats{i}.MegRefCoef(iMegNew, :)];
                                % else we'll just remove it later.
                            end
                            % Convert location and orientation of new MEG channels to 1st file coordinates.
                            % They will be changed to an average location later. 
                            TransfMeg = eye(4);
                            if isfield(MeanChannelMat, 'TransfMeg')
                                for t = 1:numel(MeanChannelMat.TransfMeg)
                                    TransfMeg = MeanChannelMat.TransfMeg{t} * TransfMeg;
                                end
                            end
                            if isfield(ChannelMats{i}, 'TransfMeg')
                                for t = 1:numel(ChannelMats{i}.TransfMeg)
                                    TransfMeg = TransfMeg / MeanChannelMat.TransfMeg{t};
                                end
                            end
                            tempChannelMat = channel_apply_transf(ChannelMats{i}, TransfMeg, iMegNew, false);
                            MeanChannelMat.Channel = [MeanChannelMat.Channel, tempChannelMat{1}.Channel(iMegNew)];
                        end
                        MeanChannelMat.Channel = [MeanChannelMat.Channel, ChannelMats{i}.Channel(setdiff(iNew, iMegNew))];
                    end
                end
            end
        case 'first'
            KeepChans = {ChannelMats{1}.Channel.Name};
        otherwise
            error('Unrecognized method, should be ''all'', ''common'' or ''first''.');
    end
    
    nChan = numel(MeanChannelMat.Channel);
    if nChan == 0
        Message = ['The channels files from the different studies do not have any channels in common.' 10 ...
            'Cannot create a common channel file.'];
        MeanChannelMat = [];
        return;
    end
        
    iMeg = find(strcmp({MeanChannelMat.Channel.Type}, 'MEG'));
    iRef = find(strcmp({MeanChannelMat.Channel.Type}, 'MEG REF'));
    iMegRef = sort([iMeg, iRef]);
    
    % Update channel number in comment
    if nChan ~= numel(ChannelMats{1}.Channel) % The one we copied.
        iComment = find(MeanChannelMat.Comment == '(', 1, 'last');
        if ~isempty(iComment)
            MeanChannelMat.Comment(iComment:end) = '';
        end
        MeanChannelMat.Comment = sprintf('%s (%d)', MeanChannelMat.Comment, numel(KeepChans));
    end
        
    % Update MegRefCoef (only kept if reference channels are identical in all files)
    if numel(iMeg) && numel(iRef)
        if size(MeanChannelMat.MegRefCoef, 2) ~= numel(iRef)
            % Can't merge coefficients if different reference sets.
            MeanChannelMat.MegRefCoef = [];
        elseif size(MeanChannelMat.MegRefCoef, 1) ~= numel(iMeg) % Only for 'common' method
            iRemove = setdiff(iMeg, iChans);
            if ~isempty(iRemove)
                [Unused, iMegNew] = ismember(iRemove, iMeg);
                MeanChannelMat.MegRefCoef(iMegNew, :) = [];
            end
        end
    else
        % Just get rid of it.
        MeanChannelMat.MegRefCoef = [];
    end
        
    % Either we don't know the source studies, or we know there are more than 1.
    % Discard projectors.
    MeanChannelMat.Projector(:) = []; % Keeps empty structure
    % New history.
    MeanChannelMat = bst_history('reset', MeanChannelMat);
    MeanChannelMat = bst_history('add',  MeanChannelMat,  'average', ...
        sprintf('Created by channel_average, from %d input files (incl. possible duplicates).', nFiles));
    % List of distinct averaged files added to history below, if we have iStudies.
    
    % Find subjects
    if ~isempty(iStudies)
        iSubjects = zeros(nFiles, 1);
        for i = 1:nFiles
            [isFound, iFoundFile] = ismember(iSubjects(i), iSubjects(1:i-1));
            if isFound
                iSubjects(i) = iSubjects(iFoundFile);
            else
                sStudy = bst_get('Study', iStudies(i));
                [Unused, iSubjects(i)] = bst_get('Subject', sStudy.BrainStormSubject);
                MeanChannelMat = bst_history('add', MeanChannelMat, 'average', [' - ' sStudy.Channel.FileName]);
            end
        end
    end
    if isempty(iStudies) || numel(unique(iSubjects)) > 1
        % Discard head points.
        MeanChannelMat.HeadPoints.Loc = [];
        MeanChannelMat.HeadPoints.Label = {};
        MeanChannelMat.HeadPoints.Type = {};
    end

    % --------------------------------------------------------------------
    % For MEG, best to "average" 'Dewar=>Native' transformation.  Applies
    % directly to MEG and reference channels, all integration points.  Warn if
    % missing or unusual transformations, but shouldn't happen.
    if ~isempty(iMegRef)
        BrainOrigin = zeros(nFiles, 3);
        for i = 1:nFiles
            if ~isempty(iStudies)
                [isFound, iFoundFile] = ismember(iSubjects(i), iSubjects(1:i-1));
                if isFound
                    BrainOrigin(i, :) = BrainOrigin(iFoundFile, :);
                else
                    sSubject = bst_get('Subject', iSubjects(i));
                    %             [sCortex, iSurface] = bst_get('SurfaceFileByType', iSubject, 'Cortex'); % Doesn't contain the surface data.
                    if ~isempty(sSubject.iCortex) && ~isempty(sSubject.Surface(sSubject.iCortex).FileName)
                        sCortex = in_tess_bst(sSubject.Surface(sSubject.iCortex).FileName, 0);
                        BrainOrigin(i, :) = mean(sCortex.Vertices, 1);
                    else
                        BrainOrigin(i, :) = [1, 0, 6] ./ 100; % in m
                    end
                end
            else
                BrainOrigin(i, :) = [1, 0, 6] ./ 100; % in m
            end
        end
        
        TransfMeg = cell(0);
        isWarnTransfOrder = false;
        for i = 1:nFiles
            iTransf = find(strcmpi(ChannelMats{i}.TransfMegLabels, 'Dewar=>Native'), 1, 'first');
            if ~isempty(iTransf)
                if iTransf ~= 1
                    isWarnTransfOrder = true;
                end
                TransfMeg{end+1} = ChannelMats{i}.TransfMeg{iTransf};
            end
        end
        if isWarnTransfOrder
            if ~isempty(Message)
                Message = [Message, '\n'];
            end
            Message = [Message, 'Unexpected MEG transformation order; MEG channel positions may be wrong.'];
        end
        nAvg = numel(TransfMeg);
        if nAvg < nFiles && ~isempty(Message)
            Message = [Message, '\n'];
        end
        if nAvg == 0
            % Not sure if this is possible, but would be ok if the channels are
            % still in dewar coordinates; no averaging required.
            Message = [Message, 'No Dewar=>Native transformation found; MEG channel positions not averaged.'];
            TransfMeg = eye(4);
        else
            if nAvg < nFiles
                Message = [Message, 'Missing Dewar=>Native transformations; MEG channel positions not fully averaged.'];
            end
            % Optimal position and orientation average (without shrinkage),
            % centered on brain origin.
            TransfMeg = PositionAverage(TransfMeg, BrainOrigin);
            iTransf = find(strcmpi(MeanChannelMat.TransfMegLabels, 'Dewar=>Native'), 1, 'first');
            if isempty(iTransf)
                OldTransf = eye(4);
                % Insert at first position, though this is unusual especially
                % if there are other transf.
                MeanChannelMat.TransfMegLabels = [{'Dewar=>Native'}, MeanChannelMat.TransfMegLabels];
                MeanChannelMat.TransfMeg = [{TransfMeg}, MeanChannelMat.TransfMeg];
                iTransf = 1;
            else
                OldTransf = MeanChannelMat.TransfMeg{iTransf};
                MeanChannelMat.TransfMeg{iTransf} = TransfMeg;
            end
            TransfMeg = TransfMeg / OldTransf;
            % Combine with all subsequent transf for applying later.
            for iTr = iTransf+1:numel(MeanChannelMat.TransfMeg)
                % Remove first (right), reapply last (left).
                TransfMeg = MeanChannelMat.TransfMeg{iTr} * TransfMeg / MeanChannelMat.TransfMeg{iTr};
            end
        end
        
        % Apply to channel locations and orientations.
        MeanChannelMat = channel_apply_transf(MeanChannelMat, TransfMeg, iMegRef, false);
        MeanChannelMat = MeanChannelMat{1};
        % Remove last tranformation we just added, it's already in the new 'Dewar=>Native'.
        MeanChannelMat.TransfMeg(end) = [];
        MeanChannelMat.TransfMegLabels(end) = [];
    end
    
    % --------------------------------------------------------------------
    % For other channels, average positions and orientations, but correct
    % distances to avoid "shrinkage" towards origin.  (Could use brain center
    % again here.)
    nAvg = zeros(1, nChan);
    Dist = cell(nChan, 1);
    % Keep channel location sizes, but initialize sums to zero.
    for iChan = setdiff(1:nChan, iMegRef) 
        % If the channel has no location, skip.
        if ~isempty(MeanChannelMat.Channel(iChan).Loc)
            MeanChannelMat.Channel(iChan).Loc(:) = 0; 
            MeanChannelMat.Channel(iChan).Orient(:) = 0; 
            Dist{iChan} = zeros(1, size(MeanChannelMat.Channel(iChan).Loc, 2));
        end
    end
    
    for i = 1:nFiles
        %         % Check number of channels
        %         if numel(ChannelMats{i}.Channel) ~= nChan
        %             Message = ['The channels files from the different studies do not have the same number of channels.' 10 ...
        %                 'Cannot create a common channel file.'];
        %             MeanChannelMat = [];
        %             return;
        %         end
        
        % Match channels by name.
        [Unused, iMean, iChans] = intersect(KeepChans, {ChannelMats{i}.Channel.Name}, 'stable'); % Stable keeps the order of CommonChans.
        
        % Sum EEG channel locations
        [Unused, iiChan] = setdiff(iMean', iMegRef);
        for c = iiChan'
            % If the channel has no location in this file: skip
            if isempty(ChannelMats{i}.Channel(iChans(c)).Loc)
                continue;
                % Check the size of Loc matrix and the values of Weights matrix
            elseif isempty(MeanChannelMat.Channel(iChans(c)).Loc)
                MeanChannelMat.Channel(iMean(c)).Loc = ChannelMats{i}.Channel(iChans(c)).Loc;
                Dist{iMean(c)} = sqrt(sum(ChannelMats{i}.Channel(iChans(c)).Loc.^2, 1));
                MeanChannelMat.Channel(iMean(c)).Orient = ChannelMats{i}.Channel(iChans(c)).Orient;
                nAvg(iMean(c)) = nAvg(iMean(c)) + 1;
            elseif ~isequal(size(MeanChannelMat.Channel(iMean(c)).Loc), size(ChannelMats{i}.Channel(iChans(c)).Loc))
                Message = ['A channel does not have the same location structure between studies.' 10 ...
                    'Cannot create a common channel file.'];
                MeanChannelMat = [];
                return;
            else
                % Sum with existing average
                MeanChannelMat.Channel(iMean(c)).Loc = MeanChannelMat.Channel(iMean(c)).Loc + ChannelMats{i}.Channel(iChans(c)).Loc;
                % Also sum distances from origin.
                Dist{iMean(c)} = Dist{iMean(c)} + sqrt(sum(ChannelMats{i}.Channel(iChans(c)).Loc.^2, 1));
                MeanChannelMat.Channel(iMean(c)).Orient = MeanChannelMat.Channel(iMean(c)).Orient + ChannelMats{i}.Channel(iChans(c)).Orient;
                nAvg(iMean(c)) = nAvg(iMean(c)) + 1;
            end
        end
    end
    for iChan = 1:nChan
        if nAvg(iChan) > 1
            % Divide the locations of channels by the number of channel files averaged.
            MeanChannelMat.Channel(iChan).Loc = MeanChannelMat.Channel(iChan).Loc / nAvg(iChan);
            Dist{iChan} = Dist{iChan} / nAvg(iChan);
            % Correct distance from origin.
            MeanChannelMat.Channel(iChan).Loc = bsxfun(@times, MeanChannelMat.Channel(iChan).Loc, ...
                Dist{iChan} ./ sqrt(sum(MeanChannelMat.Channel(iChan).Loc.^2, 1)));
            % Orientations need to be normalized.
            MeanChannelMat.Channel(iChan).Orient = MeanChannelMat.Channel(iChan).Orient / norm(MeanChannelMat.Channel(iChan).Orient);
        end
    end
    
end


function TransfAvg = PositionAverage(Transf, BrainOrigin)
    % Average head position to minimize sum of square displacements over cortex.
    
    % Simply averaging positions (sensors or surface points) at different
    % orientations shrinks the space.  We must average origins, and
    % separately the spatial rotations.
    
    nT = numel(Transf);
    TransfAvg = eye(4);
    
    % Rotations ------------------------------
    % [Markley 2007 - Averaging Quaternions] gives a simple method for
    % averaging orientations based on the quaternion representation.
    Quat = zeros(4, nT);
    for t = 1:nT
        Quat(:, t) = RotToQuat(Transf{t}(1:3, 1:3));
    end
    % Eigenvector of max eigenvalue of Q'*Q is first singular vector of Q'.
    [U, S] = svd(Quat, 'econ');
    TransfAvg(1:3, 1:3) = QuatToRot(U(:, 1));
    % Rotation verified.
    
    % Translations of origin ------------------------------
    % To minimize brain displacement, we must choose the cortex center as
    % the origin to average, and not the SCS origin.  We must know the
    % cortex center in head coordinates.
    Origins = zeros(4, nT);
    BrainOriginAvg = zeros(3, 1);
    for t = 1:nT
        Origins(:, t) = Transf{t} \ [BrainOrigin(t, :)'; 1];
        BrainOriginAvg = BrainOriginAvg + BrainOrigin(t, :)';
    end
    BrainOriginAvg = BrainOriginAvg / nT;
    TransfAvg(1:3, 4) = BrainOriginAvg - TransfAvg(1:3, 1:3) * ...
        process_adjust_coordinates('GeoMedian', Origins(1:3, :)')';
    % Origin verified.
    
end


% Verified conversions of matrix and quaternion representations.
%     Transf = eye(3);
%     t = pi/2;
%     Transf(1:2, 1:2) = [cos(t), -sin(t); sin(t), cos(t)]
%     NewTransf = QuatToRot(RotToQuat(Transf))
function R = QuatToRot(q)
    % q = [w, x, y, z]', w scalar
    d = q(1)^2 - q(2)^2 - q(3)^2 - q(4)^2;
    R = d * eye(3) + 2 * [q(2)^2, q(2)*q(3) - q(1)*q(4), q(2)*q(4) + q(1)*q(3); ...
        q(2)*q(3) + q(1)*q(4), q(3)^2, q(3)*q(4) - q(1)*q(2); ...
        q(2)*q(4) - q(1)*q(3), q(3)*q(4) + q(1)*q(2), q(4)^2];
end

function q = RotToQuat(R)
    % q = [w, x, y, z]', w scalar
    t = trace(R);
    q = [1 + t; ...
        1 - t + 2 * R(1, 1); ...
        1 - t + 2 * R(2, 2); ...
        1 - t + 2 * R(3, 3)];
    if any(q < 0)
        error('Quat problem');
    end
    q = 1/2 * sqrt(q);
    q = q .* [1; ...
        sign(R(3, 2) - R(2, 3));
        sign(R(1, 3) - R(3, 1));
        sign(R(2, 1) - R(1, 2))];
    % For minimizing errors.
    q = q ./ norm(q);
end



