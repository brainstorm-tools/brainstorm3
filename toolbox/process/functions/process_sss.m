function varargout = process_sss( varargin )
    % PROCESS_SSS: Spatiotemporal signal space separation and motion correction.
    %
    % DESCRIPTION:
    %
    
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
    
    % In this file, theta (or t) is the colatitude angle, from the z axis,
    % and phi (or p) is the longitude angle or azimuth.
    
    % TO DO:
    % tSSS, how long of chunks do we need for stable separation?
    % tSSS, how do we avoid jumps between chunks?
    % SSS, (and tSSS!) we need to keep track of the empty subspace as in SSP, for source modeling?
    % How would that work in combination with SSP/ICA?
    
    eval(macro_method);
end


% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Signal space separation';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 114;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SSS';
    sProcess.FileTag     = 'sss';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    sProcess.processDim  = 2;   % Process all channels at once
    % Definition of the options
    %     % Use existing SSPs
    %     sProcess.options.usessp.Comment = 'Compute using existing SSP/ICA projectors';
    %     sProcess.options.usessp.Type    = 'checkbox';
    %     sProcess.options.usessp.Value   = 1;
    %     % Ignore bad segments
    %     sProcess.options.ignorebad.Comment = 'Ignore bad segments';
    %     sProcess.options.ignorebad.Type    = 'checkbox';
    %     sProcess.options.ignorebad.Value   = 1;
    %     sProcess.options.ignorebad.Hidden  = 1;
    % Motion correction
    sProcess.options.motion.Comment = 'Apply head motion correction: interpolate with spherical harmonics.';
    sProcess.options.motion.Type    = 'checkbox';
    sProcess.options.motion.Value   = 1;
    % Cleaning
    sProcess.options.clean.Comment = 'Clean external interference and artifacts.';
    sProcess.options.clean.Type    = 'label';
    %   sProcess.options.clean.Type    = 'checkbox';
    %   sProcess.options.clean.Value   = 1;
    % Spatial cleaning
    sProcess.options.spatial.Comment = 'Spatial SSS: reject "outside" spherical harmonics.';
    sProcess.options.spatial.Type    = 'checkbox';
    sProcess.options.spatial.Value   = 0;
    % Temporal cleaning
    sProcess.options.temporal.Comment = 'Temporal SSS: project out artefact timecourses.';
    sProcess.options.temporal.Type    = 'checkbox';
    sProcess.options.temporal.Value   = 0;
    % Spherical harmonic expansion order
    sProcess.options.exporder.Comment = 'Expansion order (out, in): ';
    sProcess.options.exporder.Type    = 'range';
    sProcess.options.exporder.Value   = {[6, 9], '', 0};
    
end


% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    LIn = sProcess.options.exporder.Value{1}(2);
    LOut = sProcess.options.exporder.Value{1}(1);
    nHarmonics = (LIn + 1)^2 + (LOut + 1)^2 - 2;
    % Seems no word wrap and no color.  Need small comments.
    if sProcess.options.temporal.Value && (LIn < 2 || LOut < 2)
        Comment = 'Error: tSSS cleaning requires orders 2 or more.';
        % For now allow temporal without spatial, though it is strange.
        %   elseif sProcess.options.temporal.Value && ~sProcess.options.spatial.Value
        %     Comment = 'Error: tSSS cleaning requires spatial SSS as well.';
    elseif sProcess.options.spatial.Value && (LIn < 2 || LOut < 2)
        Comment = 'Error: SSS cleaning requires orders 2 or more.';
    elseif sProcess.options.temporal.Value && sProcess.options.spatial.Value
        if sProcess.options.motion.Value
            Comment = sprintf('SSS: spatio-temporal cleaning (%d harmonics) + motion correction', nHarmonics);
        else
            Comment = sprintf('SSS: spatio-temporal cleaning (%d harmonics)', nHarmonics);
        end
    elseif sProcess.options.temporal.Value
        if sProcess.options.motion.Value
            Comment = sprintf('SSS: temporal cleaning (%d harmonics) + motion correction', nHarmonics);
        else
            Comment = sprintf('SSS: temporal cleaning (%d harmonics)', nHarmonics);
        end
    elseif sProcess.options.spatial.Value
        if sProcess.options.motion.Value
            Comment = sprintf('SSS: spatial cleaning (%d harmonics) + motion correction', nHarmonics);
        else
            Comment = sprintf('SSS: spatial cleaning (%d harmonics)', nHarmonics);
        end
    elseif sProcess.options.motion.Value
        Comment = 'SSS: motion correction';
    else
        Comment = 'Error: Nothing to do.';
    end
    
end


