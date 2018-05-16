function [ftData, sInput, VertConn] = out_fieldtrip_results( ResultsFile, ScoutSel, ScoutFunc, TimeWindow, isNorm)
% OUT_FIELDTRIP_RESULTS Converts a source file into a FieldTrip structure (ft_datatype_source.m).
% 
% USAGE:  [ftData, sInput, VertConn] = out_fieldtrip_results( ResultsFile, ScoutSel=[], ScoutFunc=[mean], TimeWindow=[], isNorm=0);
%
% INPUTS:
%    - ResultsFile : Relative path to a source file available in the database
%    - ScoutSel    : List of scouts to extract
%    - ScoutFunc   : Function to apply on the scouts recordings
%    - TimeWindow  : Time segment to import from the input files
%    - isNorm      : If 0, return the source values as they are stored in the file
%                    If 1, return the absolute values (constrained) or the norm of the three orientations (unconstrained)

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
% Authors: Arnaud Gloaguen, Francois Tadel, 2015

% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(ScoutSel)
    ScoutSel = []; 
end
if (nargin < 3) || isempty(ScoutFunc)
    ScoutFunc = 'mean';
end
if (nargin < 4) || isempty(TimeWindow)
    TimeWindow = [];
end
if (nargin < 5) || isempty(isNorm)
    isNorm = 0;
end
ftData = [];
VertConn = [];
isComputeVertConn = (nargout >= 3);

% ===== LOAD INPUTS =====
% Options for LoadInputFile()
LoadOptions.LoadFull    = 1;    % Load full source results
LoadOptions.IgnoreBad   = 1;    % Do not read bad segments
LoadOptions.ProcessName = [];
LoadOptions.TargetFunc  = ScoutFunc;
LoadOptions.isNorm      = isNorm;
% Load reference signal
sInput = bst_process('LoadInputFile', ResultsFile, ScoutSel, TimeWindow, LoadOptions);
if isempty(sInput.Data)
    return;
end
% If this is not a source file
if isempty(sInput.SurfaceFile) || strcmpi(sInput.DataType, 'scout')
    error('The input files do not contain full cortex maps, use function "ft_freqstatistics" instead.');
end

% Enforce absolute value
if isNorm
    sInput.Data = abs(sInput.Data);
end
% If using scouts: no positions, no connectivity
nSignals = size(sInput.Data, 1);
if ~isempty(ScoutSel)
    VertConn = [];
    GridLoc  = zeros(nSignals, 3);
else
    [VertConn, GridLoc] = results_vertconn(ResultsFile, isComputeVertConn);
end

% ===== CREATE FIELDTRIP STRUCTURE =====
% Convert to FieldTrip source data structure: see ft_datatype_source.m
ftData = struct();
ftData.inside = true(nSignals, 1);
ftData.pow    = sInput.Data;
ftData.pos    = GridLoc;
% Time
if (size(ftData.pow,2) == 1)
    ftData.time = sInput.Time(1);
else
    ftData.time = sInput.Time;
end
% Fields dependent on the frequency format
switch (file_gettype(ResultsFile))
    case {'results', 'link'}
        ftData.dimord = 'pos_time';
    case 'timefreq'
        ftData.dimord = 'pos_freq_time';
        % Frequency bands: Take the middle of the band
        if iscell(sInput.Freqs)
            BandBounds = process_tf_bands('GetBounds', sInput.Freqs);
            ftData.freq = mean(BandBounds,2);
        % Frequency bins
        else
            ftData.freq = sInput.Freqs;
        end
        ftData.pow = permute(ftData.pow, [1 3 2]);
end

