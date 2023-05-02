function varargout = process_pac_average( varargin )
% PROCESS_PAC_AVERAGE: average pac maps.
%
% Averages all "full" PAC value arrays across files and/or trials.  Then the max PAC fields (TF,
% NestingFreq, NestedFreq, PhasePAC) are recomputed from the averages.  However, DyncamicPAC may
% already be the max across several nesting frequencies and this average should be interpreted with
% caution.
%
% For time-resolved (dynamic) PAC, trials could have been concatenated in 4th dim of the DynamicPAC
% field; these are also averaged here.  If using the phase in averaging, the returned DynamicPhase
% is the phase of the averaged (complex) PAC, otherwise it is empty.  Similarly for TF & PhasePAC
% which are the max values over all frequencies for amplitude.  DynamicNesting (frequency for phase)
% values are also removed since they are different between files.
%
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
% Authors: Soheila Samiee, 2015-2017
%          Marc Lalancette, 2023
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

    %     % Get current progressbar position
    %     if bst_progress('isVisible')
    %         curProgress = bst_progress('get');
    %     else
    %         curProgress = [];
    %     end

    switch(sProcess.options.analyze_type.Value)
        % === EVERYTHING ===
        case 1
            [tpacMat, FileTag] = AverageFilesPAC(sInput, usePhase);
            if isempty(tpacMat) % Error already reported.
                OutputFiles = {};
                return;
            end
            % Save the results
            OutputFiles = save_pac_files(sProcess, sInput, FileTag, tpacMat);
            
            % === BY SUBJECT ===
        case 2
            % Process each subject independently
            [~, iSubj, iUniq] = unique({sInput.SubjectFile});
            nSubj = length(iSubj);
            OutputFiles = cell(nSubj,1);
            for i = 1:nSubj
                % Get all the files for subject #i
                isInputSubj = (i == iUniq);
                [tpacMat, FileTag] = AverageFilesPAC(sInput(isInputSubj), usePhase);
                if isempty(tpacMat) % Error already reported.
                    OutputFiles = {};
                    return;
                end
                % Save the results
                OutputFiles(i) = save_pac_files(sProcess, sInput(isInputSubj), FileTag, tpacMat);
            end
    end
end



