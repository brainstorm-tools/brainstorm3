function varargout = process_sss( varargin )
  % PROCESS_SSS: Spatiotemporal signal space separation with optional motion correction.
  %
  % DESCRIPTION:
  %
  
  % In this file, theta (or t) is the colatitude angle, from the z axis,
  % and phi (or p) is the longitude angle or azimuth.
  
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
  
  % TO DO: 
  % Deal with aborted recordings; all zeros.
  % Temporal SSS.
  % Translation for where to put harmonic expansion origin?
  % Units/dimensions for spherical harmonics?
  % tSSS, how long of chunks do we need for stable separation?
  % SSS, we need to keep track of the empty subspace as in SSP, for source modeling?
  % How would that work in combination?
  
  eval(macro_method);
end


%% ===== GET DESCRIPTION =====
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
  sProcess.options.spatial.Value   = 1;
  % Temporal cleaning
  sProcess.options.temporal.Comment = 'Temporal SSS: project out artefact timecourses.';
  sProcess.options.temporal.Type    = 'checkbox';
  sProcess.options.temporal.Value   = 1;
  % Spherical harmonic expansion order
  sProcess.options.exporder.Comment = 'Expansion order (out, in): ';
  sProcess.options.exporder.Type    = 'range';
  sProcess.options.exporder.Value   = {[6, 9], '', 0};
  
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) 
  LIn = sProcess.options.exporder.Value{1}(2);
  LOut = sProcess.options.exporder.Value{1}(1);
  nHarmonics = (LIn + 1)^2 + (LOut + 1)^2 - 2;
  % Seems no word wrap and no color.  Need small comments.
  if sProcess.options.temporal.Value && (LIn < 1 || LOut < 1)
    Comment = 'Error: tSSS cleaning requires orders [1, 1] or more.';
  elseif sProcess.options.spatial.Value && (LIn < 1 || LOut < 0)
    Comment = 'Error: SSS cleaning requires orders [0, 1] or more.';
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


%% ===== RUN =====
function sInput = Run(sProcess, sInput)
  
  % Parse options.
  LIn = sProcess.options.exporder.Value{1}(2);
  LOut = sProcess.options.exporder.Value{1}(1);
  if sProcess.options.temporal.Value && (LIn < 1 || LOut < 1)
    bst_error('tSSS requires SSS cleaning and expansion orders at minimum [1, 1].');
  end
  if sProcess.options.spatial.Value && (LIn < 1 || LOut < 0)
    bst_error('SSS cleaning requires expansion orders at minimum [0, 1].');
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
  % 
  iRef = good_channel(ChannelMat.Channel, [], 'MEG REF');
  iMeg = good_channel(ChannelMat.Channel, ChannelMat.ChannelFlag, 'MEG');
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
    sInput.A(iMeg,:) = sInput.A(iMeg,:) + ChannelMat.MegRefCoef * sInput.A(iRef,:);
  end
   
  % Need to keep this after CTF compensation.
  iMegRef = sort([iRef, iMeg]);
  nChannels = numel(iMegRef);
  
  % Adjust the maximum expansion orders based on number of channels. 
  nHarmonics = @(L1, L2) (L1 + 1)^2 + (L2 + 1)^2 - 2;
  if sProcess.options.motion.Value && ~sProcess.options.spatial.Value && ...
      ~sProcess.options.temporal.Value
    % Only doing head motion correction, use as many harmonics as channels.
    % Not sure which basis is best here: but if we use the reference
    % channels, probably best to have at least some "out" harmonics.
    LIn = ceil(sqrt(nChannels + 1) - 1);
    LOut = ceil(LIn / 3);
  end
  % Don't use more harmonics than needed.
  if nHarmonics(LIn, LOut) > nChannels
    while nHarmonics(LIn, LOut) >= nChannels
      if LOut >= LIn
        LOut = LOut - 1;
      else
        LIn = LIn - 1;
      end
    end
    LIn = LIn + 1;
    if LIn < sProcess.options.exporder.Value{1}(2)
      fprintf(['BST> SSS: Asked for too many harmonics; expansion order [%d, %d] => %d harmonics.\n', ...
        'Using [%d, %d] => %d harmonics instead, more than enough for %d channels.\n'], ...
        sProcess.options.exporder.Value{1}, ...
        nHarmonics(sProcess.options.exporder.Value{1}(1), sProcess.options.exporder.Value{1}(2)), ...
        LOut, LIn, nHarmonics(LIn, LOut), nChannels);
    end
  end
  
    
  % Get channel locations and orientations per sensor coil. 
  [InitLoc, InitOrient, CoilToChannel] = ...
    CoilGeometry(ChannelMat.Channel, ChannelMat.ChannelFlag);
  
  % We may want to translate the coil locations such that the origin of the
  % spherical harmonic expansion is better centered on the brain.
  %   InitLoc = bsxfun(@minus, InitLoc, ExpansionOrigin);
  
  % Get the SSS basis matrix for inside and outside sources at the
  % reference head position.
  [InitSIn, InitSOut] = SphericalBasis(LIn, LOut, InitLoc, InitOrient, CoilToChannel);
  
  if sProcess.options.motion.Value
    % For head motion correction, compute sensor locations through time.
    
    % Verify that we can compute the transformation from initial to
    % each continuous head tracking position.
    if ~strcmp(ChannelMat.TransfMegLabels{1}, 'Dewar=>Native')
      bst_error('Dewar=>Native transformation not first.');
    end
    
    % Compute initial head location.  This isn't exactly the coil positions
    % in the .hc file, but was verified to give the same transformation.
    % Use the SCS distances from origin, with left and right PA points
    % symmetrical.
    LeftRightDist = sqrt(sum((ChannelMat.SCS.LPA - ChannelMat.SCS.RPA).^2));
    InitHeadCoilLoc = [[ChannelMat.SCS.NAS(1); 0; 0; 1], [0; LeftRightDist; 0; 1], ...
      [0; -LeftRightDist; 0; 1]];
    InitHeadCoilLoc = ChannelMat.TransfMeg{1} \ InitHeadCoilLoc;
    InitHeadCoilLoc(4, :) = [];
    InitHeadCoilLoc = InitHeadCoilLoc(:);
        
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
      HeadSamplePeriod = min(HeadSamplePeriod, min(diff(TrueSamples)));
    end
    HeadCoilLoc = HeadCoilLoc(:, 1:HeadSamplePeriod:nSamples);
      
