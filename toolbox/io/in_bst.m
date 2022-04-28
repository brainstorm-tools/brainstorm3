function [sMatrix, matName] = in_bst(FileName, TimeBounds, isLoadFull, isIgnoreBad, RemoveBaseline, UseSsp)
% IN_BST: Read a data matrix in a Brainstorm file of any type.
%
% USAGE: [sMatrix, matName] = in_bst(FileName, TimeBounds, isLoadFull=1, isIgnoreBad=0, RemoveBaseline='all', UseSsp=1)  : read only the specified time indices
%        [sMatrix, matName] = in_bst(FileName)         : Read the entire file
%                TimeVector = in_bst(FileName, 'Time') : Read time vector in the file
%
% INPUT:
%    - FileName   : Full path to file to read. Possible input file types are: 
%                    - recordings file (.F field),
%                    - results file (.ImageGridAmp field),
%                    - results file in kernel-only format (.ImagingKernel field)
%    - TimeBounds : [Start,Stop] values of the time segment to read (in seconds)
%    - isLoadFull : If 0, read the kernel-based results separately as Kernel+Recordings
%    - isIgnoreBad: If 1, do not return the bad segments in the file
%    - RemoveBaseline: {'all','no'}, only usefull when reading RAW files
%
% OUTPUT:
%    - sMatrix     : Full content of the file
%    - matName     : name of the field that was read: {'F', 'ImageGridAmp', 'TF'}
%    - TimeVector  : time values of all samples that were read in the file

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
% Authors: Francois Tadel, 2008-2016

%% ===== PARSE INPUTS =====
% Parse inputs
if (nargin < 6) || isempty(UseSsp)
    UseSsp = 1;
end
if (nargin < 5) || isempty(RemoveBaseline)
    RemoveBaseline = 'all';
end
if (nargin < 4) || isempty(isIgnoreBad)
    isIgnoreBad = 0;
end
if (nargin < 3) || isempty(isLoadFull)
    isLoadFull = 1;
end
if (nargin < 2) || isempty(TimeBounds)
    TimeBounds = [];
end
% Get file type
fileType = file_gettype( FileName );


%% ===== READ ONLY TIME =====
if ischar(TimeBounds) && strcmpi(TimeBounds, 'Time')
    % Load time range from this file
    switch (fileType)
        case {'data', 'raw', 'pdata'}
            FileMat = in_bst_data(FileName, 'Time');
        case {'results', 'link', 'presults'}
            FileMat = in_bst_results(FileName, isLoadFull, 'Time');
        case {'timefreq', 'ptimefreq'}
            FileMat = in_bst_timefreq(FileName, 0, 'Time');
        case {'matrix', 'pmatrix'}
            FileMat = in_bst_matrix(FileName, 'Time');
    end
    sMatrix = FileMat.Time;
    return;
end


