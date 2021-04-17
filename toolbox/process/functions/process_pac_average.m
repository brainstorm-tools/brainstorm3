function varargout = process_pac_average( varargin )
% PROCESS_PAC_AVERAGE: average pac maps.
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Soheila Samiee, 2015-2017
%   - 2.0: SS. Aug. 2017 
%                - Imported in public brainstorm rep
%   - 2.1: SS Sep. 2017
%                - Bug fix for averaging multiple files with different 
%                number of sources
%
%   - 2.2: SS Sep 2017
%                - Bug fix - donot store f_nesting information 
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Average PAC maps';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Frequency','Time-resolved Phase-Amplitude Coupling'};
    sProcess.Index       = 1018;
    
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    
    % === ANALYZE TO BE DONE
    sProcess.options.label.Comment = '<U><B>Analyze:</B></U>';
    sProcess.options.label.Type    = 'label';
    sProcess.options.analyze_type.Comment = { ...
        'Everything','By Subject'};
    sProcess.options.analyze_type.Type    = 'radio';
    sProcess.options.analyze_type.Value   = 1;

    % === Using phase
    sProcess.options.usePhase.Comment = 'Use phase in averaging';
    sProcess.options.usePhase.Type    = 'checkbox';
    sProcess.options.usePhase.Value   = 0;

end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>

    usePhase = sProcess.options.usePhase.Value;

    % Get current progressbar position
    if bst_progress('isVisible')
        curProgress = bst_progress('get');
    else
        curProgress = [];
    end

    % Load TF file
    tpacMat = in_bst_timefreq(sInput(1).FileName, 0);
    % Error
    if isempty(tpacMat)
        bst_report('Error', sProcess, sInput, Messages);
        return;
    end
    
    switch(sProcess.options.analyze_type.Value)
        % === EVERYTHING ===
        case 1
            [tpacMat, tag, FileTag] = AverageFilesPAC(sInput, tpacMat,usePhase);
            N = length(sInput);
            tpacMat.nAvg = N;
            isAvgFile = 1;
            
            % Save the results
            OutputFiles = save_pac_files(sProcess, sInput, FileTag, tag, tpacMat, isAvgFile);
            
            % === BY SUBJECT ===
        case 2
            % Process each subject independently
            uniqueSubj = unique({sInput.SubjectFile});
            for i = 1:length(uniqueSubj)
                % Set progress bar at the same level for each loop
                if ~isempty(curProgress)
                    bst_progress('set', curProgress);
                end
                % Get all the files for subject #i
                iInputSubj = find(strcmpi(uniqueSubj{i}, {sInput.SubjectFile}));
                N = length(sInput(iInputSubj));
                if N>1
                    % Load TF file
                    tpacMat = in_bst_timefreq(sInput(iInputSubj(1)).FileName, 0);
                    % Process the average of subject #i
                    [tpacMat, tag, FileTag] = AverageFilesPAC(sInput(iInputSubj(2:end)), tpacMat, usePhase);
                    isAvgFile = 1;
                else
                    % Process the average of subject #i
                    [tpacMat, tag, FileTag] = AverageFilesPAC(sInput(iInputSubj(1)), tpacMat, usePhase);
                    isAvgFile = 0;
                end
                tpacMat.nAvg = N;
                tpacMat.Options.usePhase = usePhase;
                
                % Save the results
                OutputFiles = save_pac_files(sProcess, sInput(iInputSubj), FileTag, tag, tpacMat, isAvgFile);
            end
    end
end