%       nEpochs = size(HeadCoilLoc, 3);
    nHeadSamples = size(HeadCoilLoc, 2);
%       for iEpoch = 1:nEpochs
%         % Samples in this trial.
%         nSamples = diff(sFile.prop.samples) + 1; % This is single epoch samples if epoched.
    % In case the recording was aborted.
    iLastSample = nSamples;
    for iHeadSample = 1:nHeadSamples
      % If a collection was aborted, the channels will be filled with
      % zeros. We must ignore these samples.
      if all(HeadCoilLoc(:, iHeadSample)) == 0
        iLastSample = (iHeadSample - 1) * HeadSamplePeriod;
        break;
      end
      
      %           B = in_fread(sFile, ChannelMat, iEpoch, SampleBounds, iMegRef);
      % Compute transformation corresponding to coil position.
      TransfMat = process_adjust_head_position('LocationTransform', ...
        HeadCoilLoc(:, iHeadSample), ChannelMat.TransfMeg);
      
      % Modify channel positions.
      %       ChannelMat = channel_apply_transf(ChannelMat, TransfMat, [], false);
      Loc = bsxfun(@plus, TransfMat(1:3, 1:3) * InitLoc, TransfMat(1:3, 4));
      Orient = TransfMat(1:3, 1:3) * InitOrient;
      
      % Get the SSS basis matrix for inside and outside sources.
      [SIn, SOut] = SphericalBasis(LIn, LOut, Loc, Orient, CoilToChannel);
      
      % Get data corresponding to this head sample.
      SampleStart = (iHeadSample - 1) * HeadSamplePeriod + 1;
      SampleBounds = [SampleStart, min(SampleStart+HeadSamplePeriod, nSamples)];
      
      % Compute coefficients as function of time.
      SpherCoeffs = [SIn, SOut] \ sInput.A(iMegRef, SampleBounds);
      
      % Project back to sensor space and at reference head position.
      if sProcess.options.spatial.Value
        % Clean using inside basis only.
        sInput.A(iMegRef, SampleBounds) = InitSIn * SpherCoeffs(1:size(InitSIn, 2), :);
      else
        % Use complete basis.
        sInput.A(iMegRef, SampleBounds) = [InitSIn, InitSOut] * SpherCoeffs;
      end
      
      %       SampleStart = SampleStart + SampleBounds(2) - SampleBounds(1) + 1;
    end % Head samples loop
    %       end % Epochs loop
    
    % Also modify the head coil channels, such that the fact we
    % corrected for motion is known by other processes.
    for c = 1:numel(iHLU)
      sInput.A(iHLU(c), 1:iLastSample) = InitHeadCoilLoc(c);
    end
    
  else % don't correct for head motion
