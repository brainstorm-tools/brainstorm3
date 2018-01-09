function [iSel, iEcg] = ImaGIN_select_channels(chNames, isSEEG)
% IMAGIN_SELECT_CHANNELS Keep only channels of interest.
%
% USAGE:  [iSel, iEcg] = ImaGIN_select_channels(chNames, isSEEG=1)
%
% INPUT: 
%    - chNames : Cell-array of strings
%    - isSEEG  : 1 if the data is SEEG, 0 if regular EEG
%
% OUTPUT:
%    - iSel : Array of indices of the channels that are considered as valid
%    - iEcg : Array of indices of the channels that are identified as ECG

% -=============================================================================
% This function is part of the ImaGIN software: 
% https://f-tract.eu/
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS
% DO NOT ASSUME ANY LIABILITY OR RESPONSIBILITY FOR ITS USE IN ANY CONTEXT.
%
% Copyright (c) 2000-2018 Inserm U1216
% =============================================================================-
%
% Authors: Francois Tadel, 2017

% Parse inputs
if (nargin < 2) || isempty(isSEEG)
    isSEEG = 1;
end

% Get all names: remove special characters
AllNames = cellfun(@(c)c(~ismember(c, ' .,?!-_@#$%^&*+*=()[]{}|/')), chNames, 'UniformOutput', 0);
AllTags  = cell(size(AllNames));
AllInd   = cell(size(AllNames));
isNoInd  = zeros(size(AllNames));
% Separate characters and numbers in the names
for i = 1:length(AllNames)
    % Find the last letter in the name
    iLastLetter = find(~ismember(AllNames{i}, '0123456789'), 1, 'last');
    if isempty(iLastLetter)
        iLastLetter = 0;
    end
    AllTags{i} = AllNames{i}(1:iLastLetter);
    % For EEG: The separate name/index does not make sense
    if ~isSEEG
        AllInd{i} = sprintf('%d',i);
        isNoInd(i) = 0;
    % If there are digits at the end of the name: use them as the index of the contact
    elseif (iLastLetter < length(AllNames{i}))
        AllInd{i} = AllNames{i}(iLastLetter+1:end);
    else
        isNoInd(i) = 1;
        AllInd{i} = '0';
    end
end
% Convert indices to double values
AllInd = cellfun(@str2num, AllInd);
    
% Remove all the channels with more than 18x the same tag (this is not SEEG)
if isSEEG
    uniqueTags = unique(AllTags);
    for i = 1:length(uniqueTags)
        % Get channels of this tag
        iTag = find(strcmpi(uniqueTags{i}, AllTags));
        % If the tag is "X": Used by Nihon Kohden for technical tracks, but can be a SEEG electrode too. Keep only indices <= 18
        if isequal(uniqueTags{i}, 'X')
            iTagExtra = iTag(AllInd(iTag) > 18);
            AllNames(iTagExtra) = {'XXXXX'};
            AllTags(iTagExtra) = {'XXXXX'};
        % Remove if more than 18 (except for Salpetriere electrodes with digits in the name)
        elseif ((length(iTag) > 18) && (any(iTag < 10) || any(iTag >= 30)))
            AllNames(iTag) = {'XXXXX'};
            AllTags(iTag) = {'XXXXX'};
        end
        % Removed: ((length(iTag) < 2) && ~any(chNames{iTag(1)} == '-'))   % less than 2 (but only if not designating a bipolar montage, with '-' in the name) 
        % Keep electrodes with one contact only
    end
end

