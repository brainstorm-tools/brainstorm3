function varargout = process_tf_measure( varargin )
% PROCESS_TF_MEASURE: Change timefreq file measure.
%
% USAGE:                      Values = process_tf_measure('Compute', Values, srcMeasure, destMeasure)
%        [DefFunction, ColormapType] = process_tf_measure('GetDefaultFunction', sTimefreq)

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
% Authors: Francois Tadel, 2012-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Measure from complex values';
    sProcess.FileTag     = 'meas';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 375;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TimeFrequency?highlight=%28Measure%29#Description_of_the_fields';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === Sensor types
    sProcess.options.measure.Comment = {'Power', 'Magnitude', 'Log(power)', 'Phase'};
    sProcess.options.measure.Type    = 'radio';
    sProcess.options.measure.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = [sProcess.Comment ': ' sProcess.options.measure.Comment{sProcess.options.measure.Value}];
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get destination measure
    switch (sProcess.options.measure.Value)
        case 1,  destMeasure = 'power';
        case 2,  destMeasure = 'magnitude';
        case 3,  destMeasure = 'log';
        case 4,  destMeasure = 'phase';   
    end
    % Nothing to do
    if strcmpi(sInput.Measure, destMeasure)
        bst_report('Warning', sProcess, sInput, ['Input file is already in destination measure "' destMeasure '".']);
        return
    end
    % Change measure
    [sInput.A, isError] = Compute(sInput.A, sInput.Measure, destMeasure);
    % Display error message
    if isError
        bst_report('Error', sProcess, sInput, ['Invalid measure conversion: ' sInput.Measure ' => ' destMeasure]);
        sInput = [];
        return;
    else
        sInput.Measure = destMeasure;
    end
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== COMPUTE =====
function [Values, isError] = Compute(Values, srcMeasure, destMeasure, isKeepNan)
    if nargin < 4 || isempty(isKeepNan)
        isKeepNan = false;
    end
    isError = 0;
    if strcmpi(srcMeasure, destMeasure)
        return;
    elseif strcmpi(srcMeasure, 'other') || strcmpi(destMeasure, 'other')
        isError = 1;
        return;
    end
    switch lower(srcMeasure)
        case 'none'
            switch lower(destMeasure)
                case 'power',      Values = abs(Values) .^ 2;
                case 'magnitude',  Values = abs(Values);
                case 'log',        Values = 10 .* log10(abs(Values) .^ 2);
                case 'phase',      Values = angle(Values);
                case 'none',       % Nothing to do
                otherwise,         isError = 1;
            end
        case 'power'
            switch lower(destMeasure)
                case 'power',      % Nothing to do
                case 'magnitude',  Values = sqrt(abs(Values)) .* sign(Values);
                case 'log',        Values = 10 .* log10(abs(Values)) .* sign(Values);
                otherwise,         isError = 1;
            end
        case 'magnitude'
            switch lower(destMeasure)
                case 'power',      Values = Values.^2 .* sign(Values);
                case 'magnitude',  % Nothing to do
                case 'log',        Values = 10 .* log10(Values .^ 2) .* sign(Values);
                otherwise,         isError = 1;
            end
        case 'log'
            switch lower(destMeasure)
                case 'power',      Values = 10 .^ (Values / 10);
                case 'magnitude',  Values = sqrt(10 .^ (Values / 10));
                case 'log',        % Nothing to do
                otherwise,         isError = 1;
            end
        case 'phase'
            switch lower(destMeasure)
                case 'phase',      % Nothing to do
                otherwise,         isError = 1;
            end
    end
    if ~isKeepNan
        Values(isnan(Values)) = 0;
    end
end


%% ===== GET DEFAULT MEASURE =====
% USAGE:   [DefFunction, ColormapType] = process_tf_measure('GetDefaultFunction', sTimefreq)
function [DefFunction, ColormapType] = GetDefaultFunction(sTimefreq) %#ok<DEFNU>
    switch lower(sTimefreq.Method)
        case 'morlet',   DefFunction = 'power';       ColormapType = 'timefreq';
        case 'fft',      DefFunction = 'power';       ColormapType = 'timefreq';
        case 'psd',      DefFunction = 'power';       ColormapType = 'timefreq';
        case 'hilbert',  DefFunction = 'power';       ColormapType = 'timefreq';
        case 'mtmconvol',DefFunction = 'power';       ColormapType = 'timefreq';
        case 'instfreq', DefFunction = 'other';       ColormapType = 'timefreq';
        case 'canolty',  DefFunction = 'other';       ColormapType = 'timefreq';  
        case 'corr',     DefFunction = 'other';       ColormapType = 'connect1';
        case 'cohere',   DefFunction = 'other';       ColormapType = 'connect1';
        case 'granger',  DefFunction = 'other';       ColormapType = 'connect1';
        case 'spgranger',DefFunction = 'other';       ColormapType = 'connect1';
        case 'henv',     DefFunction = 'other';       ColormapType = 'connect1';
        case 'plv',      DefFunction = 'magnitude';   ColormapType = 'connect1';
        case 'plvt',     DefFunction = 'magnitude';   ColormapType = 'connect1';
        case 'ciplv',    DefFunction = 'magnitude';   ColormapType = 'connect1';
        case 'ciplvt',   DefFunction = 'magnitude';   ColormapType = 'connect1';
        case 'wpli',     DefFunction = 'magnitude';   ColormapType = 'connect1';
        case 'wplit',    DefFunction = 'magnitude';   ColormapType = 'connect1';
        case 'pac',      DefFunction = 'maxpac';      ColormapType = 'pac';
        case 'dpac',     DefFunction = 'maxpac';      ColormapType = 'pac';
        case 'tpac',     DefFunction = 'maxpac';      ColormapType = 'pac';
        case 'ttest',    DefFunction = 'other';       ColormapType = 'stat2'; 
        otherwise,       DefFunction = 'power';       ColormapType = 'timefreq';
    end
    % Overwrite the defaults if there is an unknown function currently applied
    if strcmpi(sTimefreq.Measure, 'other')
        DefFunction = 'other';
    % If the phase is already computed: Cannot go back to the power
    elseif strcmpi(sTimefreq.Measure, 'phase')
        DefFunction = 'phase';
    end
    % Override colormap type with what was saved in the file
    if isfield(sTimefreq, 'ColormapType') && ~isempty(sTimefreq.ColormapType)
        ColormapType = sTimefreq.ColormapType;
    end
end


