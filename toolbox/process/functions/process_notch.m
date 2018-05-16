function varargout = process_notch( varargin )
% PROCESS_NOTCH: Remove one or more sinusoids from a signal
%
% USAGE:      sProcess = process_notch('GetDescription')
%               sInput = process_notch('Run',     sProcess, sInput)
%                    x = process_notch('Compute', x, sfreq, FreqList)

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
% Authors: Francois Tadel, 2014-2015
% 
% Code inspired from MatlabCentral post:
% http://www.mathworks.com/matlabcentral/newsreader/view_thread/292960

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Notch filter';
    sProcess.FileTag     = 'notch';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 66;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsFilter#Filter_specifications:_Notch';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.processDim  = 1;   % Process channel by channel
    
    % Definition of the options
    % === Freq list
    sProcess.options.freqlist.Comment = 'Frequencies to remove (Hz):';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'list', 2};
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    if isempty(sProcess.options.freqlist.Value{1})
        Comment = 'Notch filter: No frequency selected';
    else
        strValue = sprintf('%1.0fHz ', sProcess.options.freqlist.Value{1});
        Comment = ['Notch filter: ' strValue(1:end-1)];
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
    % Get sampling frequency
    sfreq = 1 ./ (sInput.TimeVector(2)-sInput.TimeVector(1));
%     % Test length of the signal
%     if (size(sInput.A,2) < round(sfreq))
%         bst_report('Warning', sProcess, [], 'Signal is too short for performing a proper filtering. Minimum duration = 1s');
%     end
    % Filter data
    sInput.A = Compute(sInput.A, sfreq, FreqList);
    % Comment
    strValue = sprintf('%1.0fHz ', FreqList);
    sInput.CommentTag = [sProcess.FileTag '(' strValue(1:end-1) ')'];
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== EXTERNAL CALL =====
% USAGE: x = process_notch('Compute', x, sfreq, FreqList)
function x = Compute(x, sfreq, FreqList)
    % Use the signal processing toolbox?
    UseSigProcToolbox = bst_get('UseSigProcToolbox');
    % Check list of freq to remove
    if isempty(FreqList) || isequal(FreqList, 0)
        return;
    end
    % Define a default width
    FreqWidth = 1;
    % Remove the mean of the data before filtering
    xmean = mean(x,2);
    x = bst_bsxfun(@minus, x, xmean);
    % Remove all the frequencies sequencially
    for ifreq = 1:length(FreqList)
        % Define coefficients of an IIR notch filter
        delta = FreqWidth/2;
        % Pole radius
        r = 1 - (delta * pi / sfreq);     
        theta = 2 * pi * FreqList(ifreq) / sfreq;
        % Gain factor
        B0 = abs(1 - 2*r*cos(theta) + r^2) / (2*abs(1-cos(theta)));   
        % Numerator coefficients
        B = B0 * [1, -2*cos(theta), 1];  
        % Denominator coefficients
        A = [1, -2*r*cos(theta), r^2];    
        % Filter signal
        if UseSigProcToolbox
            x = filtfilt(B,A,x')'; 
        else
            x = filter(B,A,x')'; 
            x(:,end:-1:1) = filter(B,A,x(:,end:-1:1)')'; 
        end
    end
    % Restore the mean of the signal
    x = bst_bsxfun(@plus, x, xmean);
end


