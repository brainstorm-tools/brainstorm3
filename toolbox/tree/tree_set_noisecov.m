function tree_set_noisecov(bstNodes, NoiseCovFile, isDataCov)
% TREE_SET_NOISECOV: Import a new noisecov file for a set of studies.
%
% USAGE:  tree_set_noisecov(bstNodes, NoiseCovFile, isDataCov=0) : Import NoiseCov from file
%         tree_set_noisecov(bstNodes)               : Import NoiseCov from file, NoiseCovFile is asked to the user
%         tree_set_noisecov(bstNodes, 'MatlabVar')  : Import NoiseCov from Matlab variable
%         tree_set_noisecov(bstNodes, 'Compute')    : Compute NoiseCov from data files in studies
%         tree_set_noisecov(bstNodes, 'Identity')   : Uses identity matrix

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
% Authors: Francois Tadel, 2009-2016

% Parse inputs
if (nargin < 2) || isempty(NoiseCovFile)
    NoiseCovFile = '';
end
if (nargin < 3) || isempty(isDataCov)
    isDataCov = 0;
end
% Progress bar
bst_progress('start', 'Covariance estimation', 'Selecting files...');
% Get selected studies
iTargetStudies = tree_channel_studies( bstNodes, 'NoIntra' );
% Remove channel studies without channel file defined
sTargetStudies = bst_get('Study', iTargetStudies);
% Find a study without channel file
iWithoutChan = find(cellfun(@isempty, {sTargetStudies.Channel}));
% Remove them from list
iTargetStudies(iWithoutChan) = [];
sTargetStudies(iWithoutChan) = [];
    
% Import a noisecov in all the specified studies
if ~isempty(iTargetStudies)
    % Source is specified
    if ~isempty(NoiseCovFile) 
        % === COMPUTE ===
        if strcmpi(NoiseCovFile, 'Compute')
            % Get data files
            [iStudies_data, iData] = tree_dependencies(bstNodes, 'data', [], 0);
            if isequal(iStudies_data, -10)
                bst_error('Error in file selection.', 'Covariance estimation', 0);
                return;
            end
            % If no data in the selected nodes
            if isempty(iStudies_data) && (length(bstNodes) == 1)
                [iStudies_data, iData] = bst_get('DataForStudies', iTargetStudies);
            end
            % Still no data: error
            if isempty(iStudies_data)
                bst_error('No recordings selected.', 'Covariance estimation', 0);
                return;
            end
            % Compute NoiseCov matrix
            bst_noisecov(iTargetStudies, iStudies_data, iData, [], isDataCov);
            
        % === IMPORT FROM MATLAB ===
        elseif strcmpi(NoiseCovFile, 'MatlabVar')
            % Get matlab variable
            NoiseCovMat.Comment = 'Noise covariance (Matlab)';
            [NoiseCovMat.NoiseCov, varname] = in_matlab_var();
            % Check if import was cancelled
            if isempty(NoiseCovMat.NoiseCov)
                return
            end
            % Check if input was already a structure
            if isstruct(NoiseCovMat.NoiseCov) && isfield(NoiseCovMat.NoiseCov, 'NoiseCov')
                NoiseCovMat.NoiseCov = NoiseCovMat.NoiseCov.NoiseCov;
            end
            % History: Import from Matlab
            NoiseCovMat = bst_history('add', NoiseCovMat, 'import', ['Import from Matlab variable: ' varname]);
            % Save in database
            import_noisecov(iTargetStudies, NoiseCovMat, [], isDataCov);
            
        % === IDENTITY MATRIX ===
        elseif strcmpi(NoiseCovFile, 'Identity')
            % Use an identity matrix
            import_noisecov(iTargetStudies, 'Identity', [], isDataCov);

        % === IMPORT FROM FILE ===
        else
            NoiseCovMat = NoiseCovFile;
            % Check if input was already a structure
            if isstruct(NoiseCovMat.NoiseCov) && isfield(NoiseCovMat.NoiseCov, 'NoiseCov')
                NoiseCovMat.NoiseCov = NoiseCovMat.NoiseCov.NoiseCov;
            end
            % Save in database
            import_noisecov(iTargetStudies, NoiseCovFile, [], isDataCov);
        end
    else
        import_noisecov(iTargetStudies, [], [], isDataCov);
    end
else
    error('No data available.');
end
% Close progress bar
bst_progress('stop');




