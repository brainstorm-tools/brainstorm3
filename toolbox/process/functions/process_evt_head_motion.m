function varargout = process_evt_head_motion(varargin)
% PROCESS_EVT_HEAD_MOTION: Create extended events for stable head position and bad head motion.

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
% Authors: Elizabeth Bock, Francois Tadel, Marc Lalancette, 2013-2018

eval(macro_method);
end



%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description of the process
    sProcess.Comment     = 'Detect head motion (CTF)';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadMotion#Mark_head_motion_events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 48;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Definition of the options
    sProcess.options.warning.Comment = 'Only for CTF MEG recordings with HLC channels recorded.<BR><BR>';
    sProcess.options.warning.Type    = 'label';
    % Channel names
    %Na = HLC0011,12,13 (meters) fit error = HLC0018
    %Le = HLC0021,22,23 (meters) fit error = HLC0028
    %Re = HLC0031,32,33 (meters) fit error = HLC0038
    % === Movement Threshold
    sProcess.options.thresh.Comment = 'Movement threshold: ';
    sProcess.options.thresh.Type    = 'value';
    sProcess.options.thresh.Value   = {5, 'mm', []};
    % === Minimum movement segment length
    sProcess.options.minSegLength.Comment  = 'Minimum split length: ';
    sProcess.options.minSegLength.Type     = 'value';
    sProcess.options.minSegLength.Value    = {5, 's', []};
    % === Fit Error
    sProcess.options.fiterror.Comment = 'Detect head coil fit errors ';
    sProcess.options.fiterror.Type    = 'checkbox';
    sProcess.options.fiterror.Value   = 0;
    % === Fit Error Tolerance
    sProcess.options.fitthresh.Comment = 'Fit error tolerance: ';
    sProcess.options.fitthresh.Type    = 'value';
    sProcess.options.fitthresh.Value   = {3, '%', []};
    %   sProcess.options.allowance.Comment = 'Fit threshold allowance: ';
    %   sProcess.options.allowance.Type    = 'value';
    %   sProcess.options.allowance.Value   = {5, '%', []};
    
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Find stable, bad head motion and bad head coil fit segments.
    %
    % MoveSegments and FitSegments are a list of extended events, so start
    % and end samples of these two kinds of segments.  FitSegments represent
    % the head coil fit error, below or above the given threshold, with
    % hysteresis.
    
    nFiles = length(sInputs);
    
    isFileOk = false(1, length(sInputs));
    bst_progress('start', 'Detect head motion events', ...
        'Loading HLU locations...', 0, 2*nFiles);
    for iFile = 1:length(sInputs)
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'Time', 'Device');
            sFile = DataMat.F;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Time', 'Device');
            sFile = in_fopen(sInputs(iFile).FileName, 'BST-DATA');
        end
        % Check for CTF.
        if ~strcmp(DataMat.Device, 'CTF')
            bst_report('Error', sProcess, sInputs(iFile), ...
                'Detect head motion events is currently only available for CTF data.');
        end
        % Process only continuous files for now.
        if ~isempty(sFile.epochs)
            bst_report('Error', sProcess, sInputs(iFile), ...
                'This function can only process continuous recordings (no epochs).');
            continue;
        end
        
        % Load head coil locations.
        bst_progress('text', 'Loading HLU locations...');
        bst_progress('inc', 1);
        [Locations, HeadSamplePeriod, FitErrors] = LoadHLU(sInputs(iFile));
        if isempty(Locations)
            % No HLU channels.  Error already reported.
            continue;
        end
        bst_progress('text', 'Detecting motion events...');
        bst_progress('inc', 1);
        nSxnT = size(Locations, 2); % floor(nSamples/HeadSamplePeriod) * nEpochs
        
        % Find motion events, high motion and bad fit segments.
        MinLength = sProcess.options.minSegLength.Value{1} * ...
            sFile.prop.sfreq / HeadSamplePeriod; % seconds -> (down.)samples
        Thresh = sProcess.options.thresh.Value{1} / 1000; % mm -> m
        DoFit = sProcess.options.fiterror.Value;
        FitErrorThresh  = sProcess.options.fitthresh.Value{1} / 100;
        ThreshAllowance = 0.05; %sProcess.options.allowance.Value{1} / 100; % percent to decimal
        
        if Thresh <= 0
            bst_error('Movement threshold should be a positive value.');
        end
        m = 0;
        iStart = 1;
        isBadMove = false(0);
        MoveSegments = [];
        D = zeros(nSxnT, 1);
        while iStart < nSxnT
            % Reference location is position at start of current segment.
            InitLoc = Locations(:, iStart);
            % Deal with aborted recordings, where all channels, including head
            % coil locations, are zeros.  This will be the last segment.
            if all(InitLoc == 0)
                iMove = nSxnT+1;
            else
                % Get motion distance from reference location, as most distant point
                % on a sphere that follows the motion defined by the head coils.
                % This replaces the 9 HLU channels and better captures any type of
                % head movement.
                D(iStart:end) = RigidDistances(Locations(:, iStart:end), ...
                    InitLoc, Thresh);
                iMove = find(D(iStart:end) > Thresh, 1, 'first') + iStart - 1;
                if isempty(iMove)
                    % Last segment.
                    iMove = nSxnT+1;
                end
            end
            if iMove - iStart < MinLength
                if m > 0 && isBadMove(m)
                    % Short bad segment continues; do nothing.
                else
                    % New short bad segment.
                    m = m + 1;
                    isBadMove(m) = true;
                    MoveSegments(m) = iStart; %#ok<AGROW>
                end
            else
                % New long good segment.
                m = m + 1;
                isBadMove(m) = false;
                MoveSegments(m) = iStart; %#ok<AGROW>
            end
            iStart = iMove;
        end
        
        % Convert back to samples at original sampling rate.  But these are
        % indices, not "Brainstorm samples", which are linked to time values.
        MoveSegments = (MoveSegments - 1) * HeadSamplePeriod + 1;
        
        % Convert to extended events.
        % MoveSegments and FitSegments cannot be empty here.
        MoveSegments = [MoveSegments; ...
            MoveSegments(2:end) - 1, nSxnT * HeadSamplePeriod];
        StableHead = MoveSegments(:, ~isBadMove);
        BadHeadMotion = MoveSegments(:, isBadMove);
        
        % Convert once more, to time values.
        StableHead = (StableHead - 1) / sFile.prop.sfreq + DataMat.Time(1);
        BadHeadMotion = (BadHeadMotion - 1) / sFile.prop.sfreq + DataMat.Time(1);
        
        % Add to event structure.
        sFile = CreateEvents(sFile, 'StableHead', StableHead);
        sFile = CreateEvents(sFile, 'BadHeadMotion', BadHeadMotion);
        
        if DoFit
            % Large fit errors.
            % Use maximum error among coils.
            FitErrors = max(FitErrors);
            % Find bad and good segments, with hysteresis
            isBadFit = FitErrors > FitErrorThresh;
            isGoodFit = FitErrors <= FitErrorThresh * (1-ThreshAllowance);
            for i = 1:nSxnT
                if ~isBadFit(i) && ~isGoodFit(i) % in "hysteresis band"
                    if i ~= 1 && isBadFit(i-1)
                        isBadFit(i) = true;
                        % We don't need isGoodFit as it will be the opposite of isBadFit.
                        %   else
                        %     isGoodFit(i) = true;
                    end
                end
            end
            clear isGoodFit % To avoid confusion.
            FitSegments = [1, find(diff(isBadFit) ~= 0) + 1];
            % Ignore single sample segments.
            FitSegments([false, diff(FitSegments) == 1]) = [];
            isBadFit = isBadFit(FitSegments);
            
            % Convert back to samples at original sampling rate.  But these are
            % indices, not "Brainstorm samples", which are linked to time values.
            FitSegments = (FitSegments - 1) * HeadSamplePeriod + 1;
            
            % Convert to extended events.
            % MoveSegments and FitSegments cannot be empty here.
            FitSegments = [FitSegments; ...
                FitSegments(2:end) - 1, nSxnT * HeadSamplePeriod];
            BadHeadFit = FitSegments(:, isBadFit);
            
            % Convert once more, to time values.
            BadHeadFit = (BadHeadFit - 1) / sFile.prop.sfreq + DataMat.Time(1);
            
            % Add to event structure.
            sFile = CreateEvents(sFile, 'BadHeadFit', BadHeadFit);
        end
        
        % Save results.
        if isRaw
            DataMat.F = sFile;
        else
            DataMat.Events = sFile.events;
        end
        DataMat = rmfield(DataMat, 'Time');
        % Save file definition
        bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
        
        isFileOk(iFile) = true;
    end
    bst_progress('stop');
    
    % Return the input files that were processed properly.
    OutputFiles = {sInputs(isFileOk).FileName};
    
