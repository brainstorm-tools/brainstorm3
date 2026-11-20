function test_headpoints_ctf()
% TEST_HEADPOINTS_CTF Test the fixes for issue #944 (CTF coordinate system and adding head points).
%
%  1. process_headpoints_add: warning and proposed alignment when adding head points while the MEG
%     sensors are not (or not correctly) aligned in SCS.
%  2. select_pos_file: selection of the best .pos file when several are present (e.g. in a .ds).
%
% Usage:
%   cd <brainstorm3>
%   addpath('toolbox');                       % Add all the Brainstorm functions to the path
%   brainstorm nogui local                    % Start Brainstorm without GUI (for the full test)
%   test_headpoints_ctf()                     % Run all the tests
%
% The first part of the test (pure logic) does not require a running Brainstorm, as long as the
% toolboxes "toolbox/process/functions", "toolbox/io" and "toolbox/core" are in the Matlab path.
% The second part (integration with .pos files and channel alignment) requires Brainstorm to start.
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

%% ===== SETUP: PATH AND BRAINSTORM =====
% Add the Brainstorm toolboxes to the path (in case the user did not add them)
ToolboxDir = fileparts(fileparts(mfilename('fullpath')));
if exist(fullfile(ToolboxDir, 'brainstorm.m'), 'file')
    addpath(genpath(ToolboxDir));
end
% Start Brainstorm for the integration tests (skipped if it cannot start)
isBstRunning = false;
if exist('brainstorm', 'file')
    try
        isBstRunning = (brainstorm('status') ~= 0);
    catch
        isBstRunning = false;
    end
    if ~isBstRunning
        % Preferred: "nogui" mode (a hidden user interface exists). In fully headless
        % environments (no display at all) this fails when loading the Java window icons,
        % so fall back to "server" mode, which creates no Java objects at all.
        try
            brainstorm nogui local;
            isBstRunning = (brainstorm('status') ~= 0);
        catch
            isBstRunning = false;
        end
        if ~isBstRunning
            try
                brainstorm server local;
                isBstRunning = (brainstorm('status') ~= 0);
            catch
                isBstRunning = false;
            end
        end
    end
end

fprintf('=== test_headpoints_ctf ===\n');

%% ===== TEST 1: GET_MEG_ALIGN_WARNING =====
% Channel file without any MEG transformation (MEG in "Native" coordinates)
ChannelMatNative = struct();
ChannelMatNative.TransfMeg = {};
ChannelMatNative.TransfMegLabels = {};
ChannelMatNative.TransfEeg = {};
ChannelMatNative.TransfEegLabels = {};
ChannelMatNative.Channel = struct('Name', {'MEG 1'}, 'Type', {'MEG'}, 'Loc', {[0; 0; 0.5]}, 'Orient', {[]});
% Head points with the three anatomical fiducials AND the three head coils (positions in meters):
% both sets must be present, a single set of markers is assumed to be head coils (older datasets)
HeadPointsFid = struct();
HeadPointsFid.Loc   = [ 0.00, 0.10, 0.10;    % NAS
                       -0.07, 0.00, 0.02;    % LPA
                        0.07, 0.00, 0.02;    % RPA
                        0.00, 0.11, 0.12;    % HPI-N
                       -0.08, 0.01, 0.03;    % HPI-L
                        0.08, 0.01, 0.03]';  % HPI-R
