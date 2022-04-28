function varargout = process_pac_analysis( varargin )
% PROCESS_PAC_ANALYSIS: Further analysis of tpac maps.
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
% Authors: Soheila Samiee, 2014-2017
%   - 2.0: SS. Aug. 2017 
%                - Imported in public brainstorm rep
%   - 2.1: SS. Jul. 2018
%                - Bug fix in average over sources (mean)
%
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Basic Analysis of tPAC maps';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Frequency','Time-resolved Phase-Amplitude Coupling'};
    sProcess.Index       = 1019;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    
    % === ANALYSIS TO BE DONE
    sProcess.options.label.Comment = '<U><B>Analysis:</B></U>';
    sProcess.options.label.Type    = 'label';
    sProcess.options.analyze_type.Comment = {'Mean (Over sources)', ...
        'Median (Over sources)','Z-score on time (If no negative time, on total recording)', ...
        'Mean (Over time)'};
    sProcess.options.analyze_type.Type    = 'radio';
    sProcess.options.analyze_type.Value   = 1;
    
        % === Using phase
    sProcess.options.usePhase.Comment = 'Use phase in averaging (mean)';
    sProcess.options.usePhase.Type    = 'checkbox';
    sProcess.options.usePhase.Value   = 0;

end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    isMean   = 0;
    isMedian = 0;
    isZscore = 0;
    isTimeMean = 0;

    usePhase = sProcess.options.usePhase.Value;

    % Get options
    if sProcess.options.analyze_type.Value ==1
        isMean  = 1;
        tag = '| mean';
    elseif sProcess.options.analyze_type.Value ==2
        isMedian  = 1;
        tag = '| median';
    elseif sProcess.options.analyze_type.Value ==3
        isZscore = 1;
        tag = '| zscore';
    elseif sProcess.options.analyze_type.Value ==4
        isTimeMean = 1;
        tag = '| TimeMean';
    end
    
    % Load TF file
    tpacMat = in_bst_timefreq(sInput(1).FileName, 0);
    % Error
    if isempty(tpacMat)
        bst_report('Error', sProcess, sInput, Messages);
        return;
    end
    
    % Apply the appropriate function
    tpac_avg = tpacMat.sPAC.DynamicPAC;    
    if usePhase
        tpac_avg_phase = tpacMat.sPAC.DynamicPhase; 
    end
    
    if isZscore
        iBaseline = find(tpacMat.Time<0);
        if isempty(iBaseline)
            iBaseline = 1:length(tpacMat.Time);
        end
        tpac_avg = process_zscore('Compute', tpac_avg, iBaseline);
        
    elseif isMean
        if usePhase
            tmp = mean(tpac_avg.*exp(1i*tpac_avg_phase),1);
            tpac_avg = abs(tmp);
            tpac_avg_phase = angle(tmp);
        else
            tpac_avg = mean(tpac_avg,1);
        end
        
        if length(sInput)>1
            N = length(sInput);
            for iFile = 2:N
                TimefreqMat2 = in_bst_timefreq(sInput(iFile).FileName, 0);
                if usePhase
                    tmp = mean(TimefreqMat2.sPAC.DynamicPAC.*exp(1i*TimefreqMat2.sPAC.DynamicPhase),1);
                    TimefreqMat2.sPAC.DynamicPAC  = abs(tmp);
                    TimefreqMat2.sPAC.DynamicPhase  = angle(tmp);
                else
                    TimefreqMat2.sPAC.DynamicPAC = mean(TimefreqMat2.sPAC.DynamicPAC,1);                
                end
                TimefreqMat2.TF = TimefreqMat2.sPAC.DynamicPAC;
                %Saving the files
                TimefreqMat2.Comment = [TimefreqMat2.Comment, ' ', tag];
                % Output filename: add file tag
                FileTag = strtrim(strrep(tag, '|', ''));
                pathName = file_fullpath(sInput(iFile).FileName);
                OutputFile = strrep(pathName, '.mat', ['_' FileTag '.mat']);
                OutputFile = file_unique(OutputFile);
                % Save file
                bst_save(OutputFile, TimefreqMat2, 'v6');
                % Add file to database structure
                db_add_data(sInput(iFile).iStudy, OutputFile, TimefreqMat2);
                OutputFiles{end + 1} = OutputFile;
            end
        end
        
    elseif isMedian
        tpac_avg = median(tpac_avg,1);
        if length(sInput)>1
            N = length(sInput);
            for iFile = 2:N
                TimefreqMat2 = in_bst_timefreq(sInput(iFile).FileName, 0);
                TimefreqMat2.sPAC.DynamicPAC = median(TimefreqMat2.sPAC.DynamicPAC,1);
                TimefreqMat2.TF = median(TimefreqMat2.sPAC.DynamicPAC,1);
                %Saving the files
                TimefreqMat2.Comment = [TimefreqMat2.Comment, ' ', tag];
                % Output filename: add file tag
                FileTag = strtrim(strrep(tag, '|', ''));
                pathName = file_fullpath(sInput(iFile).FileName);
                OutputFile = strrep(pathName, '.mat', ['_' FileTag '.mat']);
                OutputFile = file_unique(OutputFile);
                % Save file
                bst_save(OutputFile, TimefreqMat2, 'v6');
                % Add file to database structure
                db_add_data(sInput(iFile).iStudy, OutputFile, TimefreqMat2);
                OutputFiles{end + 1} = OutputFile;
            end
        end
        
    elseif isTimeMean
        if length(sInput)==1
            tpac_avg = repmat(mean(tpac_avg,2),[1,size(tpac_avg,2),1]);
            [PACmax,tmp] = max(abs(tpac_avg),[],1);
            tpacMat.TF = squeeze(PACmax)';        
        elseif length(sInput)>1
            N = length(sInput);
            for iFile = 2:N
                tPACMat2 = in_bst_timefreq(sInput(iFile).FileName, 0);
