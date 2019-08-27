function Timefreq = in_bst_timefreq(TimefreqFile, LoadFull, varargin)
% IN_TIMEFREQ_BST: Read a sources file in Brainstorm format.
% 
% USAGE:  Timefreq = in_bst_timefreq(TimefreqFile, LoadFull=1, FieldsList=All)  
% 
% INPUT:
%    - TimefreqFile : Absolute or relative path to the file to read
%    - LoadFull     : If 1, and if file is a "Kernel only" file, load the data, compute Kernel*Data to get the full sources time series
%    - FieldsList   : List of fields to read from the file
% OUTPUT:
%    - Timefreq     : Brainstorm timefreq file structure

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2010-2019

%% ===== PARSE INPUTS =====
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Filename: Relative / absolute
if ~file_exist(TimefreqFile)
    TimefreqFile = bst_fullfile(ProtocolInfo.STUDIES, TimefreqFile);
    if ~file_exist(TimefreqFile)
        error('Timefreq file not found.');
    end
end
% Load full?
if (nargin < 2) || isempty(LoadFull)
    LoadFull = 1;
end
isKernel = ~isempty(strfind(TimefreqFile, '_KERNEL_'));
% Specific fields
if (nargin < 3)
    % Read all fields
    Timefreq = load(TimefreqFile);
    % Get all the fields
    FieldsToRead = fieldnames(Timefreq);
    FieldsToRead{end+1} = 'ZScore';
else
    % Get fields to read
    FieldsToRead = varargin;
    % Add some conditional fields
    if ismember('TF', FieldsToRead)
        FieldsToRead{end+1} = 'Measure';
        FieldsToRead{end+1} = 'ZScore';
        if LoadFull && isKernel
            FieldsToRead{end+1} = 'DataFile';
        end   
    end
    % When reading Leff, make sure nAvg is read as well
    if ismember('Leff', FieldsToRead) && ~ismember('nAvg', FieldsToRead)
        FieldsToRead{end+1} = 'nAvg';
    end
    % Read each field only once
    FieldsToRead = unique(FieldsToRead);
    % Read specified files only
    warning off MATLAB:load:variableNotFound
    Timefreq = load(TimefreqFile, FieldsToRead{:});
    warning on MATLAB:load:variableNotFound
end


%% ===== FILL OTHER MISSING FIELDS =====
for i = 1:length(FieldsToRead)
    if ~isfield(Timefreq, FieldsToRead{i})
        switch(FieldsToRead{i}) 
            case 'Measure'
                Timefreq.(FieldsToRead{i}) = 'none';
            case 'nAvg'
                Timefreq.(FieldsToRead{i}) = 1;
            case 'Leff'
                if isfield(Timefreq, 'nAvg') && ~isempty(Timefreq.nAvg)
                    Timefreq.Leff = Timefreq.nAvg;
                else
                    Timefreq.Leff = 1;
                end
            case 'Method'
                if ~isempty(strfind(TimefreqFile, '_psd'))
                    Timefreq.(FieldsToRead{i}) = 'psd';
                elseif ~isempty(strfind(TimefreqFile, '_fft'))
                    Timefreq.(FieldsToRead{i}) = 'fft';
                elseif ~isempty(strfind(TimefreqFile, '_hilbert'))
                    Timefreq.(FieldsToRead{i}) = 'hilbert';
                elseif ~isempty(strfind(TimefreqFile, '_mtmconvol'))
                    Timefreq.(FieldsToRead{i}) = 'mtmconvol';
                else
                    Timefreq.(FieldsToRead{i}) = 'morlet';
                end
            otherwise
                Timefreq.(FieldsToRead{i}) = [];
        end
    end
end

%% ===== FILL EMPTY FIELDS =====
if isfield(Timefreq, 'Measure') && isempty(Timefreq.Measure)
    Timefreq.Measure = 'none';
elseif isfield(Timefreq, 'Measure')
    Timefreq.Measure = lower(Timefreq.Measure);
end


%% ===== FIX OLD TIME/FREQUENCY BANDS =====
% Old structure:  {name, fstart, fend}
% New structure:  {name, 'expression', 'stat')
if isfield(Timefreq, 'Freqs') && iscell(Timefreq.Freqs) && ~isempty(Timefreq.Freqs) && ~ischar(Timefreq.Freqs{1,2})
    for iBand = 1:size(Timefreq.Freqs,1)
        Timefreq.Freqs{iBand, 2} = [num2str(Timefreq.Freqs{iBand, 2}), ', ', num2str(Timefreq.Freqs{iBand, 3})];
        Timefreq.Freqs{iBand, 3} = 'mean';
    end
end
if isfield(Timefreq, 'TimeBands') && ~isempty(Timefreq.TimeBands) && ~ischar(Timefreq.TimeBands{1,2})
    for iBand = 1:size(Timefreq.TimeBands,1)
        Timefreq.TimeBands{iBand, 2} = [num2str(Timefreq.TimeBands{iBand, 2}), ', ', num2str(Timefreq.TimeBands{iBand, 3})];
        Timefreq.TimeBands{iBand, 3} = 'mean';
    end
end

%% ===== REBUILD FULL SOURCES =====
if ismember('TF', FieldsToRead) && LoadFull && isKernel && ismember(file_gettype(Timefreq.DataFile), {'link', 'results'})
    % Get imaging kernel
    ResultsMat = in_bst_results(Timefreq.DataFile, 0, 'ImagingKernel');
    % Initialize full matrix
    TFfull = zeros(size(ResultsMat.ImagingKernel,1), size(Timefreq.TF,2), size(Timefreq.TF,3));
    % Multiply the TF values
    for i = 1:size(Timefreq.TF,3)
        TFfull(:,:,i) = ResultsMat.ImagingKernel * Timefreq.TF(:,:,i);
    end
    Timefreq.TF = TFfull;
end

%% ===== APPLY DYNAMIC ZSCORE =====
% DEPRECATED
% Check for structure integrity
if ismember('ZScore', FieldsToRead) && ~isempty(Timefreq.ZScore) && (~isfield(Timefreq.ZScore, 'mean') || ~isfield(Timefreq.ZScore, 'std') || ~isfield(Timefreq.ZScore, 'abs') || ~isfield(Timefreq.ZScore, 'baseline') || isempty(Timefreq.ZScore.abs))
    Timefreq.ZScore = [];
end
% Apply to file values
if ismember('ZScore', FieldsToRead) && ismember('TF', FieldsToRead) && ~isempty(Timefreq.ZScore) && ~isempty(Timefreq.TF)
    % Error in the case of source-based sources
    if isKernel && ~LoadFull
        error('Unsupported operation.');
    end
    Timefreq.TF = process_zscore_dynamic('Compute', Timefreq.TF, Timefreq.ZScore);
    Timefreq = rmfield(Timefreq, 'ZScore');
end

% ===== FIX TRANSPOSED TIME VECTOR =====
if isfield(Timefreq, 'Time') && (size(Timefreq.Time,1) > 1)
    Timefreq.Time = Timefreq.Time';
end