end


function sFile = CreateEvents(sFile, EvtName, Events)
    % Basic events structure
    if ~isfield(sFile, 'events') || isempty(sFile.events)
        sFile.events = repmat(db_template('event'), 0);
    end
    
    % Get the event to create.  Overwrite if it exists.
    iEvt = find(strcmpi({sFile.events.label}, EvtName));
    if isempty(Events)
        % Remove empty events.
        if ~isempty(iEvt)
            sFile.events(iEvt) = [];
        end
        return;
    end
    if isempty(iEvt)
        % Initialize new event.
        iEvt = length(sFile.events) + 1;
        sFile.events(iEvt).label = EvtName;
        sFile.events(iEvt).color = panel_record('GetNewEventColor', iEvt, sFile.events);
    end
    sFile.events(iEvt).times      = Events;
    sFile.events(iEvt).epochs     = ones(1, size(sFile.events(iEvt).times,2));
    sFile.events(iEvt).reactTimes = [];
    sFile.events(iEvt).channels   = cell(1, size(sFile.events(iEvt).times, 2));
    sFile.events(iEvt).notes      = cell(1, size(sFile.events(iEvt).times, 2));
end



function [Locations, HeadSamplePeriod, FitErrors] = LoadHLU(sInput, SamplesBounds, ReshapeContinuous)
    % Load and downsample continuous head localization channels.
    % HeadSamplePeriod is in (MEG) samples per (head) sample, not seconds.
    % Locations are in meters, [nChannels, nSamples, nEpochs] possibly converted to continuous.
    
    % For now removing bad segments is done in process_adjust_coordinates only.
    %     , RemoveBadSegments
    %     if nargin < 4 || isempty(RemoveBadSegments)
    %         RemoveBadSegments = false;
    %     end
    
    if nargin < 3 || isempty(ReshapeContinuous)
        ReshapeContinuous = true;
    end
    
    % Load the raw file descriptor
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F');
        sFile = DataMat.F;
    else
        sFile = in_fopen(sInput.FileName, 'BST-DATA');
    end
    
    nEpochs = numel(sFile.epochs);
    if nEpochs == 0
        nEpochs = 1;
    end
    if nargin < 2 || isempty(SamplesBounds)
        SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq); % This is single epoch samples if epoched.
    end
    
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    
    nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;
    
    iHLU = find(strcmp({ChannelMat.Channel.Type}, 'HLU'));
    [Unused, iSortHlu] = sort({ChannelMat.Channel(iHLU).Name});
    iFitErr = find(strcmp({ChannelMat.Channel.Type}, 'FitErr'));
    [Unused, iSortFitErr] = sort({ChannelMat.Channel(iFitErr).Name});
    nChannels = numel(iHLU);
    if nChannels < 9
        bst_report('Error', 'process_evt_head_motion', sInput, ...
            'LoadHLU > Head coil position channels not found.');
        Locations = [];
        HeadSamplePeriod = [];
        FitErrors = [];
        return;
    end
    
    % Load a max of 100Mb into memory to determine HeadSamplePeriod:
    % 100MB = 9chan * samples * 8bytes => samples ~ 1.5e6
    LoadSamples = 1.5e6;
    LoadEpochs = min(nEpochs, ceil(nSamples / LoadSamples));
    if LoadEpochs == 1
        LoadSamples = min(nSamples, LoadSamples);
    else
        LoadSamples = nSamples;
    end
    Locations = zeros(nChannels, LoadSamples, LoadEpochs);
    for t = 1:LoadEpochs
        Locations(:, :, t) = in_fread(sFile, ChannelMat, t, ...
            SamplesBounds(1) + [0, LoadSamples-1], iHLU);
    end
    
    % Downsample head localization channels to their real sampling rate.
    HeadSamplePeriod = LoadSamples; % Initialized to at least 1 point per epoch.
    for t = 1:LoadEpochs
        % Downsample to real localization sampling rate.  To find it, look for
        % changes in data, but it seems it's common to get repeated values
        % (code must have some condition where it just keeps the same value),
        % so we need to verify carefully.  First, find times of changes.  This
        % already ignores the first few samples until the first change.
        TrueSamples = find(any(diff(Locations(:, :, t), 1, 2), 1)) + 1;
        % Then get the time intervals between these changes, and find the
        % smallest "step" between these intervals.  E.g. if we got intervals of
        % 80, 120, 240 samples, the smallest difference between these would be
        % 40, which is the sampling period we were looking for.
        if numel(TrueSamples) <= 1
            continue; % to avoid empty which propagates in min and "erases" our previous good min.
        end
        % TO DO: The last diff(TrueSamples) is wrong somehow.  Need to figure
        % this out but for now just ignore it.
        HeadSamplePeriod = min(HeadSamplePeriod, min(diff(TrueSamples(1:end-1))));
    end
    % Downsample.
    Locations = Locations(:, 1:HeadSamplePeriod:LoadSamples, :);
    %   nS = ceil(nS / HeadSamplePeriod);
    
    if LoadSamples < nSamples
        Locations = zeros(nChannels, ceil(nSamples/HeadSamplePeriod), nEpochs);
        % Long epoch(s); load by channel.
        % An hour of data at the maximum sampling rate is 330MB per channel.
        % So presume we can always load a single channel into memory.
        for t = 1:nEpochs
            for c = 1:nChannels
                ChannelData = in_fread(sFile, ChannelMat, t, ...
                    SamplesBounds, iHLU(c));
                Locations(c, :, t) = ChannelData(1, 1:HeadSamplePeriod:nSamples);
            end
        end
    else
        % Load all channels at once, continue from previously loaded epochs.
        for t = (LoadEpochs+1):nEpochs
            ChannelData = in_fread(sFile, ChannelMat, t, SamplesBounds, iHLU);
            Locations(:, :, t) = ChannelData(:, 1:HeadSamplePeriod:nSamples);
        end
    end
    
    % size(Locations) is [nChannels, nSamples, nEpochs]
    if ReshapeContinuous
        % Convert to continuous.
        Locations = reshape(Locations, nChannels, []);
        %   nSxnT = floor(nSamples/HeadSamplePeriod) * nEpochs;
    end
    
    % In case channels were renamed to fix swapped coils.
    Locations = Locations(iSortHlu, :, :);
    
    % Also load head coil fitting errors if needed.
    if nargout > 2
        nFitChan = nChannels/3;
        FitErrors = zeros(nFitChan, ceil(nSamples/HeadSamplePeriod), nEpochs);
        
        if LoadSamples < nSamples
            % Long epoch(s); load by channel.
            % An hour of data at the maximum sampling rate is 330MB per channel.
            % So presume we can always load a single channel into memory.
            for t = 1:nEpochs
                for c = 1:(nChannels/3)
                    ChannelData = in_fread(sFile, ChannelMat, t, ...
                        SamplesBounds, iFitErr(c));
                    FitErrors(c, :, t) = ChannelData(1, 1:HeadSamplePeriod:nSamples);
                end
            end
        else
            % Load all channels at once, continue from previously loaded epochs.
            for t = (LoadEpochs+1):nEpochs
                ChannelData = in_fread(sFile, ChannelMat, t, SamplesBounds, iFitErr);
                FitErrors(:, :, t) = ChannelData(:, 1:HeadSamplePeriod:nSamples);
            end
        end
        
        if ReshapeContinuous
            % Convert to continuous.
            FitErrors = reshape(FitErrors, nFitChan, []);
        end
        
        % In case channels were renamed to fix swapped coils.
        FitErrors = FitErrors(iSortFitErr, :, :);
    end % if do FitError