HeadPointsFid.Label = {'NAS', 'LPA', 'RPA', 'HPI-N', 'HPI-L', 'HPI-R'};
HeadPointsFid.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL', 'HPI', 'HPI', 'HPI'};
% Case 1a: native coordinates + fiducials => warning + offer to align
[strWarn, isOfferAlign] = process_headpoints_add('GetMegAlignWarning', ChannelMatNative, HeadPointsFid);
assert(~isempty(strWarn), 'Test 1a: expected a warning when MEG is in native coordinates and fiducials are added');
assert(isOfferAlign == 1, 'Test 1a: expected an alignment offer');
% Case 1b: native coordinates + no fiducials => warning only
[strWarn, isOfferAlign] = process_headpoints_add('GetMegAlignWarning', ChannelMatNative, struct());
assert(~isempty(strWarn), 'Test 1b: expected a warning when no fiducials are available');
assert(isOfferAlign == 0, 'Test 1b: expected no alignment offer without fiducials');
% Case 1c: SCS transformation exists + fiducials => warning only (no re-alignment yet)
ChannelMatScs = ChannelMatNative;
ChannelMatScs.TransfMegLabels = {'Native=>Brainstorm/CTF'};
ChannelMatScs.TransfEegLabels = {'Native=>Brainstorm/CTF'};
[strWarn, isOfferAlign] = process_headpoints_add('GetMegAlignWarning', ChannelMatScs, HeadPointsFid);
assert(~isempty(strWarn), 'Test 1c: expected a warning when the new fiducials may define a different SCS');
assert(isOfferAlign == 0, 'Test 1c: expected no alignment offer with an existing CTF transformation');
% Case 1d: SCS transformation exists + no fiducials => no warning, no offer
[strWarn, isOfferAlign] = process_headpoints_add('GetMegAlignWarning', ChannelMatScs, struct());
assert(isempty(strWarn), 'Test 1d: expected no warning when the MEG is aligned in SCS');
assert(isOfferAlign == 0, 'Test 1d: expected no offer');
% Case 1e: no MEG channel in the channel file => no warning, no offer (alignment is not relevant)
ChannelMatEeg = struct();
ChannelMatEeg.Channel = struct('Name', {'EEG 1'}, 'Type', {'EEG'}, 'Loc', {[0; 0; 0.5]}, 'Orient', {[]});
[strWarn, isOfferAlign] = process_headpoints_add('GetMegAlignWarning', ChannelMatEeg, HeadPointsFid);
assert(isempty(strWarn), 'Test 1e: expected no warning when there is no MEG channel');
assert(isOfferAlign == 0, 'Test 1e: expected no alignment offer without MEG channels');
% Case 1f: native coordinates + a single set of markers (assumed head coils) => warning only
HeadPointsCoilsOnly = struct();
HeadPointsCoilsOnly.Loc   = HeadPointsFid.Loc(:, 4:6);
HeadPointsCoilsOnly.Label = {'HPI-N', 'HPI-L', 'HPI-R'};
HeadPointsCoilsOnly.Type  = {'HPI', 'HPI', 'HPI'};
[strWarn, isOfferAlign] = process_headpoints_add('GetMegAlignWarning', ChannelMatNative, HeadPointsCoilsOnly);
assert(~isempty(strWarn), 'Test 1f: expected a warning when MEG is in native coordinates');
assert(isOfferAlign == 0, 'Test 1f: a single set of markers (assumed coils) must not offer an alignment');
% Case 1g: legacy data: a single set labeled like the anatomical fiducials (assumed head coils)
HeadPointsLegacy = struct();
HeadPointsLegacy.Loc   = HeadPointsFid.Loc(:, 1:3);
HeadPointsLegacy.Label = {'NAS', 'LPA', 'RPA'};
HeadPointsLegacy.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL'};
[strWarn, isOfferAlign] = process_headpoints_add('GetMegAlignWarning', ChannelMatNative, HeadPointsLegacy);
assert(~isempty(strWarn), 'Test 1g: expected a warning when MEG is in native coordinates');
assert(isOfferAlign == 0, 'Test 1g: a legacy single set (assumed coils) must not offer an alignment');
fprintf('Test 1 (GetMegAlignWarning): passed\n');

