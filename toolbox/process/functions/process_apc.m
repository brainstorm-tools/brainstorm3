function varargout = process_apc(varargin)
% PROCESS_APC: Compute the Amplitude-Phase coupling for time series

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
% Authors: Niloofar Gharesi, 2025
%          Raymundo Cassani, 2025

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    sProcess.Comment     = 'APC (Custom)';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 656;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    
    % Input / output
    sProcess.InputTypes  = {'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % === Options for your code ===
    sProcess.options.label1.Comment = '<B>APC Parameters</B>';
    sProcess.options.label1.Type    = 'label';

    % Frequency range
    sProcess.options.fA.Comment = 'Frequency range (Hz)';
    sProcess.options.fA.Type    = 'timewindow';
    sProcess.options.fA.Value   = {[16, 250], 'Hz', []};

    % Epoch
    sProcess.options.epoch.Comment = 'Epoch time limits around peaks (s)';
    sProcess.options.epoch.Type    = 'timewindow';
    sProcess.options.epoch.Value   = {[-0.6, 0.6], 's', []};

    % Decomposition method
    sProcess.options.decomposition.Comment = 'Decomposition method';
    sProcess.options.decomposition.Type    = 'text';
    sProcess.options.decomposition.Value   = 'vmd_sym';

    % Show plots
    sProcess.options.diagm.Comment = 'Show plots';
    sProcess.options.diagm.Type    = 'checkbox';
    sProcess.options.diagm.Value   = 1;

    % Sampling rate
    sProcess.options.srate.Comment = 'Sampling rate (Hz)';
    sProcess.options.srate.Type    = 'value';
    sProcess.options.srate.Value   = {1000, 'Hz', []};

    % Data type
    sProcess.options.idataType.Comment = 'Type of input data';
    sProcess.options.idataType.Type    = 'text';
    sProcess.options.idataType.Value   = 'LFP';

    % Data length
    sProcess.options.dataLength.Comment = 'Length of data used for analysis (s)';
    sProcess.options.dataLength.Type    = 'timewindow';
    sProcess.options.dataLength.Value   = {[-1.5, 2], 's', []};

    % Surrogates
    sProcess.options.surrogates.Comment = 'Use surrogates';
    sProcess.options.surrogates.Type    = 'checkbox';
    sProcess.options.surrogates.Value   = 0;

    % Number of permutations
    sProcess.options.num_perm.Comment = 'Number of permutations';
    sProcess.options.num_perm.Type    = 'value';
    sProcess.options.num_perm.Value   = {1, '', []};

    % Phase bins
    sProcess.options.varargin.Comment = 'Number of phase bins';
    sProcess.options.varargin.Type    = 'value';
    sProcess.options.varargin.Value   = {18, '', []};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    OutputFiles = {};

    % Collect options
    OPTIONS.fA           = sProcess.options.fA.Value{1};
    OPTIONS.epoch        = sProcess.options.epoch.Value{1};
    OPTIONS.decomposition= sProcess.options.decomposition.Value;
    OPTIONS.diagm        = sProcess.options.diagm.Value;
    OPTIONS.srate        = sProcess.options.srate.Value{1};
    OPTIONS.idataType    = sProcess.options.idataType.Value;
    OPTIONS.dataLength   = sProcess.options.dataLength.Value{1};
    OPTIONS.surrogates   = sProcess.options.surrogates.Value;
    OPTIONS.num_perm     = sProcess.options.num_perm.Value{1};
    OPTIONS.numPhaseBins = sProcess.options.varargin.Value{1};

    % Load timeseries
    [sMatIn, matName] = in_bst(sInput.FileName);
    sMatApc.data = sMatIn.(matName);
    sMatApc.time = sMatIn.Time;

    % Compute APC features
    [pacStr, phaseFreq, ampFreq, prefPhase] = bst_apc(sMatApc, OPTIONS);
    %%% Four lines below are for quick testing
    %pacStr = sMatApc.data(:,1);
    %phaseFreq = sMatApc.data(:,1);
    %ampFreq = sMatApc.data(:,1);
    %prefPhase = sMatApc.data(:,1);

    % Save APC results
    apcFeatures = {pacStr, phaseFreq, ampFreq, prefPhase};
    apcLabels   = {'pacStr','phaseFreq','ampFreq','prefPhase'};
    apcUnits    = {'??', 'Hz', 'Hz', '??'};
    apcTime     = [0,1]; % One sample

    for iFeature = 1 : length(apcFeatures)
        % Create output structure based on type
        switch sInput.FileType
            case 'results'
                sMatOut = db_template('resultsmat');
                sMatOut.ImageGridAmp  = apcFeatures{iFeature};
                sMatOut.SurfaceFile   = sMatIn.SurfaceFile;
                sMatOut.HeadModelFile = sMatIn.HeadModelFile;

            case 'data'
                sMatOut = db_template('datamat');
                sMatOut.F           = apcFeatures{iFeature};
                sMatOut.ChannelFlag = sMatIn.ChannelFlag;
                sMatOut.DataType    = '';  % Clear to avoid having a source link

            case 'matrix'
                sMatOut = db_template('matrixmat');
                sMatOut.Value = X;
        end
        % Common elements
        sMatOut.Time         = apcTime;
        sMatOut.Comment      = [sMatIn.Comment, ' | ', apcLabels{iFeature}];
        sMatOut.DisplayUnits = apcUnits{iFeature};
        % Add history
        sMatOut = bst_history('add', sMatOut, 'process', ...
            sprintf('process_apc: APC %s, file: %s', apcLabels{iFeature}, sInput.FileName));
        % Create filename
        [originalPath, originalBase, originalExt] = bst_fileparts(file_fullpath(sInput.FileName));
        OutputFile = bst_fullfile(originalPath, [originalBase, '_apc_', apcLabels{iFeature}, originalExt]);
        OutputFile = file_unique(OutputFile);
        % Save and add to database
        bst_save(OutputFile, sMatOut);
        db_add_data(sInput.iStudy, OutputFile, sMatOut);
        OutputFiles{end+1} = OutputFile;
    end
end