% ===== RUN =====
function sInput = Run(sProcess, sInput)
    
    % Parse options.
    LIn = sProcess.options.exporder.Value{1}(2);
    LOut = sProcess.options.exporder.Value{1}(1);
    if sProcess.options.temporal.Value && (LIn < 2 || LOut < 2)
        bst_error('tSSS cleaning requires expansion orders at minimum 2.');
    end
    if sProcess.options.temporal.Value && ~sProcess.options.spatial.Value
        fprintf(['BST> tSSS without spatial SSS is unusual: it would in theory only remove artefacts \n', ...
            'that are very close to the sensors and keep those originating from further away.\n']);
    end
    if sProcess.options.spatial.Value && (LIn < 2 || LOut < 2)
        bst_error('SSS cleaning requires expansion orders at minimum 2.');
    end
    if ~sProcess.options.temporal.Value && ~sProcess.options.spatial.Value && ...
            ~sProcess.options.motion.Value
        fprintf('BST> SSS: Nothing to do.');
        return
    end
    
    %   for iFile = 1:numel(sInputs)
    %     sInput = sInputs(iFile);
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    
    % CTF compensation.
    % It is not obvious how to best combine reference channels and SSS.  For
    % head motion correction only, it makes sense to treat them as regular
    % channels, thus undo the compensation before and reapply it after.
    iRef = good_channel(ChannelMat.Channel, sInput.ChannelFlag, 'MEG REF');
    iMeg = good_channel(ChannelMat.Channel, sInput.ChannelFlag, 'MEG');
    if strcmpi(sInput.FileType, 'raw')
        DataMat = in_bst_data(sInput.FileName, 'F');
        sFile = DataMat.F;
    else
        sFile = in_fopen(sInput.FileName, 'BST-DATA');
    end
    isCtfComp = ~isempty(sFile.prop.currCtfComp) && (sFile.prop.currCtfComp ~= 0);
    clear sFile
    % Remove CTF compensation, apply it back at end.
    isUndoCtfComp = true && ... % This could potentially be an option.
        isCtfComp && ...
        isfield(ChannelMat, 'MegRefCoef') && ~isempty(ChannelMat.MegRefCoef) && ...
        (numel(iRef) == size(ChannelMat.MegRefCoef, 2));
    if isCtfComp && ~isUndoCtfComp
        % If we don't take into account CTF compensation, either by option or
        % because we're missing the reference channels or coefficients, we must
        % completely ignore reference channels.
        iRef = [];
    end
    if isUndoCtfComp
        sInput.A(iMeg, :) = sInput.A(iMeg, :) + ChannelMat.MegRefCoef(iMeg, iRef) * sInput.A(iRef, :);
    end
    
    % Need to keep this after CTF compensation.
    iMegRef = sort([iRef, iMeg]);
    nChannels = numel(iMegRef);
    
    %% TESTING
    isFullRank = false;
    isTruncate = true;
    % Adjust the maximum expansion orders based on number of channels.
    % For only head
    % motion correction, we will want to keep the full rank of the data, with
    % as many harmonics as needed, and use a minimum-norm solution.
    nHarmonics = @(L1, L2) (L1 + 1)^2 + (L2 + 1)^2 - 2; % but not if we must reject LOut=1.
%     if sProcess.options.motion.Value && ~sProcess.options.spatial.Value && ...
%             ~sProcess.options.temporal.Value
%         % Only doing head motion correction, use as many harmonics as channels.
%         % Not sure which basis is best here: but if we use the reference
%         % channels, probably best to have at least some "out" harmonics.
%         % Still, respect user choice.
%         while nHarmonics(LIn, LOut) < nChannels
%             if LOut < LIn
%                 LOut = LOut + 1;
%             else
%                 LIn = LIn + 1;
%             end
%         end
% %         isFullRank = true;
% %     else
% %         isFullRank = false;
%     end
    
    % Don't use more harmonics than needed.
    if isTruncate && nHarmonics(LIn, LOut) > nChannels && ...
            nHarmonics(LIn-1, LOut) > nChannels && nHarmonics(LIn, LOut-1) > nChannels
        while nHarmonics(LIn, LOut) >= nChannels
            if LOut >= LIn
                LOut = LOut - 1;
            else
                LIn = LIn - 1;
            end
        end
        LIn = LIn + 1;
        %         if LIn < sProcess.options.exporder.Value{1}(2)
        %             fprintf(['BST> SSS: Asked for too many harmonics; expansion order [%d, %d] => %d harmonics.\n', ...
        %                 'Using [%d, %d] => %d harmonics instead, more than enough for %d channels.\n'], ...
        %                 sProcess.options.exporder.Value{1}, ...
        %                 nHarmonics(sProcess.options.exporder.Value{1}(1), sProcess.options.exporder.Value{1}(2)), ...
        %                 LOut, LIn, nHarmonics(LIn, LOut), nChannels);
        %         end
    end
    
    
    % Get channel locations and orientations per sensor coil.
    [InitLoc, InitOrient, CoilToChannel, ExpansionOrigin] = ...
        CoilGeometry(ChannelMat.Channel, iMegRef);
    % We may want to translate the coil locations such that the origin of the
    % spherical harmonic expansion is better centered on the brain.  For now,
    % use the approximate center of the MEG sensor coils.
    %   InitLoc -> bsxfun(@minus, InitLoc, ExpansionOrigin);
    % Also, for numerical stability we want the values of r to be close to 1,
    % so that the expansion coefficients are also of that order.  Locations
    % are in meters, maybe better in dm?
    %   InitLoc -> InitLoc * ExpansionScale;
    ExpansionScale = 10;
    %% TESTING
%     ExpansionOrigin
%     SensDist = sqrt(sum(bsxfun(@minus, InitLoc, ExpansionOrigin).^2, 1));
%     MinSensOriginDist = min(SensDist)
    
    % Get the SSS basis matrix for inside and outside sources at the
    % reference head position.
    [InitSIn, InitSOut, LIn, LOut] = SphericalBasis(LIn, LOut, ...
        bsxfun(@minus, InitLoc, ExpansionOrigin) * ExpansionScale, ...
        InitOrient, CoilToChannel, true, isFullRank, isTruncate);
    % We may want to further normalize the basis vectors to improve the
    % matrix condition. This also has a strong impact on the interpolation
    % when we have more harnonics than sensors because we then have
    % multiple solutions and we choose the minimum norm solution.
    InitSInNorms = sqrt(sum(InitSIn.^2, 1));
    InitSOutNorms = sqrt(sum(InitSOut.^2, 1));