function [tpacMat, FileTag] = AverageFilesPAC(sInput, usePhase)
        N = length(sInput);
        % Load TF file
        tpacMat = in_bst_timefreq(sInput(1).FileName, 0);
        if isempty(tpacMat)
            bst_report('Error', sProcess, sInput, 'Error loading input file.');
            return;
        end
        tpacMat.Options.usePhase = usePhase;
        
        if isfield(tpacMat.sPAC, 'DirectPAC')
            % size is [nSignals, nTime=1, nLowFreqs, nHighFreqs]
            % Keep first file's data to avoid loading again.
            tpacIn = tpacMat;
            % Reinitialize output array.
            tpacMat.sPAC.DirectPAC = zeros(size(tpacMat.sPAC.DirectPAC, 1:3));
            tpacMat.nAvg = 0;
            for iFile = 1:N
                if iFile > 1
                    tpacIn = in_bst_timefreq(sInput(iFile).FileName, 0);
                    if ~isequal(tpacMat.sPAC.LowFreqs, tpacIn.sPAC.LowFreqs) || ~isequal(tpacMat.sPAC.HighFreqs, tpacIn.sPAC.HighFreqs)
                        Message = ['Frequencies of file #',num2str(iFile),' is not the same as previous files.'];
                        bst_report('Error', 'process_pac_average', sInput, Message);
                        tpacMat = [];
                        return;
                    elseif ~isequal(size(tpacMat.sPAC.DirectPAC), size(tpacIn.sPAC.DirectPAC))
                        Message = ['Size of PAC array of file #',num2str(iFile),' is not the same as previous files.'];
                        bst_report('Error', 'process_pac_average', sInput, Message);
                        tpacMat = [];
                        return;
                    end
                end
                % Check full maps were saved.
                if isempty(tpacIn.sPAC.DirectPAC)
                    Message = ['Full PAC array is missing for file #',num2str(iFile),'.'];
                    bst_report('Error', 'process_pac_average', sInput, Message);
                    tpacMat = [];
                    return;
                end
                tpacMat.sPAC.DirectPAC = tpacMat.sPAC.DirectPAC + tpacIn.sPAC.DirectPAC;
                if isempty(tpacIn.nAvg)
                    tpacIn.nAvg = 1;
                end
                tpacMat.nAvg = tpacMat.nAvg + tpacIn.nAvg;
            end
            FileTag = 'timefreq_pac_fullmaps';
            % Divide by total number of trials for average.
            tpacMat.sPAC.DirectPAC = tpacMat.sPAC.DirectPAC / tpacMat.nAvg;

            % Recompute max over all fA and fP pairs, saved in TF, and save corresponding frequencies (NestingFreq and NestedFreq).
            % Ensure we have 4 dimensions
            pacDims = size(tpacMat.sPAC.DirectPAC);
            if length(pacDims) < 4
                pacDims = [ones(1,4-length(pacDims)), pacDims];
                tpacMat.sPAC.DirectPAC = reshape(tpacMat.sPAC.DirectPAC, pacDims);
            end
            [nSources, nWindows, nLow, nHigh] = size(tpacMat.sPAC.DirectPAC);
            [tpacMat.sPAC.TF, iLinMax] = max(tpacMat.sPAC.DirectPAC(:, :, :), 3); % max over all fA and fP pairs.
            [iFp, iFa] = ind2sub([nLow, nHigh], iLinMax); 
            tpacMat.sPAC.NestingFreq = tpacMat.LowFreq(iFp);
            tpacMat.sPAC.NestedFreq = tpacMat.HighFreqs(iFa);
            
        elseif isfield(tpacMat.sPAC, 'DynamicPAC')
            % size is [nSignals, nTime, nHighFreqs, nTrials], 4th dim if "averaging"/concatenating was selected in process_pac_dynamic.
            % Keep first file's data to avoid loading again.
            tpacIn = tpacMat;
            % Reinitialize output array.
            tpacMat.sPAC.DynamicPAC = zeros(size(tpacMat.sPAC.DynamicPAC, 1:3));
            tpacMat.nAvg = 0;
            %             Nesting = tpacMat.sPAC.DynamicNesting;
            for iFile = 1:N
                if iFile > 1
                    tpacIn = in_bst_timefreq(sInput(iFile).FileName, 0);
                    if ~isequal(tpacIn.Time, tpacMat.Time) || ~isequal(tpacIn.sPAC.HighFreqs, tpacMat.sPAC.HighFreqs)
                        Message = ['Format of file #',num2str(iFile),' does not match the first file'];
                        bst_report('Error', 'process_pac_average', sInput, Message);
                        tpacMat = [];
                        return;
                    elseif ~isequal(size(tpacIn.sPAC.DynamicPAC,1), size(tpacMat.sPAC.DynamicPAC,1))
                        Message = ['Number of sources in file #',num2str(iFile),' is not the same as previous files -- average on sources before averaging files'];
                        bst_report('Error', 'process_pac_average', sInput, Message);
                        tpacMat = [];
                        return;
                    elseif usePhase && ~isequal(size(tpacIn.sPAC.DynamicPhase,1), size(tpacMat.sPAC.DynamicPhase,1))
                        Message = ['Number of sources for phase in file #',num2str(iFile),' is not the same as previous files -- You cannot use phase in averaging'];
                        bst_report('Error', 'process_pac_average', sInput, Message);
                        tpacMat = [];
                        return;
                    end
                end
                if usePhase
                    tpacMat.sPAC.DynamicPAC = tpacMat.sPAC.DynamicPAC + sum(tpacIn.sPAC.DynamicPAC.*exp(1i*tpacIn.sPAC.DynamicPhase), 4);
                else
                    tpacMat.sPAC.DynamicPAC = tpacMat.sPAC.DynamicPAC + sum(tpacIn.sPAC.DynamicPAC, 4);
                end
                % Sum number of trials averaged. Double-check size to be safe in case of concatenated trials.
                nTrials = size(tpacIn.sPAC.DynamicPAC, 4);
                if isempty(tpacIn.nAvg) || (tpacIn.nAvg == 1 && nTrials > 1)
                    tpacIn.nAvg = nTrials;
                elseif tpacIn.nAvg ~= nTrials && nTrials > 1
                    Message = sprintf('Unexpected number of averages in input file; nAvg=%d, nTrials=%d.  Using nTrials.', tpacMat.nAvg, nTrials);
                    bst_report('Warning', 'process_pac_average', sInput, Message);
                    tpacIn.nAvg = nTrials;
                end
                tpacMat.nAvg = tpacMat.nAvg + tpacIn.nAvg;
                %                 Nesting = cat(5,Nesting,tmp.sPAC.DynamicNesting);
            end
            % Divide by total number of trials for average.
            tpacMat.sPAC.DynamicPAC = tpacMat.sPAC.DynamicPAC / tpacMat.nAvg;

            % Recompute max over fA across averaged tPAC, i.e. do max of mean, not mean of max.
            % Careful: not same array dim order than where this happens in process_pac_dynamic.
            [tpacMat.sPAC.TF, iLinMax] = max(abs(tpacMat.sPAC.DynamicPAC), [], 3, 'linear'); 
            [~, ~, iMax] = ind2sub(size(tpacMat.sPAC.DynamicPAC), iLinMax);
            tpacMat.sPAC.NestedFreq = tpacMat.sPAC.HighFreqs(iMax); % vector to 2d array.
            tpacMat.sPAC.NestingFreq = []; % no longer meaningful.

            if usePhase
                tpacMat.sPAC.DynamicPhase = angle(tpacMat.sPAC.DynamicPAC);
                tpacMat.sPAC.PhasePAC = tpacMat.sPAC.DynamicPhase(iLinMax); % phase of TF (ValPAC)
                % Go back to real values after phases extracted.
                tpacMat.sPAC.DynamicPAC = abs(tpacMat.sPAC.DynamicPAC);
            else
                tpacMat.sPAC.PhasePAC = [];
                tpacMat.sPAC.DynamicPhase = [];
            end
            % Averaged PAC over different fP's, so fP no longer meaningful; don't average it.
            tpacMat.sPAC.DynamicNesting = []; 
            FileTag = 'timefreq_dpac_fullmaps';

        else
            Message = 'Unknown file type, not recognized as PAC.';
            bst_report('Error', 'process_pac_average', sInput, Message);
            tpacMat = [];
            return;
        end
end



function OutputFiles = save_pac_files(sProcess, sInput, FileTag, tpacMat)
    % === SAVING THE DATA IN BRAINSTORM ===
    % Getting the study
    [sOutputStudy, iOutputStudy, comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInput);

    % Comment
    tag = '| avg';
    tpacMat.Comment = [tpacMat.Comment, ' ', tag];

    % Preparing the output file
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), FileTag); 

    % Averaging results from the different data file: reset the "DataFile" field
    if isfield(tpacMat, 'DataFile') && ~isempty(tpacMat.DataFile) && (length(uniqueDataFile) ~= 1)
        tpacMat.DataFile = [];
    end

    % Save on disk
    bst_save(OutputFiles{1}, tpacMat, 'v6');
    % Register in database
    db_add_data(iOutputStudy, OutputFiles{1}, tpacMat);
end