end



function D = RigidDistances(Locations, Reference, StopThreshold)
    % Maximum distance traveled by any point in a moving sphere.
    %
    % Maximum distance within a spherical volume, given its translation and
    % rotation about origin.  The formula used is equivalent to 2*R*sin(a/2)
    % where a is the angle of the single rotation equivalent to the original
    % translation+rotation, and R is the distance from that axis to the
    % furthest edge of the sphere.  For the sphere radius, we use the maximum
    % coil distance from the origin in the rigid body reference.  This is
    % done independently for each time sample.
    %
    % StopThreshold gives the option to interrupt the computation when a
    % certain distance is reached.  The subsequent distances will default to
    % zero.
    
    if nargin < 3 || isempty(StopThreshold)
        StopThreshold = false;
    end
    
    if size(Locations, 1) ~= 9 || size(Reference, 1) ~= 9
        bst_error('Expecting 9 HLU channels in first dimension.');
    end
    nS = size(Locations, 2);
    nT = size(Locations, 3);
    
    % Calculate distances.
    
    Reference = reshape(Reference, [3, 3]);
    % Reference "head origin" and inverse "orientation matrix".
    [YO, YR] = RigidCoordinates(Reference);
    % Sphere radius.
    r = max( sqrt(sum((Reference - YO(:, [1, 1, 1])).^2, 1)) );
    if any(YR(:)) % any ignores NaN and returns false for empty.
        YI = inv(YR); % Faster to calculate inverse once here than "/" in loop.
    else
        YI = YR;
    end
    
    %   SinHalf = zeros([nS, 1, nT]);
    %   Axis = zeros([nS, 3, nT]);
    D = zeros([nS, nT]);
    for t = 1:nT
        for s = 1:nS
            [XO, XR] = RigidCoordinates(Locations(:, s, t));
            % Translation from X "head origin" to Y "head origin".
            T = XO - YO;
            % Rotation from X to Y (both with their "head origin" subtracted, so
            % it is a rotation around an axis through the real origin).
            R = XR * YI; % %#ok<MINV>
            
            % Sine of half the rotation angle.
            %       SinHalf = sqrt(3 - trace(R)) / 2;
            %   For very small angles, this formula is not accurate compared to
            %   w, since diagonal elements are around 1, and eps(1) = 2.2e-16.
            %   This will be the order of magnitude of non-diag. elements due to
            %   errors. So we should get SinHalf from w.
            % Rotation axis with amplitude = SinHalf (like in rotation quaternions).
            w = [R(3, 2) - R(2, 3); R(1, 3) - R(3, 1); R(2, 1) - R(1, 2)] / ...
                (2 * sqrt(1 + R(1, 1) + R(2, 2) + R(3, 3)));
            SinHalf = sqrt(sum(w.^2));
            TNormSq = sum(T.^2);
            % Maximum sphere distance for translation + rotation, as described
            % above.
            D(s, t) = sqrt( TNormSq + (2 * r * SinHalf)^2 + ...
                4 * r * sqrt(TNormSq * SinHalf^2 - (T' * w)^2) );
            % CHECK should be comparable AND >= to max coil movement.
            
            % Option to interrupt when past a distance threshold.
            if StopThreshold && D(s, t) > StopThreshold
                return;
            end
        end
    end
    
end % RigidDistances



function [O, R] = RigidCoordinates(FidsColumns)
    % Convert head coil locations to origin position and rotation matrix.
    % Works with 9x1 or 3x3 (columns) input.
    
    R = zeros(3);
    O = zeros(3, 1);
    O(:) = (FidsColumns(4:6) + FidsColumns(7:9))/2;
    R(1:6) = FidsColumns(1:6); % F(1:6) is row if F is matrix, column if F is column!
    R(1:3) = R(1:3) - O';
    R(4:6) = R(4:6) - O';
    %R(:, 3) = cross(R(:, 1), R(:, 2));
    R(:, 3) = [R(2, 1)*R(3, 2) - R(3, 1)*R(2, 2), -R(1, 1)*R(3, 2) + R(3, 1)*R(1, 2), R(1, 1)*R(2, 2) - R(2, 1)*R(1, 2)];
    %R(:, 2) = cross(R(:, 3), R(:, 1));
    R(:, 2) = [R(2, 3)*R(3, 1) - R(3, 3)*R(2, 1), -R(1, 3)*R(3, 1) + R(3, 3)*R(1, 1), R(1, 3)*R(2, 1) - R(2, 3)*R(1, 1)];
    % Normalize x, y, z.
    R = bsxfun(@rdivide, R, sqrt(sum(R.^2, 1)));
end % RigidCoordinates



function Distance = HeadMotionDistance(Locations, ChannelFile)
    % Compute continuous head distance from initial/reference position.
    %
    % Locations contains the HLU coordinates in meters, [9, nSamples].
    % Takes into account any adjustment to the reference position that is
    % saved as a transformation.
        
    ChannelMat = in_bst_channel(ChannelFile);
    % Get the initial/reference head position, to which we compare the
    % instantaneous ones.
    InitLoc = process_adjust_coordinates('ReferenceHeadLocation', ChannelMat);
    if isempty(InitLoc)
        bst_error('Unable to compute reference head position.');
    end
    
    nSamples = size(Locations, 2);
    if size(Locations, 1) < 9
        bst_error('Unexpected number of head coil position channels.');
    end
    
    % Downsample head localization channels to their real sampling rate.
    % This makes the following computation much faster.
    % HeadSamplePeriod is in (MEG) samples per (head) sample, not seconds.
    HeadSamplePeriod = nSamples; % Initialized to at least 1 point per epoch.
    % To find real localization sampling rate, look for changes in data, but
    % it seems it's common to get repeated values (code must have some
    % condition where it just keeps the same value), so we need to verify
    % carefully.  First, find times of changes.  This already ignores the
    % first few samples until the first change.
    TrueSamples = find(any(diff(Locations, 1, 2), 1)) + 1;
    % Then get the time intervals between these changes, and find the
    % smallest "step" between these intervals.  E.g. if we got intervals of
    % 80, 120, 240 samples, the smallest difference between these would be
    % 40, which is the sampling period we were looking for.
    if numel(TrueSamples) > 1 % to avoid empty which propagates in min.
        HeadSamplePeriod = min(HeadSamplePeriod, min(diff(TrueSamples(1:end-1))));
    end
    % Downsample.
    Locations = Locations(:, 1:HeadSamplePeriod:nSamples);
    %   nS = ceil(nS / HeadSamplePeriod);
    
    % Compute distance
    DistDowns = RigidDistances(Locations, InitLoc)';
    
    if numel(DistDowns) == 1
        % Special case where movement was removed, either manually or with SSS.
        Distance = DistDowns * ones(1, nSamples);
    else
        % Upsample back to MEG sampling rate.
        Distance = interp1(DistDowns, (1:nSamples)/HeadSamplePeriod);
        % Replace initial NaNs with first value.
        Distance(isnan(Distance)) = Distance(find(~isnan(Distance), 1));
    end
    
end