% Process all the channels
iSel = [];
iEcg = [];
for i = 1:length(AllNames)
    % ECG: Accept (should be labelled as such)
    if ismember(lower(AllTags{i}), {'ecg', 'ekg'}) || ~isempty(strfind(lower(AllNames{i}), 'ecg')) || ~isempty(strfind(lower(AllNames{i}), 'ekg'))
        iEcg(end+1) = i;
    % No index or does not end with a digit
    elseif isSEEG && (isNoInd(i) || ~ismember(AllNames{i}(end), '0123456789'))
        continue;
    % Does not contain at least a letter
    elseif isSEEG && ~any(ismember(lower(AllNames{i}), 'abcdefghijklmnopqrstuvwxyz'))
        continue;
    % Contains a /: exclude
    elseif isSEEG && any(ismember(lower(chNames{i}), '/'))
        continue;
    % Unwanted labels
    elseif ismember(lower(AllTags{i}), {'xxxxx', 'mark', 'dc', 'emg', 'eog', 'veo', 'heo', 'veog', 'heog', 'myo', 'myog', 'myod', 'dd', 'dg', 'el', 'ref', 'eegref', 'eref', 'vref', 'ref', 'pulse', 'mast', 'spo2', 'lpar', 'rpar', 'tib'})
        % MAYBE ADD 'oc' ??
        continue;
    % Unwanted labels
    elseif ~isempty(strfind(lower(AllTags{i}), 'eog')) || ~isempty(strfind(lower(AllTags{i}), 'ref'))
        continue;
    % Unwanted EEG labels
    elseif isSEEG && ismember(lower(AllTags{i}), {'cz', 'fz', 'pz', 'oz', 'nz', 'fpz'})
        continue;
    % Unwanted electrodes that are explicitely scalp electrodes (case sensitive)
    elseif isSEEG && ismember(AllNames{i}, {'sFp1','sFp2','sF4','sF3','sC3','sC4','sP4','sP3','sO2','sO1','sF8','sF7','sT8/T4','sT7/T3','sP8/T6','sP7/T5','sPz','sFz','sIO1','sIO2','sAF9','sAF10','sF9','sF10','sCB1','sCB2','sTP7','sTP9','sTP10','sTP8','sOz','sIz','sPO4','sPO3','sCP5','sCP6','sCP1','sCP2','sFT9','sFT10','sFC2','sFC1','sAF3','sAF4','sFC6','sFC5','sCPz','sP1','sPOz','sP2','sP6','sC6','sP5','sC1','sC2','sC5','sF2','sF6','sF1','sAF8','sF5','sAF7','sFpz','sFCz','sCz'})
        continue;
    % Unwanted FPx/Fx/Cx/Tx/Pz/Ox labels
    elseif isSEEG && ismember(lower(AllNames{i}), {'fp1','fp2'}) && ~any(ismember({'fp3','fp4','fp5','fp6','fp9','fp10','fp11','fp12','fp13','fp14','fp15','fp16'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'f3','f4','f7','f8'}) && ~any(ismember({'f1','f2','f5','f6','f9','f10','f11','f12','f13','f14','f15','f16'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'ft1','ft2','ft9','ft10'}) && ~any(ismember({'ft5','ft6','ft11','ft12','ft13','ft14','ft15','ft16'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'tp9','tp10'}) && ~any(ismember({'tp1','tp2','tp5','tp6','tp11','tp12','tp13','tp14','tp15','tp16'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'c3','c4'}) && ~any(ismember({'c1','c2','c5','c6','c7','c8','c9','c10','c11','c12','c13','c14','c15','c16'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'t3','t4','t5','t6','t9','t10'}) && ~any(ismember({'t1','t2','t7','t8','t11','t12','t13','t14','t15','t16'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'p3','p4'}) && ~any(ismember({'p1','p2','p5','p6','p7','p8','p9','p10','p11','p12','p13','p14','p15','p16'}, lower(AllNames)))
        continue;
    elseif isSEEG && ismember(lower(AllNames{i}), {'o1','o2'}) && ~any(ismember({'o3','o4','o4','o5','o6','o7','o8','o9','o10','o11','o12','o13','o14','o15','o16'}, lower(AllNames)))
        continue;
    % Otherwise: accept
    else
        iSel(end+1) = i;
    end
end

% Sort channels by tag and index
AllTags = AllTags(iSel);
AllInd = AllInd(iSel);
uniqueTags = unique(AllTags);
iOrderSel = [];
for i = 1:length(uniqueTags)
    iTag = find(strcmpi(AllTags, uniqueTags{i}));
    [tmp, iOrderInd] = sort(AllInd(iTag));
    iOrderSel = [iOrderSel, iTag(iOrderInd)];
end

% Add ECG channels at the end of the file
iSel = [iSel(iOrderSel), iEcg];