function [tpacMat, tag, FileTag] = AverageFilesPAC(sInput, tpacMat, usePhase)
        tag = '|avg_file';
        N = length(sInput);
        spac = tpacMat.sPAC;
        
        if isfield(spac,'DirectPAC')
            pac = tpacMat.sPAC.DirectPAC/N;
            for iFile = 2:N
                tmp = in_bst_timefreq(sInput(iFile).FileName, 0);
                pac = pac + tmp.sPAC.DirectPAC/N;
            end
            tpacMat.sPAC.DirectPAC = pac;
            FileTag = 'timefreq_pac_fullmaps';
            %% Recompute nesting frequencies
            pacDims = size(pac);
            if length(pacDims) < 4
                % Ensure we have 4 dimensions
                pacDims = [ones(1,4-length(pacDims)), pacDims];
                pac = reshape(pac,pacDims);
            end
            [nSources, nWindows, nLow, nHigh] = size(pac);
            for iSource = 1:nSources
                for iWindow = 1:nWindows
                    curPac = pac(iSource,iWindow,:,:);
                    [tmp, maxInd] = max(curPac(:));
                    [indFa, indFp] = ind2sub([nLow, nHigh], maxInd);
                    tpacMat.sPAC.NestingFreq(iSource,iWindow) = tpacMat.sPAC.LowFreqs(indFp);
                    tpacMat.sPAC.NestedFreq(iSource,iWindow) = tpacMat.sPAC.HighFreqs(indFa);
                end
            end
            
        elseif isfield(spac,'DynamicPAC')    
            if usePhase
                tpac = tpacMat.sPAC.DynamicPAC.*exp(1i*tpacMat.sPAC.DynamicPhase)/N;
            else
                tpac = tpacMat.sPAC.DynamicPAC/N;
            end
%             Nesting = tpacMat.sPAC.DynamicNesting;
            for iFile = 2:N
                tmp = in_bst_timefreq(sInput(iFile).FileName, 0);
                if ~isequal(tmp.Time,tpacMat.Time) || ~isequal(tmp.sPAC.HighFreqs, tpacMat.sPAC.HighFreqs)
                    Message = ['Format of file#',num2str(iFile),' does not match the first file'];
                    bst_report('Error', 'process_pac_average', sInput, Message);
                    return;
                end 
                if ~isequal(size(tpac,1), size(tmp.sPAC.DynamicPAC,1))
                    Message = ['Number of sources in File #',num2str(iFile),' is not the same as previous files -- average on sources before averaging files'];
                    bst_report('Error', 'process_pac_average', sInput, Message);
                    return;
                end 
                if usePhase && isequal(size(tpac,1), size(tmp.sPAC.DynamicPhase,1))
                    tpac = tpac + tmp.sPAC.DynamicPAC.*exp(1i*tmp.sPAC.DynamicPhase)/N;
                elseif ~isequal(size(tpac,1), size(tmp.sPAC.DynamicPAC,1))                    
                    Message = ['Number of sources for phase in File #',num2str(iFile),' is not the same as previous files -- You cannot use phase in averaging'];
                    bst_report('Error', 'process_pac_average', sInput, Message);
                    return;
                else
                    tpac = tpac + tmp.sPAC.DynamicPAC/N;
                end
%                 Nesting = cat(5,Nesting,tmp.sPAC.DynamicNesting);
            end
            tpacMat.sPAC.DynamicPAC = abs(tpac);
            if usePhase
                tpacMat.sPAC.PhasePAC = angle(tpac);
                tpacMat.sPAC.DynamicPhase = angle(tpac);
            end
            tpacMat.sPAC.DynamicNesting = [];%Nesting;
            FileTag = 'timefreq_dpac_fullmaps';
        end                
end



function OutputFiles = save_pac_files(sProcess, sInput, FileTag, tag, tpacMat, isAvgFile)
    % === SAVING THE DATA IN BRAINSTORM ===
    % Getting the study
    [sOutputStudy, iOutputStudy, comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInput);

    % Comment
    tpacMat.Comment = [tpacMat.Comment, ' ', tag];

    % Preparing the output file
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), FileTag); 
    OutputFiles{1} = file_unique(OutputFiles{1});

    if isAvgFile
        % Averaging results from the different data file: reset the "DataFile" field
        if isfield(tpacMat, 'DataFile') && ~isempty(tpacMat.DataFile) && (length(uniqueDataFile) ~= 1)
            tpacMat.DataFile = [];
        end

    end

    % Save on disk
    bst_save(OutputFiles{1}, tpacMat, 'v6');
    % Register in database
    db_add_data(iOutputStudy, OutputFiles{1}, tpacMat);

end