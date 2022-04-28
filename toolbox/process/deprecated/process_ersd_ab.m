function varargout = process_ersd_ab( varargin )
% PROCESS_ERSD_AB: Compute event related perturbation (synchrnonization / desynchrnonization)
%
% DESCRIPTION: 
%    This function calculates event related perturbation (ERS/ERD) as the percentage of a 
%    decrease or increase during a test interval (T), as compared to a reference interval (R). 
%    The following formula is used: ERSP = (R-T)/R x 100.

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
% Authors: Nikola Vukovic, University of Cambridge, 2013
%          Francois Tadel, 2013-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Event related perturbation (ERS/ERD) [DEPRECATED]';
    sProcess.FileTag     = 'ersd';
    sProcess.Category    = 'Filter2';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 205;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TimeFrequency#Normalized_time-frequency_maps';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 1;
    sProcess.processDim       = 1;    % Process channel by channel
    sProcess.isPaired         = 1;
    
    % Definition of the options
    sProcess.options.description.Comment = ['For each signal in input:<BR>' ...
                                            '1) <B>FilesA</B>: Compute the mean <I>m</I> for the baseline<BR>' ...
                                            '2) <B>FilesB</B>: For each time sample, calculates a percentage of increase/decrease<BR>' ...
                                            'ERSD = (Data-<I>m</I>)/<I>m</I> x 100<BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline (Files A):';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get baseline
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        Time = sProcess.options.baseline.Value{1};
    else
        Time = [];
    end
    % Format comment
    if isempty(Time)
        Comment = 'Event related perturbation: [All file]';
    elseif any(abs(Time) > 2)
        Comment = sprintf('Event related perturbation: [%1.3fs,%1.3fs]', Time(1), Time(2));
    else
        Comment = sprintf('Event related perturbation: [%dms,%dms]', round(Time(1)*1000), round(Time(2)*1000));
    end
end


%% ===== RUN =====
function sInputB = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Get options
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        BaselineBounds = sProcess.options.baseline.Value{1};
    else
        BaselineBounds = [];
    end
    % Get baseline indices
    if ~isempty(BaselineBounds)
        iBaseline = bst_closest(BaselineBounds, sInputA.TimeVector);
        if (iBaseline(1) == iBaseline(2)) && any(iBaseline(1) == sInputA.TimeVector)
            error('Invalid baseline definition.');
        end
        iBaseline = iBaseline(1):iBaseline(2);
    % Get all file
    else
        iBaseline = 1:size(sInputA.A,2);
    end
    % Compute ERS/ERD
    sInputB.A = Compute(sInputA.A(:,iBaseline,:), sInputB.A);
    % Change DataType
    if ~strcmpi(sInputB.FileType, 'timefreq')
        sInputB.DataType = 'zscore';
    end
    % Default colormap
    if strcmpi(sInputB.FileType, 'results')
        sInputB.ColormapType = 'stat1';
    else
        sInputB.ColormapType = 'stat2';
    end
    % Add new tag to comment
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        sInputB.Comment = [sInputB.Comment, ' | abs'];
    end
end


%% ===== COMPUTE =====
function B_data = Compute(A_baseline, B_data)
    disp('BST> process_ersd_ab.m is deprecated, use "Standardize > Baseline normalization" instead.');
    % Compute baseline statistics
    meanBaseline = mean(A_baseline, 2);
    % Remove null variance values
    meanBaseline(meanBaseline == 0) = 1e-12;
    % Compute event related perturbation
    B_data = bst_bsxfun(@minus, B_data, meanBaseline);
    B_data = bst_bsxfun(@rdivide, B_data, meanBaseline) .* 100;
end