%       % Get all the data, possibly in chunks.
%       nEpochs = numel(sFile.epochs);
%       if nEpochs == 0
%         nEpochs = 1;
%       end
%       for iEpoch = 1:nEpochs
%         % Samples in this trial.
%         nSamples = diff(sFile.prop.samples) + 1; % This is single epoch samples if epoched.
%         % Current starting sample.
%         SampleStart = 1;
%         ChunkSize = nSamples;
%         while SampleStart <= nSamples
%           B = in_fread(sFile, ChannelMat, iEpoch, ...
%             [SampleStart, min(SampleStart + ChunkSize - 1, nSamples)], iMeg);
    % Compute coefficients as function of time.
    SpherCoeffs = [InitSIn, InitSOut] \ sInput.A(iMegRef, :);
    % Can split them into In and Out components.
    
    if sProcess.options.spatial.Value
      % Project back to sensor space using inside basis only.
      sInput.A(iMegRef, :) = InitSIn * SpherCoeffs(1:size(InitSIn, 2), :);
    end
    
%           SampleStart = SampleStart + size(B, 2);
%         end
%       end
      
  end % if correct for head motion
    
  if sProcess.options.temporal.Value
    % Temporal SSS
    nIn = size(InitSIn, 2);
    L = Intersect(SpherCoeffs(1:nIn, :), SpherCoeffs((nIn+1):end, :), ...
      TemporalIntersectAllowance);
  end
    
    
  if isUndoCtfComp
    sInput.A(iMeg,:) = sInput.A(iMeg,:) - ChannelMat.MegRefCoef * sInput.A(iRef,:);
  end
%   end
  
end



function [Loc, Orient, CoilToChannel] = CoilGeometry(Channel, Flag)
  % Get channel locations and orientations per coil. They were converted to
  % 4 points per coil when the dataset was first loaded. We could have an
  % option to keep the 4 points, but it really seems unnecessary, so for
  % efficiency, keep one location and one orientation per coil.
  iMegRef = sort([good_channel(Channel, [], 'MEG REF'), ...
    good_channel(Channel, Flag, 'MEG')]);
  nChannels = numel(iMegRef);

  Loc = zeros(3, 2*nChannels);
  Orient = Loc;
  CoilToChannel = zeros(nChannels, 2*nChannels);
  iCoil = 1;
  for c = 1:nChannels
    cc = iMegRef(c);
    nChanLocPts = size(Channel(cc).Loc, 2);
    switch nChanLocPts
      case 4
        Loc(:, iCoil) = mean(Channel(cc).Loc(:, 1:4), 2);
        Orient(:, iCoil) = Channel(cc).Orient(:, 1);
        CoilToChannel(c, iCoil) = sum(Channel(cc).Weight(:, 1:4), 2);
        iCoil = iCoil + 1;
      case 8
        Loc(:, iCoil+(0:1)) = [ mean(Channel(cc).Loc(:, 1:4), 2), ...
          mean(Channel(cc).Loc(:, 5:8), 2) ];
        Orient(:, iCoil+(0:1)) = Channel(cc).Orient(:, [1,5]);
        CoilToChannel(c, iCoil+(0:1)) = [ sum(Channel(cc).Weight(:, 1:4), 2), ...
          sum(Channel(cc).Weight(:, 5:8), 2) ];
        iCoil = iCoil + 2;
      otherwise
        bst_error('Unexpected number of coil location points.');
    end
  end
  nCoils = iCoil - 1;
  Loc(:, nCoils+1:end) = [];
  Orient(:, nCoils+1:end) = [];
  CoilToChannel(:, nCoils+1:end) = [];
end