%                 TimefreqMat2.sPAC.DynamicPAC = median(TimefreqMat2.sPAC.DynamicPAC,1);
%                 TimefreqMat2.TF = median(TimefreqMat2.sPAC.DynamicPAC,1);                
                tpac_avg = repmat(mean(tPACMat2.sPAC.DynamicPAC,2),[1,size(tPACMat2.sPAC.DynamicPAC,2),1]);
                [PACmax,tmp] = max(abs(tpac_avg),[],1);
                tPACMat2.TF = tpac_avg;%squeeze(PACmax)';
                tPACMat2.sPAC.DynamicPAC = tpac_avg;
                
                
                %Saving the files
                tPACMat2.Comment = [tPACMat2.Comment, ' ', tag];
                % Output filename: add file tag
                FileTag = strtrim(strrep(tag, '|', ''));
                pathName = file_fullpath(sInput(iFile).FileName);
                OutputFile = strrep(pathName, '.mat', ['_' FileTag '.mat']);
                OutputFile = file_unique(OutputFile);
                % Save file
                bst_save(OutputFile, tPACMat2, 'v6');
                % Add file to database structure
                db_add_data(sInput(iFile).iStudy, OutputFile, tPACMat2);
                OutputFiles{end + 1} = OutputFile;
            end
        end            
        tpacMat.sPAC.DynamicPAC = tpac_avg;
        tpacMat.TF = tpac_avg;
        if usePhase
            tpacMat.sPAC.DynamicPhase = tpac_avg_phase;
        end
    end
    
    tpacMat.TF = tpac_avg;
    tpacMat.sPAC.DynamicPAC = tpac_avg;
    if usePhase
        tpacMat.sPAC.DynamicPhase = tpac_avg_phase;
    end

    % === SAVING THE DATA IN BRAINSTORM ===
    % Getting the study
    [sOutputStudy, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInput(1));
    % Comment
    tpacMat.Comment = [tpacMat.Comment, ' ', tag];
    % Output filename: add file tag
    FileTag = strtrim(strrep(tag, '|', ''));
    pathName = file_fullpath(sInput(1).FileName); 
    % Preparing the output file
    OutputFile = strrep(pathName, '.mat', ['_' FileTag '.mat']);
    OutputFile = file_unique(OutputFile);
    % Save on disk
    bst_save(OutputFile, tpacMat, 'v6');
    % Register in database
    db_add_data(iOutputStudy, OutputFile, tpacMat);
    OutputFiles{end + 1} = OutputFile;
end




