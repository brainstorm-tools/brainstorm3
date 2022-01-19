function OutputFile = dipoles_merge(DipoleFiles)
% DIPOLES_MERGE: Merge multiple dipoles files

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
% Authors: Elizabeth Bock, Francois Tadel, Jeremy Moreau, 2015


% Load in all dipole files
for i = 1:length(DipoleFiles)
    % Check file path file
    if ~file_exist(DipoleFiles{i})
        DipoleFiles{i} = file_fullpath(DipoleFiles{i});
    end
    if ~file_exist(DipoleFiles{i})
        error(['File not found: ' DipoleFiles{i}]);
    end
    % Load file
    DipoleMat = load(DipoleFiles{i});
    % Do not accept subsets of dipoles
    if (DipoleMat.Subset > 1)
        error('TODO: Update this function for merging files with subsets.')
    end
    % First file: template
    if (i == 1)
        MergeMat = DipoleMat;
        MergeMat.DipoleNames = {};
        MergeMat.Dipole = [];
        
        % Calculate sampling rate of first dipole file
        if (length(DipoleMat.Time) == 1)
            DipOneSamplingRate = 0;  % Set sampling rate to 0 if only one dipole
        elseif (length(DipoleMat.Time) > 1)
            DipOneSamplingRate = DipoleMat.Time(2) - DipoleMat.Time(1);
        end
    
    % Following files: check that they are compatible
    else
        if ((DipOneSamplingRate ~= 0) && (length(DipoleMat.Time) > 1))
            if (abs(DipOneSamplingRate - (DipoleMat.Time(2) - DipoleMat.Time(1))) > 0.00001)
                error('Only files with equal sampling rate can be merged.');
            end
        elseif (DipoleMat.Subset ~= MergeMat.Subset)
            error('Only files with equal number of channel subsets can be merged.');
        end
    end
    
    % Names just have the group number (i.e. Group #1, Group #2)
    lastGroupNumber = length(MergeMat.DipoleNames);
    nGroups = length(DipoleMat.DipoleNames);
    % Loop through the groups
    for g = 1:nGroups
        % Add the name 
        MergeMat.DipoleNames{end+1} = ['Group #' num2str(lastGroupNumber + g)];
        % Update the index numbers
        ind = find([DipoleMat.Dipole.Index] == g);
        if ~isempty(ind)
            [DipoleMat.Dipole(ind).Index] = deal(lastGroupNumber + g);
        end
    end
    % Merge the Dipole structures
    MergeMat.Dipole = [MergeMat.Dipole, DipoleMat.Dipole];
    MergeMat.DataFile = '';
    % Merge history
    MergeMat = bst_history('add', MergeMat, 'merge', ['Merged file: ' file_short(DipoleFiles{i})]);
end

% Set new Time sampling for merged dipoles
MergeMat.Time = unique([MergeMat.Dipole.Time]);

% ===== SAVE NEW FILE =====
% Update the comment to reflect the number of merged files
MergeMat.Comment = ['Merge: ' num2str(length(DipoleFiles)) ' files'];
% Create output filename
OutputFile = file_unique(bst_fullfile(fileparts(DipoleFiles{1}), 'dipoles_merged.mat'));
% Save new file in Brainstorm format
bst_save(OutputFile, MergeMat, 'v7');


% ===== UPDATE DATABASE =====
% Get study of the first file
[sStudy,iStudy] = bst_get('DipolesFile', file_short(DipoleFiles{1}));
% Create structure
BstDipolesMat = db_template('Dipoles');
BstDipolesMat.FileName = file_short(OutputFile);
BstDipolesMat.Comment  = MergeMat.Comment;
BstDipolesMat.DataFile = MergeMat.DataFile;
% Add to study
sStudy = bst_get('Study', iStudy);
iDipole = length(sStudy.Dipoles) + 1;
sStudy.Dipoles(iDipole) = BstDipolesMat;
% Save study
bst_set('Study', iStudy, sStudy);
% Update tree
panel_protocols('UpdateNode', 'Study', iStudy);
% Select node
panel_protocols('SelectNode', [], BstDipolesMat.FileName);
% Save database
db_save();