%% ===== READ ALL FILE =====
switch(fileType)
    %% ===== RESULTS =====
    case {'results', 'link'}
        % Read results file
        dataFields = fieldnames(db_template('resultsmat'));
        sMatrix = in_bst_results(FileName, 0, 'ImageGridAmp', dataFields{:});
        % FULL RESULTS
        if isfield(sMatrix, 'ImageGridAmp') && ~isempty(sMatrix.ImageGridAmp)
            iTime = GetTimeIndices(TimeBounds, sMatrix.Time);
            sMatrix.ImageGridAmp  = sMatrix.ImageGridAmp(:,iTime);
            sMatrix.Time          = sMatrix.Time(iTime);
            sMatrix.ImagingKernel = [];
            matName = 'ImageGridAmp';
        % KERNEL ONLY
        elseif isfield(sMatrix, 'ImagingKernel') && ~isempty(sMatrix.ImagingKernel)
            % Cannot read the data file
            if isempty(sMatrix.DataFile)
                matName = 'ImagingKernel';
                disp('BST> Error: Cannot read data file associated with source file.');
                return;
            end
            % Get good channels
            iGoodChannels = sMatrix.GoodChannel;
            % For DataFile in relative
            sMatrix.DataFile = file_short(sMatrix.DataFile);
            % Load the recordings file
            if ~isempty(sMatrix.ZScore)
                DataMat = in_bst(sMatrix.DataFile, [], 1, isIgnoreBad, RemoveBaseline);
            else
                DataMat = in_bst(sMatrix.DataFile, TimeBounds, 1, isIgnoreBad, RemoveBaseline);
            end
            sMatrix.nAvg = DataMat.nAvg;
            sMatrix.Leff = DataMat.Leff;
            % Rebuild full results
            if isLoadFull
                sMatrix.ImageGridAmp = sMatrix.ImagingKernel * DataMat.F(iGoodChannels, :);
            else
                sMatrix.F = DataMat.F(iGoodChannels, :);
            end
            sMatrix.Time = DataMat.Time;
            
            % Apply dynamic zscore
            if ~isempty(sMatrix.ZScore)
                if isLoadFull
                    [sMatrix.ImageGridAmp, sMatrix.ZScore] = process_zscore_dynamic('Compute', sMatrix.ImageGridAmp, sMatrix.ZScore, DataMat.Time, sMatrix.ImagingKernel, DataMat.F(iGoodChannels,:));
                    sMatrix = rmfield(sMatrix, 'ZScore');
                else
                    [tmp, sMatrix.ZScore] = process_zscore_dynamic('Compute', [], sMatrix.ZScore, DataMat.Time, sMatrix.ImagingKernel, DataMat.F(iGoodChannels,:));
                end
                % Select requested time window
                if ~isempty(TimeBounds)
                    iTime = GetTimeIndices(TimeBounds, sMatrix.Time);
                    sMatrix.Time = sMatrix.Time(iTime);
                    if isLoadFull
                        sMatrix.ImageGridAmp = sMatrix.ImageGridAmp(:,iTime);
                    else
                        sMatrix.F = sMatrix.F(:,iTime);
                    end
                end
            end
            % Remove "Kernel" indications in the Comment field
            if isLoadFull
                sMatrix.Comment = strrep(sMatrix.Comment, '(Kernel)', '');
                sMatrix.Comment = strrep(sMatrix.Comment, 'Kernel', '');
                sMatrix.ImagingKernel = [];
                matName = 'ImageGridAmp';
            else
                matName = 'ImagingKernel';
            end
        end
    
    %% ===== DATA =====
    case 'data'
        % Read recordings file
        dataFields = fieldnames(db_template('datamat'));
        sMatrix = in_bst_data( FileName, dataFields{:});
        % Get time indices we want to read
        iTime = GetTimeIndices(TimeBounds, sMatrix.Time);
        % No time
        if isempty(iTime)
            sMatrix.F = [];
            sMatrix.Time = [];
        else
            % Fix input time bounds
            TimeBounds = sMatrix.Time([iTime(1), iTime(end)]);
            % Read RAW recordings: read first epoch only
            if isstruct(sMatrix.F)
                if isLoadFull
                    % Read channel file
                    ChannelFile = bst_get('ChannelFileForStudy', FileName);
                    ChannelMat = in_bst_channel(ChannelFile);
                    % Read from the raw file
                    sFile = sMatrix.F;
                    [sMatrix.F, sMatrix.Time] = panel_record('ReadRawBlock', sFile, ChannelMat, 1, TimeBounds, 0, 1, RemoveBaseline, UseSsp);
                    % Reject bad segments
                    if isIgnoreBad
                        % Get list of bad segments in file
                        [badSeg, badEpoch, badTimes] = panel_record('GetBadSegments', sFile);
                        % Remove all the bad time indices
                        if ~isempty(badTimes)
                            iBad = [];
                            for iSeg = 1:size(badTimes, 2)
                                iBad = [iBad, find((sMatrix.Time >= badTimes(1,iSeg)) & (sMatrix.Time <= badTimes(2,iSeg)))];
                            end
                            % Remove bad segments from read block
                            sMatrix.F(:,iBad) = [];
                            sMatrix.Time(iBad) = [];
                        end
                    end
                elseif ~isempty(TimeBounds)
                    sMatrix.Time = sMatrix.Time(iTime);
                end
            % Normal imported file
            elseif ~isempty(TimeBounds)
                sMatrix.F = sMatrix.F(:,iTime);
                sMatrix.Time = sMatrix.Time(iTime);
            end
        end
        matName = 'F';
    
    %% ===== TIME-FREQ =====
    case 'timefreq'
        dataFields = fieldnames(db_template('timefreqmat'));
        sMatrix = in_bst_timefreq( FileName, 0, dataFields{:});
        isKernel = ~isempty(strfind(FileName, '_KERNEL_'));
        % Keep required values
        if ~isempty(TimeBounds) && (size(sMatrix.TF,2) > 1)
            if isfield(sMatrix, 'TimeBands') && ~isempty(sMatrix.TimeBands)
                % Select the bands that have their center in the selectd time window
                TimeBandsCenter = mean(process_tf_bands('GetBounds', sMatrix.TimeBands), 2)';
                iTime = find((TimeBandsCenter >= TimeBounds(1)) & (TimeBandsCenter <= TimeBounds(2)));
                % Remove time bands from the output: use the center of the bands as the time
                sMatrix.TimeBands = [];
                sMatrix.Time = TimeBandsCenter(iTime);
            else
                iTime = GetTimeIndices(TimeBounds, sMatrix.Time);
                sMatrix.Time = sMatrix.Time(iTime);
            end
            % Select the requested times
            sMatrix.TF = sMatrix.TF(:,iTime,:);
            % Report selection on "TFmask"
            if ~isempty(sMatrix.TFmask)
                sMatrix.TFmask = sMatrix.TFmask(:,iTime,:);
            end
        end
        % Rebuild full source matrix
        if isLoadFull && isKernel && ismember(file_gettype(sMatrix.DataFile), {'link', 'results'})
            % Get imaging kernel
            ResultsMat = in_bst_results(sMatrix.DataFile, 0, 'ImagingKernel');
            % Initialize full matrix
            TFfull = zeros(size(ResultsMat.ImagingKernel,1), size(sMatrix.TF,2), size(sMatrix.TF,3));
            % Multiply the TF values
            for i = 1:size(sMatrix.TF,3)
                TFfull(:,:,i) = ResultsMat.ImagingKernel * sMatrix.TF(:,:,i);
            end
            sMatrix.TF = TFfull;
        end
        matName = 'TF';
        
        
    %% ===== MATRIX =====
    case 'matrix'
        dataFields = fieldnames(db_template('matrixmat'));
        sMatrix = in_bst_matrix( FileName, dataFields{:});
        % Keep required values
        if isfield(sMatrix, 'Time') && ~isempty(sMatrix.Time) && ~isempty(TimeBounds)
            iTime = GetTimeIndices(TimeBounds, sMatrix.Time);
            sMatrix.Value = sMatrix.Value(:,iTime);
            sMatrix.Time  = sMatrix.Time(iTime);
        end
        matName = 'Value';
        
    %% ===== STAT =====
    case {'pdata', 'presults', 'ptimefreq', 'pmatrix'}
        dataFields = fieldnames(db_template('statmat'));
        sMatrix = in_bst_matrix( FileName, dataFields{:});
        % Keep required values
        if isfield(sMatrix, 'Time') && ~isempty(sMatrix.Time) && ~isempty(TimeBounds)
            iTime = GetTimeIndices(TimeBounds, sMatrix.Time);
            sMatrix.Time  = sMatrix.Time(iTime);
            if isfield(sMatrix, 'tmap') && ~isempty(sMatrix.tmap)
                sMatrix.tmap = sMatrix.tmap(:,iTime);
            end
            if isfield(sMatrix, 'pmap') && ~isempty(sMatrix.pmap)
                sMatrix.pmap = sMatrix.pmap(:,iTime);
            end
        end
        matName = 'tmap';
        
    %% ===== NOISE COV =====
    case {'noisecov', 'ndatacov'}
        sMatrix = load(file_fullpath(FileName));
        matName = 'NoiseCov';
        
    %% ===== HEAD MODEL =====
    case 'headmodel'
        sMatrix = in_bst_headmodel(FileName);
        matName = 'Gain';
end
end


%% ===== HELPER FUNCTIONS =====
function iTime = GetTimeIndices(TimeBounds, TimeVector)
    % Get file time indices
    if (length(TimeVector) == 1)
        iTime = 1;
    elseif isempty(TimeBounds)
        iTime = 1:length(TimeVector);
    elseif (TimeBounds(1) > TimeVector(end)) || (TimeBounds(2) < TimeVector(1))
        iTime = [];
    else
        iTimeBounds = bst_closest(TimeBounds, TimeVector);
        iTime = iTimeBounds(1):iTimeBounds(2);       
    end
end