%% ===== TEST 2: SCORE_POS_FILE =====
% File with all the anatomical fiducials, the head coils and extra points (combination 4)
ChannelMatBest = struct();
ChannelMatBest.HeadPoints.Label = {'NAS', 'LPA', 'RPA', 'HPI-N', 'HPI-L', 'HPI-R', 'EXTRA', 'EXTRA'};
ChannelMatBest.HeadPoints.Loc   = zeros(3, 8);
ChannelMatBest.HeadPoints.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL', 'HPI', 'HPI', 'HPI', 'EXTRA', 'EXTRA'};
scoreBest = select_pos_file('ScorePosFile', ChannelMatBest);
assert(scoreBest == 4e6 + 8, 'Test 2a: expected score %d, got %d', 4e6 + 8, scoreBest);
% File with only digitized points: a single type cannot be used
ChannelMatPoints = struct();
ChannelMatPoints.HeadPoints.Label = {'EXTRA', 'EXTRA', 'EXTRA'};
ChannelMatPoints.HeadPoints.Loc   = zeros(3, 3);
ChannelMatPoints.HeadPoints.Type  = {'EXTRA', 'EXTRA', 'EXTRA'};
scorePoints = select_pos_file('ScorePosFile', ChannelMatPoints);
assert(scorePoints == -1, 'Test 2b: expected score -1, got %d', scorePoints);
% Empty channel file: unusable
assert(select_pos_file('ScorePosFile', struct()) == -1, 'Test 2c: expected score -1');
% Head coils + digitized points (combination 3), no anatomical fiducials
ChannelMatCoils = struct();
ChannelMatCoils.HeadPoints.Label = {'HPI-N', 'HPI-L', 'HPI-R', 'EXTRA'};
ChannelMatCoils.HeadPoints.Loc   = zeros(3, 4);
ChannelMatCoils.HeadPoints.Type  = {'HPI', 'HPI', 'HPI', 'EXTRA'};
scoreCoils = select_pos_file('ScorePosFile', ChannelMatCoils);
assert(scoreCoils == 3e6 + 4, 'Test 2d: expected score %d, got %d', 3e6 + 4, scoreCoils);
% Anatomical fiducials + digitized points (combination 2), no head coils
ChannelMatFid = struct();
ChannelMatFid.HeadPoints.Label = {'NAS', 'LPA', 'RPA', 'EXTRA'};
ChannelMatFid.HeadPoints.Loc   = zeros(3, 4);
ChannelMatFid.HeadPoints.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL', 'EXTRA'};
scoreFid = select_pos_file('ScorePosFile', ChannelMatFid);
assert(scoreFid == 2e6 + 4, 'Test 2e: expected score %d, got %d', 2e6 + 4, scoreFid);
% Fiducials + head coils without digitized points (combination 1)
ChannelMatNoPoints = struct();
ChannelMatNoPoints.HeadPoints.Label = {'NAS', 'LPA', 'RPA', 'HPI-N', 'HPI-L', 'HPI-R'};
ChannelMatNoPoints.HeadPoints.Loc   = zeros(3, 6);
ChannelMatNoPoints.HeadPoints.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL', 'HPI', 'HPI', 'HPI'};
scoreNoPoints = select_pos_file('ScorePosFile', ChannelMatNoPoints);
assert(scoreNoPoints == 1e6 + 6, 'Test 2f: expected score %d, got %d', 1e6 + 6, scoreNoPoints);
% Repeated fiducial measurements must not raise the combination rank
ChannelMatDup = ChannelMatFid;
ChannelMatDup.HeadPoints.Label = {'NAS', 'LPA', 'RPA', 'NAS', 'EXTRA'};
ChannelMatDup.HeadPoints.Loc   = zeros(3, 5);
ChannelMatDup.HeadPoints.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL', 'CARDINAL', 'EXTRA'};
scoreDup = select_pos_file('ScorePosFile', ChannelMatDup);
assert(scoreDup == 2e6 + 5, 'Test 2g: expected score %d, got %d', 2e6 + 5, scoreDup);
assert(scoreDup < scoreCoils, 'Test 2h: a duplicated fiducial must not beat coils + points');
fprintf('Test 2 (ScorePosFile): passed\n');

%% ===== TEST 3: SELECT_POS_FILE (integration, requires Brainstorm) =====
if ~isBstRunning
    fprintf('Test 3 (SelectPosFile): skipped, Brainstorm is not running\n');
