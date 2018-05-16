function varargout = process_sin_remove( varargin )
% PROCESS_SIN_REMOVE: Remove one or more sinusoids from a signal.
%
% USAGE:      sProcess = process_sin_remove('GetDescription')
%               sInput = process_sin_remove('Run', sProcess, sInput, method=[default])
%                    x = process_sin_remove('Compute', x, sfreq, FreqList, method=[default])

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
% Authors: Francois Tadel, 2011-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Sinusoid removal';
    sProcess.FileTag     = 'sin';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 67;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsFilter#What_filters_to_apply.3F';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.processDim  = 1;   % Process channel by channel
    
    % Definition of the options
    % === Warning
    sProcess.options.warning.Comment = ['<U>Warning</U>: This method has shown to have stability issues.<BR><BR>' ...
                                        'Please consider using the following filters instead:<BR>' ...
                                        '- <B>Notch filter</B>: well identified 50/60Hz peaks (+harmonics)<BR>' ...
                                        '- <B>Band-stop filter</B>: larger frequency bands.<BR><BR>'];
    sProcess.options.warning.Type    = 'label';
    % === Freq list
    sProcess.options.freqlist.Comment = 'Frequencies to remove:';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'list', 2};
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % === Reverse
    sProcess.options.reverse.Comment = 'Apply the filter in both directions';
    sProcess.options.reverse.Type    = 'checkbox';
    sProcess.options.reverse.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    if isempty(sProcess.options.freqlist.Value{1})
        Comment = 'Sinusoid removal: No frequency selected';
    else
        strValue = sprintf('%1.0fHz ', sProcess.options.freqlist.Value{1});
        Comment = ['Sinusoid removal: ' strValue(1:end-1)];
    end
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    FreqList = sProcess.options.freqlist.Value{1};
    if isempty(FreqList) || isequal(FreqList, 0)
        bst_report('Error', sProcess, [], 'No frequency in input.');
        sInput = [];
        return;
    end
    isReverse = sProcess.options.reverse.Value;
    % Test length of the signal
    sfreq = 1 ./ (sInput.TimeVector(2)-sInput.TimeVector(1));
    if (size(sInput.A,2) < round(sfreq))
        bst_report('Warning', sProcess, [], 'Signal is too short for performing a proper filtering. Minimum duration = 1s');
    end
    % Filter data
    sInput.A = Compute(sInput.A, sfreq, FreqList, [], isReverse);
    % Comment
    strValue = sprintf('%1.0fHz ', FreqList);
    sInput.CommentTag = ['sin(' strValue(1:end-1) ')'];
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== EXTERNAL CALL =====
% USAGE: x = process_sin_remove('Compute', x, sfreq, FreqList, Method=[default], isReverse=0)
function x = Compute(x, sfreq, FreqList, method, isReverse)
    % Default method
    if (nargin < 5) || isempty(isReverse)
        isReverse = 0;
    end
    if (nargin < 4) || isempty(method)
        if bst_get('UseSigProcToolbox')
            if isReverse
                method = 'moshermosher_extrap';
            else
                method = 'mosher_extrap';
            end
        else
            if isReverse
                method = 'moshermosher_sym';
            else
                method = 'mosher_sym';
            end
        end
    end
    % Check list of freq to remove
    if isempty(FreqList) || isequal(FreqList, 0)
        return;
    end
    % Filtering using the selected method
    switch (method)
        case 'sin_removal_new'
            x = bst_sin_remove_new(x, sfreq, FreqList);
            
        case 'mosher'
            x = bst_sin_remove(x, sfreq, FreqList);
            
        case 'moshermosher'
            % Filter in both directions
            x = bst_sin_remove(x, sfreq, FreqList);
            x(:,end:-1:1) = bst_sin_remove(x(:,end:-1:1), sfreq, FreqList);

        case 'mosher_extrap'
            [nChannel, nTime] = size(x);
            % Number of samples to extrapolate at the beginning of the signal
            nSym = min(round(sfreq) + 1, nTime);
            
            % Extrapolate signal (Requires the signal processing toolbox)
            nOrder = 20;
            x_extrap = zeros(nChannel, nSym);
            for i = 1:nChannel
                % Auto-regressive model coefficients
                a = arburg(x(i, nSym:-1:1), nOrder);
                % Run the initial timeseries through the filter to get the filter state
                [tmp, zf] = filter(-[0 a(2:end)], 1, x(i,nSym:-1:1));
                % Now use the filter as an IIR to extrapolate
                if any(isnan(zf))
                    x_extrap(i,:) = x(i,nSym+1:-1:2);
                else
                    x_extrap(i,end:-1:1) = filter([0 0], -a, zeros(1,nSym), zf);
                end
            end

            % Mosher filter
            x = bst_sin_remove([x_extrap, x], sfreq, FreqList);
            % Remove the interpolated part
            x = x(:, nSym+1:end);
            
        case 'moshermosher_extrap'
            [nChannel, nTime] = size(x);
            % Number of samples to extrapolate at the beginning of the signal
            nSym = min(round(sfreq) + 1, nTime-2);
            
            % Extrapolate signal
            nOrder = 20;
            x_extrap1 = zeros(nChannel, nSym);
            x_extrap2 = zeros(nChannel, nSym);
            for i = 1:nChannel
                % Auto-regressive model coefficients
                a = arburg(x(i,nSym:-1:1), nOrder);
                % Run the initial timeseries through the filter to get the filter state
                [tmp, zf] = filter(-[0 a(2:end)], 1, x(i,nSym:-1:1));
                % Now use the filter as an IIR to extrapolate
                if any(isnan(zf))
                    x_extrap1(i,:) = x(i,nSym+1:-1:2);
                else
                    x_extrap1(i,end:-1:1) = filter([0 0], -a, zeros(1,nSym), zf);
                end
                
                % Auto-regressive model coefficients
                a = arburg(x(i,end-nSym+1:end), nOrder);
                % Run the initial timeseries through the filter to get the filter state
                [tmp, zf] = filter(-[0 a(2:end)], 1, x(i,end-nSym+1:end));
                % Now use the filter as an IIR to extrapolate
                if any(isnan(zf))
                    x_extrap2(i,:) = x(i,end-nSym:end-1);
                else
                    x_extrap2(i,:) = filter([0 0], -a, zeros(1,nSym), zf);
                end
            end

            % Filter in both directions
            x = bst_sin_remove([x_extrap1, x, x_extrap2], sfreq, FreqList);
            x(:,end:-1:1) = bst_sin_remove(x(:,end:-1:1), sfreq, FreqList);
            % Remove the interpolated part
            x = x(:, nSym+1:end-nSym);
            
        case 'mosher_sym'
            % Number of samples to mirror on each side of the signal
            Nsym = min(round(sfreq) + 1, size(x,2));
            % Create a symmetrical padding on both ends
            x = [x(:,Nsym:-1:1), x, x(:,end:-1:end-Nsym+1)];
            % Mosher filter
            x = bst_sin_remove(x, sfreq, FreqList);
            % Remove padding
            x = x(:, Nsym+1:end-Nsym);
            
        case 'moshermosher_sym'
            % Number of samples to mirror on each side of the signal
            Nsym = min(round(sfreq) + 1, size(x,2));
            % Create a symmetrical padding on both ends
            x = [x(:,Nsym:-1:1), x, x(:,end:-1:end-Nsym+1)];
            % Filter in both directions
            x = bst_sin_remove(x, sfreq, FreqList);
            x(:,end:-1:1) = bst_sin_remove(x(:,end:-1:1), sfreq, FreqList);
            % Remove padding
            x = x(:, Nsym+1:end-Nsym);
           
    end
end


