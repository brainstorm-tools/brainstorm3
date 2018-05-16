function varargout = process_gradnorm( varargin )
% PROCESS_GRADNORM: Compute the norm of each couple of gradiometers in Neuromag recordings

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
% Authors: Francois Tadel, 2010-2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Norm of grad pairs';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 380;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'timefreq'};
    sProcess.OutputTypes = {'data', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.processDim  = 2;    % Process time by time
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = [];
    
    % === GET CHANNEL FILE ===
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    Channel = ChannelMat.Channel;
    % Get gradiometers
    iMag  = good_channel(Channel, [], 'MEG MAG');
    iGrad2 = good_channel(Channel, [], 'MEG GRAD2');
    iGrad3 = good_channel(Channel, [], 'MEG GRAD3');
    if isempty(iGrad2)
        bst_report('Error', sProcess, sInput, 'Cannot identify two types of Neuromag gradiometers in the file.');
        return;
    end

    % === COMPUTE NORM ===
    switch (sInput.FileType)
        case 'data'
            % Load data file
            sMat = in_bst_data(sInput.FileName);
            % Compute norm of each couple of gradiometers
            sMat.F(iGrad2,:) = sqrt(sMat.F(iGrad2,:) .^ 2 + sMat.F(iGrad3,:) .^ 2);
            sMat.F(iGrad3,:) = sMat.F(iGrad2,:);
            sMat.F(iMag,:)   = 0;
            % Redefine ChannelFlag: keep only the first gradiometers
            iBad = setdiff(1:length(sMat.ChannelFlag), iGrad2);
            sMat.ChannelFlag(iBad) = -1;
            % Change DataType
            sMat.DataType = 'gradnorm';
            
        case 'timefreq'
            % Load TF file
            sMat = in_bst_timefreq(sInput.FileName, 0);
            % Get the gradiometers indices
            iGrad2 = find(cellfun(@(c)isequal(c(end),'2'), sMat.RowNames));
            iGrad3 = find(cellfun(@(c)isequal(c(end),'3'), sMat.RowNames));
            % Cannot compute this measure on connectivity measures or incomplete files
            if ~isempty(sMat.RefRowNames) || isempty(iGrad2)
                bst_report('Error', sProcess, sInput, 'Cannot compute this measure on connectivity measures.');
                return;
            end
            % Calculate the norm of the two
            sMat.TF = sqrt(sMat.TF(iGrad2,:,:) .^ 2 + sMat.TF(iGrad3,:,:) .^ 2);
            % Update the rest of the file
            sMat.RowNames = sMat.RowNames(iGrad2);
    end
    
    % Comment
    sMat.Comment = [sMat.Comment, ' | gradnorm'];
    % History
    sMat = bst_history('add', sMat, 'gradnorm', sProcess.Comment);
    % Output filename: add file tag
    OutputFile = strrep(file_fullpath(sInput.FileName), '.mat', ['_gradnorm.mat']);
    OutputFile = file_unique(OutputFile);
    % Save file
    bst_save(OutputFile, sMat, 'v6');
    % Add file to database structure
    db_add_data(sInput.iStudy, OutputFile, sMat);
end