%     InitSInNorms = 1; %sqrt(sum(InitSIn.^2, 1));
%     InitSOutNorms = 1; %sqrt(sum(InitSOut.^2, 1));
    InitSIn = bsxfun(@rdivide, InitSIn, InitSInNorms);
    InitSOut = bsxfun(@rdivide, InitSOut, InitSOutNorms);
    
    nHarmonics = size(InitSIn, 2) + size(InitSOut, 2);
    
    % Show out first, since that's how it's entered by users.
    fprintf(['BST> SSS: Spherical harmonics expansion order [%d, %d] => %d harmonics.\n', ...
        'Rank = %d, Cond = %1.1g, %d channels.\n'], ...
        LOut, LIn, nHarmonics, rank([InitSIn, InitSOut]), cond([InitSIn, InitSOut]), nChannels);
    
    
    if sProcess.options.motion.Value
        % For head motion correction, compute sensor locations through time.
        
        % Verify that we can compute the transformation from initial to
        % each continuous head tracking position, and get required
        % transformation matrices.
        [TransfBefore, TransfAdjust, TransfAfter] = process_adjust_head_position('GetTransforms', ChannelMat, sInput);
        if isempty(TransfBefore)
            % There was an error, already reported. Skip this file.
            return;
        end
        
        % Get "equivalent" initial/reference head location.
        InitHeadCoilLoc = process_adjust_head_position('ReferenceHeadLocation', ChannelMat);
        
        % We already have the HLU channels loaded.
        %       [HeadCoilLoc, HeadSamplePeriod] = process_evt_head_motion('LoadHLU', ...
        %         sInput, BlockSampleBounds, false);
        iHLU = find(strcmp({ChannelMat.Channel.Type}, 'HLU'));
        if numel(iHLU) < 9
            bst_error('Head coil position channels not found. Can''t correct for head motion.');
        end
        HeadCoilLoc = sInput.A(iHLU, :);
        nSamples = size(sInput.A, 2);
        % Downsample head localization channels to their real sampling rate.  For
        % details, see process_evt_head_motion('LoadHLU');
        HeadSamplePeriod = nSamples;
        TrueSamples = find(any(diff(HeadCoilLoc, 1, 2), 1)) + 1;
        if numel(TrueSamples) > 1 % to avoid empty which propagates in min.
            HeadSamplePeriod = min(HeadSamplePeriod, min(diff(TrueSamples(1:end-1))));
        end
        HeadCoilLoc = HeadCoilLoc(:, 1:HeadSamplePeriod:nSamples);
        
        nHeadSamples = size(HeadCoilLoc, 2);
        % In case the recording was aborted.
        iLastSample = nSamples;
        SpherCoeffs = zeros(nHarmonics, nSamples);
        for iHeadSample = 1:nHeadSamples
            % If a collection was aborted, the channels will be filled with
            % zeros. We must ignore these samples.
            if all(HeadCoilLoc(:, iHeadSample) == 0)
                iLastSample = (iHeadSample - 1) * HeadSamplePeriod;
                break;
            end
            
            % Compute transformation corresponding to current head coil
            % positions.  It goes from the current coordinate system to an
            % equivalent adjusted one; equivalent in the sense that all
            % existing transformations are still applied.
            TransfMat = LocationTransform( ...
                HeadCoilLoc(:, iHeadSample), TransfBefore, TransfAdjust, TransfAfter);
            
            % Modify channel positions.
            %       ChannelMat = channel_apply_transf(ChannelMat, TransfMat, [], false);
            Loc = bsxfun(@plus, TransfMat(1:3, 1:3) * InitLoc, TransfMat(1:3, 4));
            Orient = TransfMat(1:3, 1:3) * InitOrient;
            
            % Get the SSS basis matrix for inside and outside sources.
            [SIn, SOut] = SphericalBasis(LIn, LOut, ...
                bsxfun(@minus, Loc, ExpansionOrigin) * ExpansionScale, ...
                Orient, CoilToChannel, true, [], isTruncate);
            % We must apply the same normalization as on the initial basis for it
            % to cancel when we recover the sensor time series.
            SIn = bsxfun(@rdivide, SIn, InitSInNorms);
            SOut = bsxfun(@rdivide, SOut, InitSOutNorms);
            
            % Get data corresponding to this head sample.
            SampleStart = (iHeadSample - 1) * HeadSamplePeriod + 1;
            SampleBounds = [SampleStart, min(SampleStart+HeadSamplePeriod, iLastSample)];
            
            % Compute coefficients as function of time.
            
            SpherCoeffs(:, SampleBounds(1):SampleBounds(2)) = ...
                lsqminnorm([SIn, SOut], sInput.A(iMegRef, SampleBounds(1):SampleBounds(2)));
            %       SpherCoeffs(:, SampleBounds(1):SampleBounds(2)) = ...
            %            [SIn, SOut] \ sInput.A(iMegRef, SampleBounds(1):SampleBounds(2)));
            
        end % Head samples loop
        
        % Also modify the head coil channels, such that the fact we
        % corrected for motion is known by other processes.
        for c = 1:numel(iHLU)
            sInput.A(iHLU(c), 1:iLastSample) = InitHeadCoilLoc(c);
        end
        
    else % don't correct for head motion
        % Compute coefficients as function of time.
        SpherCoeffs = lsqminnorm([InitSIn, InitSOut], sInput.A(iMegRef, :));
        %     SpherCoeffs = [InitSIn, InitSOut] \ sInput.A(iMegRef, :);
        % Can split them into In and Out components.
        
    end % if correct for head motion
    
    
    nIn = size(InitSIn, 2);
    if sProcess.options.temporal.Value
        % Temporal SSS
        % Intersection of in and out temporal subspaces.
        M = Intersect(SpherCoeffs(1:nIn, :), SpherCoeffs((nIn+1):end, :), ...
            TemporalIntersectAllowance);
    end
    
    % Project back to sensor space and at reference head position.
    if sProcess.options.spatial.Value
        if sProcess.options.temporal.Value
            % Remove in and out intersection from coefficients first.
            SpherCoeffs(1:nIn, :) = SpherCoeffs(1:nIn, :) - ...
                SpherCoeffs(1:nIn, :) * M * M'; %#ok<*MHERM>
        end
        % Project back to sensor space using inside basis only.
        sInput.A(iMegRef, :) = InitSIn * SpherCoeffs(1:nIn, :);
    else % don't use spatial cleaning.
        if sProcess.options.temporal.Value
            % Remove in and out intersection from coefficients first.
            SpherCoeffs = SpherCoeffs - SpherCoeffs * M * M';
        end
        % Project back to sensor space using complete basis.
        sInput.A(iMegRef, :) = [InitSIn, InitSOut] * SpherCoeffs;
    end
    
    if isUndoCtfComp
        sInput.A(iMeg, :) = sInput.A(iMeg, :) - ChannelMat.MegRefCoef(iMeg, iRef) * sInput.A(iRef, :);
    end
    
