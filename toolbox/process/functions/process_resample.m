function varargout = process_resample( varargin )
% PROCESS_RESAMPLE: Resample matrix with a new sampling frequency.
%
% USAGE:      sProcess = process_resample('GetDescription')
%               sInput = process_resample('Run', sProcess, sInput, method)
%               sInput = process_resample('Run', sProcess, sInput)
%        [x, time_out] = process_resample('Compute', x, time_in, NewRate, method)
%        [x, time_out] = process_resample('Compute', x, time_in, NewRate)
%        [x,Pfac,Qfac] = process_resample('ResampleCascade', x, NewRate, OldRate, Method)

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
% Authors: Francois Tadel, 2010-2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Resample';
    sProcess.FileTag     = 'resample';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 69;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'matrix', 'timefreq'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'matrix', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.processDim  = 1;    % Process channel by channel
    sProcess.isSeparator = 1;
    
    % Definition of the options
    % === Resample frequency
    sProcess.options.freq.Comment = 'New frequency:  ';
    sProcess.options.freq.Type    = 'value';
    sProcess.options.freq.Value   = {1000,'Hz',4};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sprintf('Resample: %dHz', round(sProcess.options.freq.Value{1}));
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput, method) %#ok<DEFNU>
    % Get method name
    if (nargin < 3)
        method = [];
    end
    % Output frequency
    NewFreq = sProcess.options.freq.Value{1};
    % Check output frequency
    OldFreq = 1 ./ (sInput.TimeVector(2) - sInput.TimeVector(1));
    if (abs(NewFreq - OldFreq) < 0.05)
        bst_report('Error', sProcess, [], 'Sampling frequency was not changed.');
        sInput = [];
        return;
    end
    % Check for Signal Processing toolbox
    if ~bst_get('UseSigProcToolbox')
        bst_report('Warning', sProcess, [], [...
            'The Signal Processing Toolbox is not available. Using the EEGLAB method instead (results may be much less accurate).' 10 ...
            'This method is based on a fft-based low-pass filter, followed by a spline interpolation.' 10 ...
            'Make sure you remove the DC offset before resampling; EEGLAB function does not work well when the signals are not centered.']);
    end
    % Resample
    [sInput.A, sInput.TimeVector] = Compute(sInput.A, sInput.TimeVector, NewFreq, method);
    % Update file
    sInput.CommentTag = sprintf('resample(%dHz)', round(NewFreq));
    sInput.HistoryComment = sprintf('Resample from %0.2f Hz to %0.2f Hz (%s)', OldFreq, NewFreq, method);
    % Do not keep the Std and TFmask fields in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
    if isfield(sInput, 'TFmask') && ~isempty(sInput.TFmask)
        sInput.TFmask = [];
    end
end


