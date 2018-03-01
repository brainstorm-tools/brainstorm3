function varargout = process_pac_analysis( varargin )
% PROCESS_PAC_ANALYSIS: Further analysis of tpac maps.
%
% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
%
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Basic Analysis of tPAC maps ';
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
    if isZscore
        iBaseline = find(tpacMat.Time<0);
        if isempty(iBaseline)
            iBaseline = 1:length(tpacMat.Time);
        end
        tpac_avg = process_zscore('Compute', tpac_avg, iBaseline);
    elseif isMean
        tpac_avg = mean(tpac_avg,1);
        if length(sInput)>1
            N = length(sInput);
            for iFile = 2:N
                TimefreqMat2 = in_bst_timefreq(sInput(iFile).FileName, 0);
                TimefreqMat2.sPAC.DynamicPAC = mean(TimefreqMat2.sPAC.DynamicPAC,1);
                TimefreqMat2.TF = mean(TimefreqMat2.sPAC.DynamicPAC,1);
                %Saving the files
                TimefreqMat2.Comment = [TimefreqMat2.Comment, ' ', tag];
                % Output filename: add file tag
                FileTag = strtrim(strrep(tag, '|', ''));
                pathName = file_fullpath(sInput(iFile).FileName);
                OutputFile{1} = strrep(pathName, '.mat', ['_' FileTag '.mat']);
                OutputFile{1} = file_unique(OutputFile{1});
                % Save file
                bst_save(OutputFile{1}, TimefreqMat2, 'v6');
                % Add file to database structure
                db_add_data(sInput(iFile).iStudy, OutputFile{1}, TimefreqMat2);
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
                OutputFile{1} = strrep(pathName, '.mat', ['_' FileTag '.mat']);
                OutputFile{1} = file_unique(OutputFile{1});
                % Save file
                bst_save(OutputFile{1}, TimefreqMat2, 'v6');
                % Add file to database structure
                db_add_data(sInput(iFile).iStudy, OutputFile{1}, TimefreqMat2);
            end
        end
        
    elseif isTimeMean
        tpac_avg = repmat(mean(tpac_avg,2),[1,size(tpac_avg,2),1]);
        [PACmax,tmp] = max(abs(tpac_avg),[],1);
        tpacMat.TF = squeeze(PACmax)';
    end    
    tpacMat.sPAC.DynamicPAC = tpac_avg;
    tpacMat.TF = tpac_avg;        
    
    % === SAVING THE DATA IN BRAINSTORM ===
    % Getting the study
    [sOutputStudy, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInput);       
    % Comment
    tpacMat.Comment = [tpacMat.Comment, ' ', tag];
    % Output filename: add file tag
    FileTag = strtrim(strrep(tag, '|', ''));
%     pathName = file_fullpath(sOutputStudy.FileName); 
    FileTag = [FileTag,'_timefreq_dpac_fullmaps']; 
    % Preparing the output file
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), FileTag); 
    OutputFiles{1} = file_unique(OutputFiles{1});     
    % Save on disk
    bst_save(OutputFiles{1}, tpacMat, 'v6');
    % Register in database
    db_add_data(iOutputStudy, OutputFiles{1}, tpacMat);
end