else
    % Temporary directory with two .pos files
    tmpDir = fullfile(tempdir, sprintf('bst_test_ctf_%d', round(rand() * 1e6)));
    if ~exist(tmpDir, 'dir')
        mkdir(tmpDir);
    end
    % .pos with EEG electrodes only (e.g. recorded before putting the cap with the head points)
    posEeg = fullfile(tmpDir, 'eeg_only.pos');
    fid = fopen(posEeg, 'w');
    fprintf(fid, '1 E1 0.01 0.02 0.03\n');
    fprintf(fid, '2 E2 0.02 0.03 0.04\n');
    fprintf(fid, '3 E3 0.03 0.04 0.05\n');
    fprintf(fid, '4 E4 0.04 0.05 0.06\n');
    fprintf(fid, '5 E5 0.05 0.06 0.07\n');
    fclose(fid);
    % .pos with anatomical fiducials, head coils and digitized points
    posHeadshape = fullfile(tmpDir, 'headshape.pos');
    fid = fopen(posHeadshape, 'w');
    fprintf(fid, 'NAS 0.00 0.10 0.10\n');
    fprintf(fid, 'LPA -0.07 0.00 0.02\n');
    fprintf(fid, 'RPA 0.07 0.00 0.02\n');
    fprintf(fid, 'HPI-N 0.00 0.11 0.12\n');
    fprintf(fid, 'HPI-L -0.08 0.01 0.03\n');
    fprintf(fid, 'HPI-R 0.08 0.01 0.03\n');
    fprintf(fid, '0.01 0.02 0.03\n');
    fprintf(fid, '0.02 0.03 0.04\n');
    fprintf(fid, '0.03 0.04 0.05\n');
    fclose(fid);
    % Select the best file: should be the headshape file with the fiducials
    selFile = select_pos_file('SelectPosFile', {posEeg, posHeadshape}, 0);
    assert(strcmp(selFile, posHeadshape), 'Test 3: expected to select the headshape file, got %s', selFile);
    % Cleanup
    delete(posEeg, posHeadshape);
    rmdir(tmpDir);
    fprintf('Test 3 (SelectPosFile): passed\n');
end

%% ===== TEST 4: ALIGN_MEG_TO_SCS (integration, requires Brainstorm) =====
if ~isBstRunning
    fprintf('Test 4 (AlignMegToScs): skipped, Brainstorm is not running\n');