end



function [Loc, Orient, CoilToChannel, Origin] = CoilGeometry(Channel, iMegRef)
    % Get channel locations and orientations per coil. They were converted to
    % 4 points per coil when the dataset was first loaded. We could have an
    % option to keep the 4 points, but it really seems unnecessary, so for
    % efficiency, keep one location and one orientation per coil.
    
    nChannels = numel(iMegRef);
    Loc = zeros(3, 2*nChannels);
    Orient = Loc;
    CoilToChannel = zeros(nChannels, 2*nChannels);
    % Find the approximate center of all "inner" MEG coils.
    Origin = zeros(3, 2);
    
    iCoil = 1;
    for c = 1:nChannels
        cc = iMegRef(c);
        nChanLocPts = size(Channel(cc).Loc, 2);
        switch nChanLocPts
            case 4
                Loc(:, iCoil) = mean(Channel(cc).Loc(:, 1:4), 2);
                Orient(:, iCoil) = Channel(cc).Orient(:, 1);
                CoilToChannel(c, iCoil) = sum(Channel(cc).Weight(:, 1:4), 2);
                if strcmp(Channel(cc).Type, 'MEG')
                    Origin(:, 1) = min([Origin(:, 1), Loc(:, iCoil)], [], 2);
                    Origin(:, 2) = max([Origin(:, 2), Loc(:, iCoil)], [], 2);
                end
                iCoil = iCoil + 1;
            case 8
                Loc(:, iCoil+(0:1)) = [ mean(Channel(cc).Loc(:, 1:4), 2), ...
                    mean(Channel(cc).Loc(:, 5:8), 2) ];
                Orient(:, iCoil+(0:1)) = Channel(cc).Orient(:, [1,5]);
                CoilToChannel(c, iCoil+(0:1)) = [ sum(Channel(cc).Weight(:, 1:4), 2), ...
                    sum(Channel(cc).Weight(:, 5:8), 2) ];
                if strcmp(Channel(cc).Type, 'MEG')
                    Origin(:, 1) = min([Origin(:, 1), max(Loc(:, iCoil+(0:1)), [], 2)], [], 2);
                    Origin(:, 2) = max([Origin(:, 2), min(Loc(:, iCoil+(0:1)), [], 2)], [], 2);
                end
                iCoil = iCoil + 2;
            otherwise
                bst_error('Unexpected number of coil location points.');
        end
    end
    nCoils = iCoil - 1;
    Loc(:, nCoils+1:end) = [];
    Orient(:, nCoils+1:end) = [];
    CoilToChannel(:, nCoils+1:end) = [];
    % Center between max and min. Though for z, keep center top as far as
    % lower edge, which after a bit of geometry gives 3/8 of the way from the
    % bottom.
    Origin = [(Origin(1:2, 2) + Origin(1:2, 1)) / 2; ...
        1/8 * (5 * Origin(3, 1) + 3 * Origin(3, 2))];
end



