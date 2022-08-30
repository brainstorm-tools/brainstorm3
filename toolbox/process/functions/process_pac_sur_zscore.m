function varargout = process_pac_sur_zscore( varargin )
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
% Authors: Soheila Samiee, 2018
%   - 1.0: SS. Oct. 2018
%                
%
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'PAC: Z-score with surrogate';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';%{'Frequency','Time-resolved Phase-Amplitude Coupling'};
    sProcess.Index       = 1020;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    sProcess.isSeparator = 0;
    
%     % === ANALYSIS TO BE DONE
%     sProcess.options.label.Comment = '<U><B>Analysis:</B></U>';
%     sProcess.options.label.Type    = 'label';
%     sProcess.options.analyze_type.Comment = {'Mean (Over sources)', ...
%         'Median (Over sources)','Z-score on time (If no negative time, on total recording)', ...
%         'Mean (Over time)'};
%     sProcess.options.analyze_type.Type    = 'radio';
%     sProcess.options.analyze_type.Value   = 1;
    
    % === Label
    sProcess.options.label.Comment = 'Mean on sources: <B>Files A</B> Z-scored with respect to <B>Files B</B><BR><BR>';
    sProcess.options.label.Type    = 'label';
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
function sOutput = Run(sProcess, sInputsA, sInputsB)  %#ok<DEFNU>
%     sOutput = sInputsA;
%     % Colormap
%     sOutput.ColormapType = 'stat2';    
%     % Time-frequency: Change the measure type
%     if strcmpi(sInputsA(1).FileType, 'timefreq')
%         sOutput.Measure = 'other';
%     end


    usePhase = sProcess.options.usePhase.Value;
    tag = '|sur-zscore';

%     % Load first TF file
%     tpacMat = in_bst_timefreq(sInputs(1).FileName, 0);
%     % Error
%     if isempty(tpacMat)
%         bst_report('Error', sProcess, sInput, Messages);
%         return;
%     end
    
    N = length(sInputsA);
    for iFile = 1:N
        tpac = in_bst_timefreq(sInputsA(iFile).FileName, 0);
        tpac_sur = in_bst_timefreq(sInputsB(iFile).FileName, 0);
        if usePhase
            tmp1 = abs(mean(tpac.sPAC.DynamicPAC.*exp(1i*tpac.sPAC.DynamicPhase),1));
            tmp2 = abs(mean(tpac_sur.sPAC.DynamicPAC.*exp(1i*tpac_sur.sPAC.DynamicPhase),1));
        else
            tmp1 = abs(mean(tpac.sPAC.DynamicPAC,1));
            tmp2 = abs(mean(tpac_sur.sPAC.DynamicPAC,1));
        end
        
        tpac.sPAC.DynamicPAC  = (tmp1 - mean(tmp2,4))./std(tmp2, [],4);
        if usePhase
            tpac.sPAC.DynamicPhase  = angle(mean(tpac.sPAC.DynamicPAC.*exp(1i*tpac.sPAC.DynamicPhase),1));
        else
            tpac.sPAC.DynamicPhase  = [];
        end
        
        tpac.TF = tpac.sPAC.DynamicPAC;
        %Saving the files
        tpac.Comment = [tpac.Comment, ' ', tag];
        % Output filename: add file tag
        FileTag = strtrim(strrep(tag, '|', ''));
        pathName = file_fullpath(sInputsA(iFile).FileName);
        sOutput{1} = strrep(pathName, '.mat', ['_' FileTag '.mat']);
        sOutput{1} = file_unique(sOutput{1});
        % Save file
        bst_save(sOutput{1}, tpac, 'v6');
        % Add file to database structure
        db_add_data(sInputsA(iFile).iStudy, sOutput{1}, tpac);
    end

end