else
    % Channel file with one MEG sensor in Native (head-coil based) coordinates
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = 'CTF test';
    ChannelMat.Channel = db_template('channeldesc');
    ChannelMat.Channel.Name  = 'MEG 1';
    ChannelMat.Channel.Type  = 'MEG';
    ChannelMat.Channel.Loc   = [0; 0; 0.5];
    ChannelMat.Channel.Orient = [];
    ChannelMat.TransfMeg = {};                  % No "Native=>Brainstorm/CTF" transformation
    ChannelMat.TransfMegLabels = {};
    ChannelMatNative = ChannelMat;               % Fresh native copy for the negative cases below
    % Head points with the anatomical fiducials AND the head coils (same native reference frame,
    % positions in meters): both sets are required for the alignment to be proposed
    HeadPoints = struct();
    HeadPoints.Loc   = [ 0.00, 0.10, 0.10;    % NAS
                        -0.07, 0.00, 0.02;    % LPA
                         0.07, 0.00, 0.02;    % RPA
                         0.00, 0.11, 0.12;    % HPI-N
                        -0.08, 0.01, 0.03;    % HPI-L
                         0.08, 0.01, 0.03]';  % HPI-R
    HeadPoints.Label = {'NAS', 'LPA', 'RPA', 'HPI-N', 'HPI-L', 'HPI-R'};
    HeadPoints.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL', 'HPI', 'HPI', 'HPI'};
    % Pre-merge the head points in the channel file, as AddHeadpoints() does before proposing the alignment
    ChannelMat.HeadPoints = HeadPoints;
    % Align the MEG sensors in SCS
    ChannelMat = process_headpoints_add('AlignMegToScs', ChannelMat, HeadPoints);
    assert(ismember('Native=>Brainstorm/CTF', ChannelMat.TransfMegLabels), 'Test 4a: expected "Native=>Brainstorm/CTF" transformation');
    assert(~isequal(ChannelMat.Channel.Loc, [0; 0; 0.5]), 'Test 4b: expected the sensor position to change after alignment');
    % The SCS coordinate system must be fully defined
    assert(isfield(ChannelMat.SCS, 'Origin') && (length(ChannelMat.SCS.Origin) == 3), 'Test 4e: expected SCS.Origin to be defined');
    assert(isfield(ChannelMat.SCS, 'R') && isequal(size(ChannelMat.SCS.R), [3 3]), 'Test 4f: expected a 3x3 SCS rotation matrix');
    % The head points must have been converted to SCS too
    assert(isfield(ChannelMat.HeadPoints, 'Loc') && ~isempty(ChannelMat.HeadPoints.Loc) && ~isequal(ChannelMat.HeadPoints.Loc, HeadPoints.Loc), 'Test 4g: expected the head points to be converted to SCS');
    % Calling again must not apply the transformation twice (safety guard in AlignMegToScs)
    LocAfterFirstAlign = ChannelMat.Channel.Loc;
    ChannelMat = process_headpoints_add('AlignMegToScs', ChannelMat, HeadPoints);
    assert(isequal(ChannelMat.Channel.Loc, LocAfterFirstAlign), 'Test 4c: expected the sensor position to stay the same when called again');
    assert(numel(find(strcmp(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF'))) == 1, 'Test 4d: expected only one "Native=>Brainstorm/CTF" transformation');
    % Missing fiducials: the channel file must be returned unchanged (fresh native channel,
    % so the check is on the fiducials, not on the "already aligned" safety guard)
    HeadPointsNoFid = struct();
    HeadPointsNoFid.Loc   = [0.01; 0.02; 0.03];
    HeadPointsNoFid.Label = {'EXTRA'};
    HeadPointsNoFid.Type  = {'EXTRA'};
    ChannelMatNoFid = process_headpoints_add('AlignMegToScs', ChannelMatNative, HeadPointsNoFid);
    assert(isequal(ChannelMatNoFid, ChannelMatNative), 'Test 4h: expected the channel file to be unchanged when fiducials are missing');
    % Single set of markers (assumed head coils, e.g. coils-only file): unchanged too
    HeadPointsCoilsOnly = struct();
    HeadPointsCoilsOnly.Loc   = HeadPoints.Loc(:, 4:6);
    HeadPointsCoilsOnly.Label = {'HPI-N', 'HPI-L', 'HPI-R'};
    HeadPointsCoilsOnly.Type  = {'HPI', 'HPI', 'HPI'};
    ChannelMatCoilsOnly = process_headpoints_add('AlignMegToScs', ChannelMatNative, HeadPointsCoilsOnly);
    assert(isequal(ChannelMatCoilsOnly, ChannelMatNative), 'Test 4i: expected the channel file to be unchanged with a single set of markers');
    % Legacy single set labeled like the anatomical fiducials (assumed head coils): unchanged too
    HeadPointsLegacy = struct();
    HeadPointsLegacy.Loc   = HeadPoints.Loc(:, 1:3);
    HeadPointsLegacy.Label = {'NAS', 'LPA', 'RPA'};
    HeadPointsLegacy.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL'};
    ChannelMatLegacy = process_headpoints_add('AlignMegToScs', ChannelMatNative, HeadPointsLegacy);
    assert(isequal(ChannelMatLegacy, ChannelMatNative), 'Test 4j: expected the channel file to be unchanged with a legacy single set');
    fprintf('Test 4 (AlignMegToScs): passed\n');
end

fprintf('\nAll tests completed.\n');
end