function [SIn, SOut] = SphericalBasis(LIn, LOut, Loc, Orient, CoilToChannel, isRealBasis)
  % Build the S matrix that relates the measured magnetic field
  % to the spherical harmonic coefficients: B = S * x
  %  Loc and Orient are size 3 x nSensors.
  
  if nargin < 6 || isempty(isRealBasis)
    isRealBasis = true;
  end
  if nargin < 5
    error('Expecting more arguments.');
  end
  
  % Convert sensor locations to spherical coordinates.
  [r, t, p] = cart2spher(Loc'); % Column vectors.
  
  % Evaluate spherical harmonics at sensor locations.
  SIn = zeros(size(Loc, 2), (LIn+1)^2 - 1);
  SOut = zeros(size(Loc, 2), (LOut+1)^2 - 1);
  iS = 1;
  for l = 1:max(LIn, LOut)
    [Y, m, dYdt] = SphericalHarmonics(l, t, p, isRealBasis);
    
    if l <= LIn
      %  Inside
      % "Magnetic field harmonics" = - gradient of "potential harmonics".
      % Here in spherical coordinates.
      SRorX = bsxfun(@times, -1/r.^(l+2), -(l+1) * Y);
      STorY = bsxfun(@times, -1/r.^(l+2), dYdt);
      if isRealBasis
        SPorZ = bsxfun(@times, -1/r.^(l+2) ./ sin(t), m) .* Y(:, [1, (l+2):end, 2:(l+1)]);
      else % complex basis
        SPorZ = bsxfun(@times, -1/r.^(l+2) ./ sin(t), 1i * m) .* Y;
      end
      % Project along sensor orientations.
      [SRorX, STorY, SPorZ] = spher2cart(SRorX, STorY, SPorZ);
      SIn(:, iS:iS+2*l) = bsxfun(@times, Orient(1, :)', SRorX) + ...
        bsxfun(@times, Orient(2, :)', STorY) + ...
        bsxfun(@times, Orient(3, :)', SPorZ);
    end
    if l <= LOut
      %  Outside
      % "Magnetic field harmonics" = - gradient of potential.
      % Here in spherical coordinates.
      SRorX = bsxfun(@times, r.^(l-1), l * Y);
      STorY = bsxfun(@times, r.^(l-1), dYdt);
      if isRealBasis
        SPorZ = bsxfun(@times, -1/r.^(l+2) ./ sin(t), m) .* Y(:, [1, (l+2):end, 2:(l+1)]);
      else % complex basis
        SPorZ = bsxfun(@times, -1/r.^(l+2) ./ sin(t), 1i * m) .* Y;
      end
      % Project along sensor orientations.
      [SRorX, STorY, SPorZ] = spher2cart(SRorX, STorY, SPorZ);
      SOut(:, iS:iS+2*l) = bsxfun(@times, Orient(1, :)', SRorX) + ...
        bsxfun(@times, Orient(2, :)', STorY) + ...
        bsxfun(@times, Orient(3, :)', SPorZ);
    end
    
    iS = iS + 2 * l + 1;
  end % l loop
  
  % Convert coil values to channels.
  SIn = CoilToChannel * SIn;
  SOut = CoilToChannel * SOut;
  % Remove basis vectors beyond number of channels.
  nChannels = size(CoilToChannel, 1);
  nOut = size(SOut, 2);
  SIn(:, (nChannels - nOut + 1):end) = [];
end



function [Y, m, dYdt, P] = SphericalHarmonics(l, t, p, isRealBasis)
  % Returns Y (size [nPoints, 2l+1]) for all values of m from -l to l,
  % ordered as m = [0 to l, -1 to -l]. t and p can be vectors, of identical
  % size. Choice of real (default) or complex basis.
  
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
  P = legendre(l, Cost).'; % size [nPoints, l+1]
  % Factorial factors.
  Fact = zeros(1, l);
  for m = 1:l
    Fact(m) = sqrt( 1 ./ prod((l+m):-1:(l-m+1)) );
  end
  if nargout > 2
    dPdt = legendre_derivative(l, P', Cost').';
  end
  
  Factor2 = sqrt((2*l + 1) / (4*pi));
  m = (1:l);
  if isRealBasis
    Y = [ Factor2 * P(:, 1), ... % m = 0
      sqrt(2) * Factor2 * bsxfun( @times, (-1).^[m, m] .* [Fact, Fact], ...
      P(:, [m, m]) ) .* ...
      [cos(bsxfun(@times, m, p)), sin(bsxfun(@times, m, p))] ];
    
    if nargout > 2
      % Also compute derivative of Y with respect to theta.
      dYdt = [ Factor2 * bsxfun(@times, -sin(t), dPdt(:, 1)), ... % m = 0
        sqrt(2) * Factor2 * bsxfun( @times, (-1).^[m, m] .* [Fact, Fact], ...
        -sin(t) ) .* dPdt(:, [m, m]) .* ...
        [cos(bsxfun(@times, m, p)), sin(bsxfun(@times, m, p))] ];
    end
    if nargout > 3
      % Get P for negative m, even though they're not used in real
      % harmonics.
      P = [P, bsxfun(@times, (-1).^m .* Fact(m), P(:, 2:end))]; % size [nPoints, 2l+1]
    end
    
    m = [0:l, -1:-1:-l];

  else % complex basis
    % Need P for negative m.
    P = [P, bsxfun(@times, (-1).^m .* Fact(m), P(:, 2:end))]; % size [nPoints, 2l+1]
    if nargout > 2
      dPdt = [dPdt, bsxfun(@times, (-1).^m .* Fact(m), dPdt(:, 2:end))]; % size [nPoints, 2l+1]
    end
    Fact = [1, Fact, 1./Fact]; % size [1, 2l+1]
    
    m = [0:l, -1:-1:-l];
    Y = Factor2 * bsxfun(@times, Fact, P) .* exp(1i * bsxfun(@times, m, p));
    if nargout > 2
      % Also compute derivative of Y with respect to theta.
      dYdt = Factor2 * bsxfun(@times, Fact, -sin(t)) .* dPdt .* ...
         exp(1i * bsxfun(@times, m, p));
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
    Fact = [1/4 sqrt(5/pi), -1/2 sqrt(15/pi), 1/4 sqrt(15/pi), ...
      -1/2 sqrt(15/pi), 1/4 sqrt(15/pi)];
    PhiPart = [1, cos(p), cos(2*p), sin(p), sin(2*p)];
  else % complex basis
    Fact = [1/4 sqrt(5/pi), -1/2 sqrt(15/(2*pi)), 1/4 sqrt(15/(2*pi)), ...
      1/2 sqrt(15/(2*pi)), 1/4 sqrt(15/(2*pi))];
    PhiPart = [1, exp(1 * 1i * p), exp(2 * 1i * p), ...
      exp(-1 * 1i * p), exp(-2 * 1i * p)];
  end
  Y = bsxfun(@times, Fact, ThetaPart .* PhiPart);
end



function [r, t, p] = cart2spher(x, y, z)
  % Convert from cartesian to spherical coordinates.
  %
  % "physics" convention:
  % t (theta) is the zenith (from z axis),
  % p (phi) is the azimuth (in xy-plane from x).
  
  if nargin == 1 && size(x, 2) == 3
    % Coordinates were passed as vector.
    y = x(:, 2);
    z = x(:, 3);
    x = x(:, 1);
  elseif nargin < 3 || size(x, 2) > 1 || size(y, 2) > 1 || size(z, 2) > 1
    bst_error('Inputs should be column vectors, or a single matrix with 3 columns.');
  end
  
  r = sqrt(x.^2 + y.^2 + z.^2);
  % Handle zero length case.
  n = size(x, 1);
  t = zeros(n, 1);
  p = zeros(n, 1);
  iOk = r ~= 0;
  t(iOk) = acos(z(iOk)./r(iOk)); % Between 0 and pi.
  p(iOk) = atan2(y(iOk), x(iOk));
  
  if nargout == 1
    % Output as vector.
    r = [r, t, p];
  end
end

function [x, y, z] = spher2cart(r, t, p)
  % Convert from spherical to cartesian coordinates.
  %
  % "physics" convention:
  % t (theta) is the zenith (from z axis),
  % p (phi) is the azimuth (in xy-plane from x).
  
  if nargin == 1 && size(r, 2) == 3
    % Coordinates were passed as vector.
    t = r(:, 2);
    p = r(:, 3);
    r = r(:, 1);
  end
  
  x = r .* sin(t) .* cos(p);
  y = r .* sin(t) .* sin(p);
  z = r .* cos(t);
  
  if nargout == 1
    % Output as vector.
    x = [x, y, z];
  end
  
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