function [SIn, SOut, LIn, LOut] = SphericalBasis(LIn, LOut, Loc, Orient, ...
        CoilToChannel, isRealBasis, isFullRank, isTruncate)
    % Build the S matrix that relates the measured magnetic field
    % to the spherical harmonic coefficients: B = S * x, so
    % size(S)=[nChannels, (L + 1)^2 - 1]
    %  Loc and Orient are size 3 x nSensors.
    % Orient is in tangential spherical coordinates.
    
    if nargin < 8 || isempty(isTruncate)
        isTruncate = false;
    end
    if nargin < 7 || isempty(isFullRank)
        isFullRank = false;
    end
    if nargin < 6 || isempty(isRealBasis)
        isRealBasis = true;
    end
    if nargin < 5 || isempty(CoilToChannel)
        CoilToChannel = eye(size(Loc, 2));
    end
    if nargin < 4
        error('Expecting more arguments.');
    end
    
    % Convert sensor locations to spherical coordinates.
    [r, t, p] = CartToSpher(Loc'); % Column vectors.
    
    % Convert the orientations to tangential spherical coordinates,
    % defined by the unit spherical vectors a each location.
    [OR, OT, OP] = CartToTangentSpher([], t, p, Orient(1, :)', Orient(2, :)', Orient(3, :)'); % Column vectors
    
    nChannels = size(CoilToChannel, 1);
    % Evaluate spherical harmonics at sensor locations.
    SIn = zeros(size(Loc, 2), (LIn+1)^2 - 1);
    SOut = zeros(size(Loc, 2), (LOut+1)^2 - 1);
    iSIn = 1;
    iSOut = 1;
    l = 1; % Why do we not include l=0? Maybe we don't expect monopoles? We could, but doesn't matter.
    while l <= max(LIn, LOut)
        [Y, m, dYdt] = SphericalHarmonics(l, t, p, isRealBasis); % size [nLoc, 2*l+1]
        
        % Compute the "magnetic field harmonics" = - gradient of "potential harmonics".
        % Here in tangential spherical coordinates (defined by spherical unit vectors).
        % The phi-hat component (SP) is the only one that requires preparation.
        if isRealBasis
            SP = bsxfun(@rdivide, -m, sin(t)) .* Y(:, [1, (l+2):end, 2:(l+1)]); % Y(-m)
            % Deal with indeterminate SP at poles (sin(t)=0). This was
            % calculated using L'Hospital's rule and the limits of dPdt (see
            % legendre_derivative_t function below) and independently with the
            % definition of Legendre.
            if any(isnan(SP(:)))
                isEdge = isnan(SP(:, 1));
                SP(isEdge, :) = 0; % For all m ~= 1.
                % Real Y has additional (-1)^m and sqrt(2) factors compared to complex Y.
                SP(isEdge, 2) = -(cos(t(isEdge)).^(l+1)) * l * (l+1) / 2 * sqrt((2*l + 1)/2/pi /l/(l+1)) .* sin(p(isEdge)); % -m=-1 cancels (-1)^m=-1 from Y
                SP(isEdge, l+2) = (cos(t(isEdge)).^(l+1)) * l * (l+1) / 2 * sqrt((2*l + 1)/2/pi /l/(l+1)) .* cos(p(isEdge)); % -m = 1, (-1)^m=-1 from Y
            end
        else % complex basis
            SP = bsxfun(@rdivide, 1i * m, sin(t)) .* Y;
            % Needs similar special treatment for t=0,pi.
            if any(isnan(SP(:)))
                isEdge = isnan(SP(:, 1));
                SP(isEdge, :) = 0; % For all m ~= 1.
                SP(isEdge, 2) = -(cos(t(isEdge)).^(l+1)) * l * (l+1) / 2 * sqrt((2*l + 1)/4/pi /l/(l+1)) .* exp(-1i*p(isEdge)); % -m=-1 cancels (-1)^m=-1 from Y_-m
                SP(isEdge, l+2) = -(cos(t(isEdge)).^(l+1)) * l * (l+1) / 2 * sqrt((2*l + 1)/4/pi /l/(l+1)) .* exp(1i*p(isEdge)); % -m = 1
            end
        end
        if l <= LIn
            %  Inside
            %       SR = -(l+1) * Y;
            %       ST = dYdt;
            % Project along sensor orientations.
            % The tangential sphere coordinates are basically cartesian, we can
            % apply the dot product with the usual formula.
            SIn(:, iSIn:iSIn+2*l) = bsxfun( @times, -1./r.^(l+2), ...
                bsxfun(@times, OR, -(l+1) * Y) + bsxfun(@times, OT, dYdt) + ...
                bsxfun(@times, OP, SP) );
            % Even though there should never be sensors at r=0, prevent
            % propagating NaNs. (The actual limit can be +-Inf or 0.)
            if any(r==0)
                SIn(r==0, :) = 0;
            end
        end
        if l <= LOut
            %  Outside
            %       SR = l * Y;
            %       ST = dYdt;
            % Project along sensor orientations.
            SOut(:, iSOut:iSOut+2*l) = bsxfun( @times, -r.^(l-1), ...
                bsxfun(@times, OR, l * Y) + bsxfun(@times, OT, dYdt) + ...
                bsxfun(@times, OP, SP) );
            % Since we don't include l=0, no problem at r=0 here.
            
            % Turns out that the l=1 out harmonics are constant vectors, thus for any
            % gradiometer, these will give zero.  If we only have gradiometers, we
            % must exclude them.
            if l == 1 && any(sum(CoilToChannel * SOut(:, iSOut:iSOut+2*l).^2, 1) < nChannels * 1000 * eps(1))
                SOut(:, iSOut:iSOut+2*l) = [];
                iSOut = iSOut - (2 * l + 1);
            end
        end
        
        %     EndIn = min(iS+2*l, size(SIn,2));
        %     EndOut = min(iS+2*l, size(SOut,2));
        %     S = CoilToChannel * ([SIn(:, 1:EndIn), SOut(:, 1:EndOut)]);
        %     SNorms = sqrt(sum(S.^2, 1));
        %     S = bsxfun(@rdivide, S, SNorms);
        %     Rank = rank(S);
        %     fprintf('l=%d, nH=%d, rank=%d, cond=%g\n', ...
        %       l, size(S, 2), Rank, cond(S));
        if isFullRank && l == max(LIn, LOut)
            %       Rank = rank(S);
            %       s = svd(S);
            %       Tol = max(size(S)) * eps(max(s));
            %       fprintf('l=%d, nH=%d, rank=%d, cond=%g\n', ...
            %         l, size(S, 2), Rank, cond(S));
            %       %       fprintf('l=%d, nH=%d, rank=%d, ranktol=%d, %d Sing=[%g, %g], cond=%g\n', ...
            %       %         l, size(S, 2), Rank, Tol, numel(s), min(s), max(s), cond(S));
            S = CoilToChannel * ([SIn, SOut]);
            SNorms = sqrt(sum(S.^2, 1));
            S = bsxfun(@rdivide, S, SNorms);
            Rank = rank(S);
            if Rank < nChannels
                % Increment the max order.
                if LIn > LOut
                    LIn = LIn + 1;
                elseif LOut > LIn
                    LOut = LOut + 1;
                else % ==
                    LIn = LIn + 1;
                    LOut = LOut + 1;
                end
            end
        end
        
        iSIn = iSIn + 2 * l + 1;
        iSOut = iSOut + 2 * l + 1;
        l = l + 1;
    end % l loop
    
    % Convert coil values to channels.
    SIn = CoilToChannel * SIn;
    SOut = CoilToChannel * SOut;
    
    if isTruncate
        % Remove basis vectors beyond number of channels.
        if nChannels < size(SIn, 2)
            SOut = [];
            SIn(:, nChannels+1:end) = [];
        elseif nChannels - size(SIn, 2) < size(SOut, 2)
            SOut(:, (nChannels - size(SIn, 2) + 1):end) = [];
        end
    end
end



function [Y, m, dYdt, P] = SphericalHarmonics(l, t, p, isRealBasis)
    % Returns Y (size [nPoints, 2l+1]) for all values of m from -l to l,
    % ordered as m = [0 to l, -1 to -l]. t and p can be vectors, of identical
    % size. Choice of real (default) or complex basis.
    
    % Real basis fully tested.
    
    % Parse inputs.
    if nargin < 4 || isempty(isRealBasis)
        isRealBasis = true;
    end
    if nargin < 3
        bst_error('Expecting 3 inputs: l, t, p');
    end
    if ~all(size(t) == size(p))
        bst_error('t and p should have the same size.');
    end
    if size(t, 1) < size(t, 2)
        t = t';
        p = p';
    end
    if size(t, 2) > 1
        bst_error('t and p should be vectors, not matrices.');
    end
    
    Cost = cos(t);
    % legendre returns m from 0 to l. We must compute negative m's.
    % legendre includes the Condon-Shortley phase, so it is omitted below.
    P = legendre(l, Cost).'; % size [nPoints, l+1]
    % Factorial factors.
    Fact = zeros(1, l);
    for m = 1:l
        Fact(m) = sqrt( 1 ./ prod((l+m):-1:(l-m+1)) );
    end
    if nargout > 2
        dPdt = legendre_derivative_t(l, Cost', P').'; % includes -sin(t) factor.
    end
    
    Factor2 = sqrt((2*l + 1) / (4*pi));
    m = (1:l);
    if isRealBasis
        % Following Wikipedia's definition, where a -1^m factor cancels the
        % Condon-Shortley phase in P.
        Y = [ Factor2 * P(:, 1), ... % m = 0
            sqrt(2) * Factor2 * bsxfun( @times, (-1).^[m, m] .* [Fact, Fact], ...
            P(:, [m+1, m+1]) ) .* ...
            [cos(bsxfun(@times, m, p)), sin(bsxfun(@times, m, p))] ];
        
        if nargout > 2
            % Also compute derivative of Y with respect to theta.
            dYdt = [ Factor2 * dPdt(:, 1), ... % m = 0
                sqrt(2) * Factor2 * bsxfun( @times, (-1).^[m, m] .* [Fact, Fact], ...
                dPdt(:, [m+1, m+1]) ) .* ...
                [cos(bsxfun(@times, m, p)), sin(bsxfun(@times, m, p))] ];
            %       dYdt = [ Factor2 * bsxfun(@times, -sin(t), dPdt(:, 1)), ... % m = 0
            %         sqrt(2) * Factor2 * bsxfun( @times, (-1).^[m, m] .* [Fact, Fact], ...
            %         -sin(t) ) .* dPdt(:, [m+1, m+1]) .* ...
            %         [cos(bsxfun(@times, m, p)), sin(bsxfun(@times, m, p))] ];
        end
        if nargout > 3
            % Get P for negative m, even though they're not used in real
            % harmonics.
            P = [P, bsxfun(@times, (-1).^m .* Fact(m).^2, P(:, 2:end))]; % size [nPoints, 2l+1]
        end
        
        m = [0:l, -1:-1:-l];
        
    else % complex basis
        % Need P for negative m.
        % Additional Fact(m).^2 factor cancels with Fact(-m) to give back
        % Fact(m).
        % Here m is still 1:l.
        P = [P, bsxfun(@times, (-1).^m, P(:, 2:end))]; % .* Fact(m).^2   size [nPoints, 2l+1]
        if nargout > 2
            dPdt = [dPdt, bsxfun(@times, (-1).^m, dPdt(:, 2:end))]; % .* Fact(m)  size [nPoints, 2l+1]
        end
        Fact = [1, Fact, Fact]; % size [1, 2l+1]
        
        m = [0:l, -1:-1:-l];
        Y = Factor2 * bsxfun(@times, Fact, P) .* exp(1i * bsxfun(@times, m, p));
        if nargout > 2
            % Also compute derivative of Y with respect to theta.
            dYdt = Factor2 * bsxfun(@times, Fact, dPdt) .* ...
                exp(1i * bsxfun(@times, m, p));
            %       dYdt = Factor2 * bsxfun(@times, Fact, -sin(t)) .* dPdt .* ...
            %          exp(1i * bsxfun(@times, m, p));
        end
        
    end
    
end

function [Y, m] = SphericalHarmonicsl2(l, t, p, isRealBasis)
    % When m is empty, returns Y for all values of m from -l to l.
    % t and p can be vectors of identical size.
    
    % Parse inputs.
    if nargin < 4 || isempty(isRealBasis)
        isRealBasis = true;
    end
    if nargin < 3
        bst_error('Expecting 3 inputs: l, t, p');
    end
    if ~all(size(t) == size(p))
        bst_error('t and p should have the same size.');
    end
    if size(t, 1) < size(t, 2)
        t = t';
        p = p';
    end
    if size(t, 2) > 1
        bst_error('t and p should be vectors, not matrices.');
    end
    if l ~= 2
        l = 2;
        warning('This function is for testing l=2 only.');
    end
    
    m = [0:l, -1:-1:-l];
    ThetaPart = [(3*cos(t).^2 - 1), sin(t).*cos(t), sin(t).^2, ... % m = 0, 1, 2
        sin(t).*cos(t), sin(t).^2]; % m = -1, -2
    if isRealBasis
        % Following Wikipedia's definition, where a -1^m factor cancels the
        % Condon-Shortley phase.
        Fact = [1/4 * sqrt(5/pi), 1/2 * sqrt(15/pi), 1/4 * sqrt(15/pi), ...
            1/2 * sqrt(15/pi), 1/4 * sqrt(15/pi)];
        PhiPart = [ones(size(p)), cos(p), cos(2*p), sin(p), sin(2*p)];
    else % complex basis, with Condon-Shortley phase here.
        Fact = [1/4 * sqrt(5/pi), -1/2 * sqrt(15/(2*pi)), 1/4 * sqrt(15/(2*pi)), ...
            1/2 * sqrt(15/(2*pi)), 1/4 * sqrt(15/(2*pi))];
        PhiPart = [ones(size(p)), exp(1 * 1i * p), exp(2 * 1i * p), ...
            exp(-1 * 1i * p), exp(-2 * 1i * p)];
    end
    Y = bsxfun(@times, Fact, ThetaPart .* PhiPart);
end



function [r, t, p] = CartToSpher(x, y, z)
    % Convert from cartesian to spherical coordinates.
    % Accepts column or row vectors.
    %
    % "physics" convention:
    % t (theta) is the zenith (from z axis),
    % p (phi) is the azimuth (in xy-plane from x).
    
    if nargin == 1
        % Coordinates were passed as vectors.
        d = find(size(x) == 3, 1);
        switch d
            case 1
                y = x(2, :); z = x(3, :); x = x(1, :);
            case 2
                y = x(:, 2); z = x(:, 3); x = x(:, 1);
            otherwise
                bst_error('Inputs should be three matrices with same sizes, or a single matrix with 3 columns or rows.');
        end
    elseif nargin ~= 3
        bst_error('Inputs should be three matrices with same sizes, or a single matrix with 3 columns or rows.');
    end
    
    r = sqrt(x.^2 + y.^2 + z.^2);
    % Handle zero length case.
    t = zeros(size(r));
    p = zeros(size(r));
    iOk = r ~= 0;
    t(iOk) = acos(z(iOk)./r(iOk)); % Between 0 and pi.
    p(iOk) = atan2(y(iOk), x(iOk));
    
    if nargout == 1
        % Output as vectors.
        if size(r, 2) == 1
            r = [r, t, p];
        elseif size(r, 1) == 1
            r = [r; t; p];
        else
            r = cat(ndims(r) + 1, r, t, p);
        end
    end
end

function [x, y, z] = SpherToCart(r, t, p)
    % Convert from spherical to cartesian coordinates.
    %
    % "physics" convention:
    % t (theta) is the zenith (from z axis),
    % p (phi) is the azimuth (in xy-plane from x).
    
    if nargin == 1
        % Coordinates were passed as vectors.
        d = find(size(r) == 3, 1);
        switch d
            case 1
                t = t(2, :); p = p(3, :); r = r(1, :);
            case 2
                t = r(:, 2); p = r(:, 3); r = r(:, 1);
            otherwise
                bst_error('Inputs should be three matrices with same sizes, or a single matrix with 3 columns or rows.');
        end
    elseif nargin ~= 3
        bst_error('Inputs should be three matrices with same sizes, or a single matrix with 3 columns or rows.');
    end
    
    x = r .* sin(t) .* cos(p);
    y = r .* sin(t) .* sin(p);
    z = r .* cos(t);
    
    if nargout == 1
        % Output as vectors.
        if size(x, 2) == 1
            x = [x, y, z];
        elseif size(x, 1) == 1
            x = [x; y; z];
        else
            x = cat(ndims(x) + 1, x, y, z);
        end
    end
    
end

function [XHat, YHat, ZHat] = TangentSpherToCart(x, t, p, RHat, THat, PHat)
    % Convert from tangent spherical (defined by spherical unit vectors) to
    % cartesian coordinates.
    %
    % Allowed inputs:
    %   LocationXYZ, TangentRTP
    %   LocX, LocY, LocZ, R, T, P
    %   [], LocT, LocP, R, T, P (LocR is not needed, so indicates spherical)
    %
    % "physics" convention:
    % t (theta) is the zenith (from z axis),
    % p (phi) is the azimuth (in xy-plane from x).
    
    if nargin == 2
        % Inputs are vectors.
        d = find(size(t) == 3, 1);
        switch d
            case 1
                RHat = p(1, :); THat = p(2, :); PHat = p(3, :);
            case 2
                RHat = p(:, 1); THat = p(:, 2); PHat = p(:, 3);
            otherwise
                bst_error('Input dimensions error.');
        end
        [~, t, p] = CartToSpher(t);
    elseif nargin ~= 6
        bst_error('Expecting 2 or 6 inputs.');
    elseif ~isempty(x)
        % First 3 inputs are cartiesian components.
        [~, t, p] = CartToSpher(x, t, p);
        % else % We were given t and p.
    end
    
    XHat = cos(p) .* (sin(t) .* RHat + cos(t) .* THat) - sin(p) .* PHat;
    YHat = sin(p) .* (sin(t) .* RHat + cos(t) .* THat) + cos(p) .* PHat;
    ZHat = cos(t) .* RHat - sin(t) .* THat;
    
    if nargout == 1
        % Output as vectors.
        if size(XHat, 2) == 1
            XHat = [XHat, YHat, ZHat];
        elseif size(XHat, 1) == 1
            XHat = [XHat; YHat; ZHat];
        else
            XHat = cat(ndims(XHat) + 1, XHat, YHat, ZHat);
        end
    end
end

function [RHat, THat, PHat] = CartToTangentSpher(x, t, p, ...
        XHat, YHat, ZHat)
    % Convert from cartesian to tangent spherical coordinates (defined by
    % spherical unit vectors).
    %
    % Allowed inputs:
    %   LocationXYZ, TangentXYZ
    %   LocX, LocY, LocZ, X, Y, Z
    %   [], LocT, LocP, X, Y, Z (LocR is not needed, so indicates spherical)
    %
    % "physics" convention:
    % t (theta) is the zenith (from z axis),
    % p (phi) is the azimuth (in xy-plane from x).
    
    if nargin == 2
        % Inputs are vectors.
        d = find(size(t) == 3, 1);
        switch d
            case 1
                XHat = p(1, :); YHat = p(2, :); ZHat = p(3, :);
            case 2
                XHat = p(:, 1); YHat = p(:, 2); ZHat = p(:, 3);
            otherwise
                bst_error('Input dimensions error.');
        end
        [~, t, p] = CartToSpher(t);
    elseif nargin ~= 6
        bst_error('Expecting 2 or 6 inputs.');
    elseif ~isempty(x)
        % First 3 inputs are cartesian components.
        [~, t, p] = CartToSpher(x, t, p);
        % else % We were given t and p.
    end
    
    RHat = sin(t) .* (cos(p) .* XHat + sin(p) .* YHat) + cos(t) .* ZHat;
    THat = cos(t) .* (cos(p) .* XHat + sin(p) .* YHat) - sin(t) .* ZHat;
    PHat = -sin(p) .* XHat + cos(p) .* YHat;
    
end


% function Samples = TimeToSample(Times, Prop)
%   % This function gives the sample indices as defined in the dataset.  So
%   % in particular it can be 0 and should not be used as a matrix index.
%   Samples = round((Times - Prop.times(1)) * Prop.sfreq) + 1 + Prop.samples(1);
% end



function dPdx = legendre_derivative(l, x, P)
    % Simplified version of https://github.com/rodyo/FEX-legendre_derivative
    % Returns size [l+1, nPoints].
    
    if nargin < 2
        error('Expecting more arguments.');
    end
    if ~ismatrix(x) || size(x, 1) > 1
        x = x(:).';
    end
    if nargin < 3 || isempty(P)
        P = legendre(l, x);
    end
    if size(P, 1) ~= l + 1 || size(P, 2) ~= size(x, 2)
        error('Dimension mismatch.');
    end
    
    if l == 0
        dPdx = zeros(1, numel(x));
        return;
    end
    
    m   = (0:l).';
    sqx = 1 - x.^2;
    dPdx = bsxfun( @rdivide, P .* bsxfun(@times, m, x) + ...
        [-P(2, :)/l/(l+1); P(1:end-1, :)] .*  ... % P_l(m-1), m = 0, rest
        bsxfun(@times, (l+m).*(l-m+1), sqrt(sqx)), ...
        sqx );
    
    % Handle edge cases.
    isEdge = abs(x)==1;
    if any(isEdge)
        xPow = x(isEdge).^(l+1);
        dPdx(1, isEdge) = xPow .* l*(l+1)/2;
        dPdx(2, isEdge) = x(isEdge).* xPow * inf; % For sign.
        if l > 1
            dPdx(3, isEdge) = -xPow * (l-1)*l*(l+1)*(l+2)/4;
            dPdx(4:end, isEdge) = 0;
        end
    end
    
end



function dPdt = legendre_derivative_t(l, x, P)
    % Derivative with respect to theta of associated Legendre of cos(theta).
    % This simply adds a -sin(t) factor, but it avoids having to deal with
    % infinities at abs(x)=1, when m=1.
    %
    % Returns size [l+1, nPoints].
    
    if nargin < 2
        error('Expecting more arguments.');
    end
    if ~ismatrix(x) || size(x, 1) > 1
        x = x(:).';
    end
    if nargin < 3 || isempty(P)
        P = legendre(l, x);
    end
    if size(P, 1) ~= l + 1 || size(P, 2) ~= size(x, 2)
        error('Dimension mismatch.');
    end
    
    if l == 0
        dPdt = zeros(1, numel(x));
        return;
    end
    
    m   = (0:l).';
    Sint = sqrt(1 - x.^2); % = sin(t)
    dPdt = -bsxfun(@times, m, x ./ Sint) .* P - ... % Global - sign from additional -sin(t) factor
        bsxfun(@times, (l+m).*(l+1-m), [-P(2, :)/l/(l+1); P(1:end-1, :)]); % P_l(m-1), m = 0, rest
    
    % Handle edge cases.
    % This was calculated using L'Hospital's rule and the recursion formula
    % used above. Only m=1 is non-zero.
    isEdge = abs(x)==1;
    if any(isEdge)
        dPdt(:, isEdge) = 0;
        dPdt(2, isEdge) = -x(isEdge).^(l) * l*(l+1)/2; % x^l or sign.
    end
    
end



function P = Intersect(A, B, Delta)
    % Compute an orthonormal basis for the intersection of two subspaces. A,
    % B and P columns have the same length.  Delta is an allowance for small
    % inaccuracies.  In other words, Delta slightly "enlarges" the
    % intersection.  Algorithm 12.4.3 of Golub and Van Loan, Matrix
    % Computations 3rd ed.
    
    % First obtain orthonormal bases of the range of A and B, by QR
    % decomposition.
    QA = qr(A, 0); % size [nA, nA]
    QB = qr(B, 0);
    %   C = QA' * QB; % size [nA, nB]
    
    % Use the SVD to find combinations of the Q basis vectors on each side (A
    % and B) such that their product is maximized.  Since all these vectors
    % are unit length, this product is the cosine of the angle between them.
    % Finally, since the SVD gives the singular values in decreasing order,
    % any intersection (with cos(0)=1) will appear first.
    [UA, DiagCos] = svd(QA' * QB, 'econ');
    % Find almost zero principal angles, thus cos almost 1.
    ZeroAngles = diag(DiagCos) >= (1 - Delta);
    
    % Corresponding principal vectors (identical on both A and B sides).
    P = QA * UA(:, ZeroAngles);
    
end



 % This function was copied from process_adjust_head_position.m for
 % efficiency.
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
    % back to the now adjusted Native system.  
    
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