%% ===== EXTERNAL CALL =====
% USAGE: [TF, time_out] = process_resample('Compute', TF, time_in, NewFreq)
% INPUT:
%     - TF      : Signal to process [nChannels x nTime x nFreq]
%     - Time    : Original time vector
%     - NewFreq : New sampling frequency (Hz)
% OUTPUT:
%     - TF   : Resampled signal
%     - Time : New time vector
function [TFout, Time] = Compute(TF, Time, NewFreq, method)
    % Default method
    if (nargin < 4) || isempty(method)
        if bst_get('UseSigProcToolbox')
            method = 'resample-cascade';
        else
            method = 'fft-spline';
        end
    end
    % Check output frequency
    OldFreq = 1 ./ (Time(2) - Time(1));
    if (abs(NewFreq - OldFreq) < 0.05)
        TFout = [];
        return;
    end
    % Round old frequency at x100
    OldFreq = round(OldFreq * 100) / 100;
    
    
    % ===== RESAMPLE DATA =====
    % Process each frequency band separately
    for iFreq = 1:size(TF,3)
        % Select only one frequency bin
        x = TF(:,:,iFreq);
        % Filtering using the selected method
        switch (method)
            % Bad
            case 'fft-spline'
                % Anti-alias filter
                if (NewFreq < OldFreq)
                    % x = process_bandpass('Compute', x, 256, [], 128 * NewFreq / OldFreq, 'bst-fft-fir', 1);
                    x = process_bandpass('Compute', x, 256, [], 128 * NewFreq / OldFreq);  % Replaced by FT, 16-Jan-2016
                end
                % Spline interpolation
                nbnewpoints  = size(x,2) * NewFreq / OldFreq;
                nbnewpoints2 = ceil(nbnewpoints);
                lastpointval = size(x,2) / nbnewpoints * nbnewpoints2;       
                XX = linspace( 1, lastpointval, nbnewpoints2);
                cs = spline( 1:size(x,2), x);
                x = ppval(cs, XX);
            % SigProc Toolbox: Good but can be slow
            case 'resample'
                % Resample: Signal processing toolbox 'resample' 
                x = resample(x', NewFreq, OldFreq)';
            % SigProc Toolbox: Good but output frequency can be different from what is required
            case 'resample-rational'
                % Resample parameters
                [P,Q] = rat(NewFreq / OldFreq, .0001);
                % Resample
                x = resample(x', P, Q)';
                % Compute output sampling frequency
                NewFreq = P / Q * OldFreq;
            % SigProc Toolbox: Good and fast
            case 'resample-cascade'
                % Resample: Signal processing toolbox 'resample' (cascade)
                x = ResampleCascade(x, NewFreq, OldFreq, 'resample');
            % SigProc Toolbox: Not so good, not so fast
            case 'interp-decimate-cascade'
                % Resample: Signal processing toolbox 'interp' + 'decimate' (cascade)
                x = ResampleCascade(x, NewFreq, OldFreq, 'decimate');
        end
        % Initialize output matrix
        if (iFreq == 1) && (size(TF,3) > 1)
            TFout = zeros(size(x,1), size(x,2), size(TF,3));
        end
        % Report results in output matrix
        TFout(:,:,iFreq) = x;
    end
    % Compute new Time vector
    % Time = linspace(Time(1), Time(end), size(x,2));
    Time = Time(1) + (0:(size(TFout,2)-1)) ./ NewFreq;
end


%% ========================================================================================
%  ====== RESAMPLING FUNCTIONS ============================================================
%  ========================================================================================

%% ====== RESAMPLE-CASCADE =====
% USAGE: [x,Pfac,Qfac] = process_resample('ResampleCascade', x, NewRate, OldRate, Method)
% INPUT:
%     - x       : Signal to process [nChannels x nTime]
%     - NewRate : New sampling frequency (Hz)
%     - OldRate : Original sampling frequency (Hz)
%     - Method  : 'resample' or 'decimate'
% OUTPUT:
%     - x    : Resampled signal
%     - Pfac : Array of successive upsampling factors
%     - Qfac : List of successive downsampling factors
% NOTE: Requires Signal Processing Toolbox
% AUTHOR: John Mosher, 2010
function [x,Pfac,Qfac] = ResampleCascade(x,NewRate,OldRate,Method)
    % Default method: 'resample'
    if (nargin < 4)
        Method = 'resample';
    end
    % Common factors
    [P,Q] = rat(NewRate/OldRate);
    % We want to upsample by P and downsample by Q to achieve the new rate
    % But big numbers cause problems.
    Pfac = factor(P);
    Qfac = factor(Q);
    % Longest number of factors
    iFacs = max(length(Pfac),length(Qfac));
    % Pad the shorter one to have unity factors
    Pfac((length(Pfac)+1):iFacs) = 1;
    Qfac((length(Qfac)+1):iFacs) = 1;

    % So now we have two factorization lists of the same length, and
    % prod(Pfac) / prod(Qfac) = P/Q.
    Pfac = sort(Pfac,'descend'); % upsample largest first
    Qfac = sort(Qfac,'ascend'); % downsample smallest rates first
    Rates = Pfac./Qfac;  % rates per step
    CRate = cumprod(Rates); % cumulative resampling rates

    % We can't go below min(1,P/Q) without losing information. Because of low-pass filtering, don't be too precise
    Problem = CRate < (0.9 * P/Q);
    if any(Problem)
        fprintf(1, 'RESAMPLE> Warning: Desired rate is %.f\n', P/Q);
    end
    if any(Pfac > 10)
        disp(['RESAMPLE> Warning: Upsampling by more than 10 in the cascades, P = ' sprintf('%d ', Pfac)]);
    end
    if any(Qfac > 10)
        disp(['RESAMPLE> Warning: Downsampling by more than 10 in the cascades, Q = ' sprintf('%d ', Qfac)]);
    end

    % ===== RESAMPLING =====
    switch Method
        % Decimate/interp inputs cannot be vectorized
        case 'decimate'
            % Initialize output parameters
            len_resmp = ceil(size(x,2) * prod(Pfac) / prod(Qfac));
            nRow = size(x,1);
            x_resmp = zeros(nRow, len_resmp);
            % Loop on factors and rows
            for iRow = 1:size(x,1)
                x_tmp = x(iRow,:);
                for i = 1:iFacs
                    x_tmp = decimate(interp(x_tmp, Pfac(i)), Qfac(i));
                end
                x_resmp(iRow,:) = x_tmp;
            end
            x = x_resmp;
        % Resample takes vectorized inputs
        case 'resample'
            for i = 1:iFacs
                x = resample(x', Pfac(i), Qfac(i))';
            end
    end
end






