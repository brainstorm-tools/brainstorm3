function varargout = select_pos_file(varargin)
% SELECT_POS_FILE: Select the best .pos (Polhemus) file among several candidates.
%
% USAGE:  pos_file = select_pos_file('SelectPosFile', posFiles, verbose=1)
%         score    = select_pos_file('ScorePosFile', ChannelMat)
%
% When several .pos files are available for the same CTF dataset, Brainstorm cannot know which one
% to use. This function picks, in a deterministic way, the file that is most likely to contain the
% complete digitization of the head. Three point types are considered (electrodes are ignored,
% they are read as EEG channels): the anatomical fiducials (NAS/LPA/RPA), the MEG head coils
% (HPI-N/L/R) and the digitized points. Files are ranked by combination of types (fiducials +
% coils + points first) and, within the same combination, by the number of head points.
% A clear message is displayed for the user.

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

eval(macro_method);
end


%% ===== SELECT POS FILE =====
function pos_file = SelectPosFile(posFiles, verbose, isInteractive)
    % SELECT_POS_FILE: Select the best .pos file among the given candidates.
    %
    % INPUT:
    %    - posFiles      : Cell array of full paths to the .pos candidate files
    %    - verbose       : If 1, display the selection in the command window
    %    - isInteractive : If 1, ask the user to confirm/change the selection in a dialog box,
    %                      with the best-scored file pre-selected. Optional, default: 0 (the
    %                      best-scored file is selected automatically, deterministically).
    % OUTPUT:
    %    - pos_file      : Full path to the selected file, or [] if no file could be read
    pos_file = [];
    % Parse inputs
    if (nargin < 2) || isempty(verbose)
        verbose = 1;
    end
    if (nargin < 3) || isempty(isInteractive)
        isInteractive = 0;
    end
    if ischar(posFiles)
        posFiles = {posFiles};
    end
    % Loop on all the candidate files (-1: unreadable file or unusable combination of point types)
    scores = -ones(1, length(posFiles));
    for i = 1:length(posFiles)
        % Try to read the file (skip the ones that cannot be read)
        try
            ChannelMat = in_channel_pos(posFiles{i});
            scores(i) = select_pos_file('ScorePosFile', ChannelMat);
        catch
            scores(i) = -1;
            disp(['CTF> Warning: Could not read the Polhemus file, ignoring: ' posFiles{i}]);
        end
    end
    % No usable file: in batch/headless mode import nothing, interactive sessions still let
    % the user pick a file manually (nothing is recommended in that case).
    [bestScore, iBest] = max(scores);
    if (bestScore < 0)
        if ~isInteractive
            disp(['CTF> Warning: No usable .pos file (readable, with at least two point types among ' ...
                  'anatomical fiducials, MEG head coils and digitized points), no head points will be imported.']);
            return;
        end
        % Pre-select the first file, without any recommendation
        iBest = 1;
    end
    pos_file = posFiles{iBest};
    % Interactive session: let the user confirm the automatic selection, or choose another file.
    % In batch/headless mode the best-scored file is selected automatically.
    if isInteractive && (length(posFiles) > 1)
        if (bestScore >= 0)
            dialogMsg = ['Multiple .pos (Polhemus) files were found in the dataset folder. ' ...
                         'The file recommended below has the best combination of point types ' ...
                         '(anatomical fiducials, MEG head coils and digitized points). ' ...
                         'Please confirm this file, or select another one if needed.'];
        else
            dialogMsg = ['Multiple .pos (Polhemus) files were found in the dataset folder, ' ...
                         'but none contains a usable combination of point types. ' ...
                         'Please select the file to import manually.'];
        end
        iChoice = java_dialog('radio', dialogMsg, 'Select the .pos file to import', [], posFiles, iBest);
        % If the user cancelled the dialog: keep the automatic selection
        if ~isempty(iChoice)
            pos_file = posFiles{iChoice};
            bestScore = scores(iChoice);
        end
    end
    % Report the selection
    if verbose
        if (bestScore >= 0)
            disp(['CTF> Multiple .pos files found, selected: ' pos_file ' (score: ' num2str(bestScore) ')']);
        else
            disp(['CTF> Multiple .pos files found, no file is fully usable, selected: ' pos_file]);
        end
        disp('BST> Warning: Please verify that the selected .pos file is the correct one.');
    end
end


%% ===== SCORE POS FILE =====
function score = ScorePosFile(ChannelMat)
    % SCORE_POS_FILE: Rank a digitized head points file, to select which file is the most likely
    % to contain the complete digitization of the head.
    % Three point types are considered, ignoring the electrodes (EEG channels):
    %   - the complete set of anatomical fiducials (NAS, LPA and RPA)
    %   - the complete set of MEG head coils (HPI-N, HPI-L and HPI-R)
    %   - the digitized points (any other head point)
    % The score encodes first the rank of the combination of types present (a file with only a
    % single type cannot be used and gets -1), then the total number of head points, used only
    % to break ties between files with the same combination:
    %   4e6 + nPoints : fiducials + coils + digitized points (complete digitization, best)
    %   3e6 + nPoints : coils + digitized points
    %   2e6 + nPoints : fiducials + digitized points
    %   1e6 + nPoints : fiducials + coils (no digitized points)
    %          -1     : unusable (0 or 1 point type, or file without head points)
    % INPUT:
    %    - ChannelMat : Channel structure read from a .pos file (in_channel_pos)
    % OUTPUT:
    %    - score      : Combination-based score described above
    score = -1;
    % Head points
    if ~isfield(ChannelMat, 'HeadPoints') || ~isfield(ChannelMat.HeadPoints, 'Label') || ...
            ~isfield(ChannelMat.HeadPoints, 'Loc') || isempty(ChannelMat.HeadPoints.Label)
        return;
    end
    labels = ChannelMat.HeadPoints.Label;
    % Complete anatomical fiducial set (NAS/LPA/RPA, under their various names)
    isNas = strcmpi(labels, 'Nasion') | strcmpi(labels, 'NAS');
    isLpa = strcmpi(labels, 'Left')   | strcmpi(labels, 'LPA');
    isRpa = strcmpi(labels, 'Right')  | strcmpi(labels, 'RPA');
    hasFid = any(isNas) && any(isLpa) && any(isRpa);
    % Complete MEG head coil set (HPI-N/L/R)
    isCoil = strcmpi(labels, 'HPI-N') | strcmpi(labels, 'HPI-L') | strcmpi(labels, 'HPI-R');
    hasCoil = any(strcmpi(labels, 'HPI-N')) && any(strcmpi(labels, 'HPI-L')) && any(strcmpi(labels, 'HPI-R'));
    % Digitized points: head points that are neither fiducials nor head coils
    hasPoints = any(~(isNas | isLpa | isRpa | isCoil));
    % Rank the combination of point types present
    if hasFid && hasCoil && hasPoints
        combination = 4;
    elseif hasCoil && hasPoints
        combination = 3;
    elseif hasFid && hasPoints
        combination = 2;
    elseif hasFid && hasCoil
        combination = 1;
    else
        % A single type (or none) cannot be used to define the head geometry
        return;
    end
    % Tie-breaker within the same combination: the total number of head points
    score = combination * 1e6 + length(labels);
end