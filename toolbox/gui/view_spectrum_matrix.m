function [hFig, iDS, iFig] = view_spectrum_matrix(BaseFiles, DisplayMode, TF, RowNames, Time, Freqs, Modality, DisplayUnits)
% VIEW_SPECTRUM_MATRIX: Display spectrum matrix in a new figure.
%
% USAGE:  [hFig, iDS, iFig] = view_spectrum_matrix(BaseFiles, DisplayMode, TF, RowNames, Time, Freqs, Modality=[], DisplayUnits=[])
%
% INPUT:
%   - BaseFiles   : Files that figure will be associated with
%   - DisplayMode : {'Spectrum', 'TimeSeries'}
%   - TF          : Time-frequency matrix to display [nRows x nTime x nFreqs]
%   - RowNames    : Names of the signals in matrix TF (dimension #1)
%   - Time        : Time vector that matches the dimension #2 of matrix TF
%   - Freqs       : Frequency vector that matches the dimension #3 of matrix TF
%   - Modality    : {'MEG', 'MEG MAG', 'MEG GRAD', 'EEG', 'NIRS', 'Other', 'Source', ...}
%   - DisplayUnits: String, units used to represent the signals in the figures ('mV', 'pA.m', 't', ...)
%
% OUTPUT: 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2023


%% ===== PARSE INPUTS =====
global GlobalData;
% Parse inputs
if (nargin < 8) || isempty(DisplayUnits)
    DisplayUnits = [];
end
if (nargin < 7) || isempty(Modality)
    Modality = '';
end
% Initialize returned values
iDS = [];
iFig = [];
% BaseFiles: cell list or char
if iscell(BaseFiles)
    BaseFile = BaseFiles{1};
elseif ischar(BaseFiles)
    BaseFile = BaseFiles;
    BaseFiles = {BaseFiles};
end
% Get study
[sStudy, iStudy, iItem, DataType, sTimefreq] = bst_get('AnyFile', BaseFile);
if isempty(sStudy)
    error('File is not registered in database.');
end


%% ===== CREATE A NEW LOADED DATASET =====
% Load file to get a base dataset index
[iDS, iTimefreqBase] = bst_memory('LoadTimefreqFile', BaseFile);
if isempty(iDS)
    return
end
% Create a new entry with the input data
iTimefreq = length(GlobalData.DataSet(iDS).Timefreq) + 1;
GlobalData.DataSet(iDS).Timefreq(iTimefreq) = GlobalData.DataSet(iDS).Timefreq(iTimefreqBase);
TfFile = sprintf('%s$%d', BaseFile, iTimefreq);
GlobalData.DataSet(iDS).Timefreq(iTimefreq).FileName     = TfFile;
GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF           = TF;
GlobalData.DataSet(iDS).Timefreq(iTimefreq).TfFile       = [];
GlobalData.DataSet(iDS).Timefreq(iTimefreq).Time         = Time;
GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs        = Freqs;
GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames     = RowNames;
GlobalData.DataSet(iDS).Timefreq(iTimefreq).DisplayUnits = DisplayUnits;
GlobalData.DataSet(iDS).Timefreq(iTimefreq).Modality     = Modality;

% Display the new dataset with regular function
[hFig, iDS, iFig] = view_spectrum(TfFile, DisplayMode, [], 1);
